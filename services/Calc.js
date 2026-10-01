.pragma library

// The launcher calculator's built-in engine, used when `qalc` isn't installed.
// Caelestia evaluates with libqalculate through its C++ Qalculator; Omacale
// can't load a C++ plugin and Omarchy ships no calculator, so this is a small
// recursive-descent evaluator (never `eval`) over plain arithmetic:
//
//   numbers   12  3.5  .5  1e3  0x1f  0b101
//   operators + - * / % ^ (also × ÷ ** and a postfix !), unary minus,
//             parentheses, and implicit multiplication: 2pi, 3(4+1)
//   constants pi π e tau
//   functions sqrt cbrt abs sign exp ln log log2 log10 sin cos tan asin acos
//             atan sinh cosh tanh floor ceil round trunc min max pow hypot
//
// evaluate(src) returns { value, parsed } or { error }.

const constants = { pi: Math.PI, "π": Math.PI, e: Math.E, tau: 2 * Math.PI }
const functions = {
  sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, sign: Math.sign, exp: Math.exp,
  ln: Math.log, log: Math.log10, log2: Math.log2, log10: Math.log10,
  sin: Math.sin, cos: Math.cos, tan: Math.tan, asin: Math.asin, acos: Math.acos, atan: Math.atan,
  sinh: Math.sinh, cosh: Math.cosh, tanh: Math.tanh,
  floor: Math.floor, ceil: Math.ceil, round: Math.round, trunc: Math.trunc,
  min: Math.min, max: Math.max, pow: Math.pow, hypot: Math.hypot
}

function tokenize(src) {
  const tokens = []
  let i = 0
  while (i < src.length) {
    const c = src[i]
    if (/\s/.test(c)) { i++; continue }
    let m = /^(0x[0-9a-f]+|0b[01]+)/i.exec(src.slice(i))
      || /^(\d+\.?\d*|\.\d+)(e[+-]?\d+)?/i.exec(src.slice(i))
    if (m) {
      const text = m[0]
      const lower = text.toLowerCase()
      const value = lower.startsWith("0x") ? parseInt(lower.slice(2), 16)
        : lower.startsWith("0b") ? parseInt(lower.slice(2), 2) : Number(text)
      tokens.push({ type: "num", value: value, text: text })
      i += text.length
      continue
    }
    m = /^([a-z_][a-z0-9_]*|π)/i.exec(src.slice(i))
    if (m) { tokens.push({ type: "id", text: m[0].toLowerCase() }); i += m[0].length; continue }
    if (src.startsWith("**", i)) { tokens.push({ type: "op", text: "^" }); i += 2; continue }
    const op = { "×": "*", "÷": "/", "·": "*" }[c] || c
    if ("+-*/%^!(),".indexOf(op) >= 0) { tokens.push({ type: "op", text: op }); i++; continue }
    throw new Error("unexpected \"" + c + "\"")
  }
  return tokens
}

function factorial(n) {
  if (n < 0 || !Number.isInteger(n)) throw new Error("factorial needs a whole number ≥ 0")
  if (n > 170) return Infinity
  let r = 1
  for (let k = 2; k <= n; k++) r *= k
  return r
}

function parse(tokens) {
  let pos = 0
  const peek = () => tokens[pos]
  const isOp = (t, s) => !!t && t.type === "op" && t.text === s
  const expect = s => {
    if (!isOp(peek(), s)) throw new Error(peek() ? "expected \"" + s + "\"" : "unexpected end of expression")
    pos++
  }

  // Each level returns { v: value, s: text }, the text being the expression
  // as parsed (qalc prints the same "parsed = result" form).
  function additive() {
    let l = multiplicative()
    while (isOp(peek(), "+") || isOp(peek(), "-")) {
      const op = tokens[pos++].text
      const r = multiplicative()
      l = { v: op === "+" ? l.v + r.v : l.v - r.v, s: l.s + " " + op + " " + r.s }
    }
    return l
  }
  function multiplicative() {
    let l = unary()
    for (;;) {
      const t = peek()
      if (isOp(t, "*") || isOp(t, "/") || isOp(t, "%")) {
        pos++
        const r = unary()
        l = { v: t.text === "*" ? l.v * r.v : t.text === "/" ? l.v / r.v : l.v % r.v,
              s: l.s + " " + (t.text === "*" ? "×" : t.text === "/" ? "÷" : "mod") + " " + r.s }
      } else if (t && (t.type === "id" || t.type === "num" || isOp(t, "("))) {
        // Implicit multiplication: 2pi, 3(4+1), (1+1)(2+2).
        const r = unary()
        l = { v: l.v * r.v, s: l.s + " × " + r.s }
      } else return l
    }
  }
  function unary() {
    if (isOp(peek(), "-")) { pos++; const r = unary(); return { v: -r.v, s: "−" + r.s } }
    if (isOp(peek(), "+")) { pos++; return unary() }
    return power()
  }
  function power() {
    const base = postfix()
    if (!isOp(peek(), "^")) return base
    pos++
    const exp = unary()   // right-associative; -2^2 is -(2^2)
    return { v: Math.pow(base.v, exp.v), s: base.s + "^" + exp.s }
  }
  function postfix() {
    let p = primary()
    while (isOp(peek(), "!")) { pos++; p = { v: factorial(p.v), s: p.s + "!" } }
    return p
  }
  function primary() {
    const t = tokens[pos++]
    if (!t) throw new Error("unexpected end of expression")
    if (t.type === "num") return { v: t.value, s: t.text }
    if (isOp(t, "(")) { const e = additive(); expect(")"); return { v: e.v, s: "(" + e.s + ")" } }
    if (t.type === "id") {
      if (functions[t.text]) {
        expect("(")
        const args = []
        if (!isOp(peek(), ")")) {
          args.push(additive())
          while (isOp(peek(), ",")) { pos++; args.push(additive()) }
        }
        expect(")")
        return { v: functions[t.text].apply(null, args.map(a => a.v)), s: t.text + "(" + args.map(a => a.s).join(", ") + ")" }
      }
      if (constants[t.text] !== undefined) return { v: constants[t.text], s: t.text }
      throw new Error("unknown name \"" + t.text + "\"")
    }
    throw new Error("unexpected \"" + t.text + "\"")
  }

  const result = additive()
  if (pos < tokens.length) throw new Error("unexpected \"" + tokens[pos].text + "\"")
  return result
}

// 12 significant digits, trailing zeros trimmed (0.1 + 0.2 is 0.3), and
// qalc's exponent style (1.07150860719E301), which also pastes as a number.
function format(v) {
  if (Object.is(v, -0)) v = 0
  return Number(v.toPrecision(12)).toString().replace("e+", "E").replace("e-", "E-")
}

function evaluate(src) {
  try {
    const tokens = tokenize(String(src))
    if (tokens.length === 0) return { error: "empty expression" }
    const r = parse(tokens)
    if (Number.isNaN(r.v)) return { error: "result is undefined" }
    if (!Number.isFinite(r.v)) return { error: r.v > 0 ? "result is infinite" : "result is negative infinity" }
    return { value: format(r.v), parsed: r.s }
  } catch (e) {
    return { error: e.message }
  }
}

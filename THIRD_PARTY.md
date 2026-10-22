# Third-party code

Omacale is GPL-3.0-only ([LICENSE](LICENSE)). Some of it is ported from
other projects and stays under their licenses; the full texts are in
[LICENSES/](LICENSES).

## Serpantinum — AGPL-3.0-or-later

<https://github.com/ilyamiro/serpantinum>, Copyright (C) 2026 ilyamiro and
the Serpantinum contributors. Licensed under the GNU Affero General Public
License, version 3 or (at your option) any later version:
[LICENSES/AGPL-3.0-or-later.md](LICENSES/AGPL-3.0-or-later.md).

These files contain code ported from Serpantinum's liquid glass
(`src/assets/shaders/effects/liquid_glass.frag`) and nested glass
(`src/quickshell/reusables/display/GlassFill.qml`), modified for Omacale, and
are therefore under AGPL-3.0-or-later, as is the compiled shader built from
each `.frag` (its `.qsb`):

- `shaders/blob.frag` (+ `shaders/blob.frag.qsb`) — the glass lens path; the
  rest of the file is a port of Caelestia's blob shader (GPL-3.0)
- `shaders/glasscard.frag` (+ `shaders/glasscard.frag.qsb`)
- `components/GlassCard.qml`
- `components/GlassMotion.qml`

GPL-3.0 and AGPL-3.0 each allow being combined with the other (section 13
of both); the files above keep the AGPL's terms, including its section 13,
and the rest of Omacale keeps the GPL's.

Omacale's Morph motion (`core/Morph.qml`, `components/MorphDrawer.qml`,
`components/MorphSwitch.qml`) is written for Omacale and follows only the
idea and timings of Serpantinum's panels; it is GPL-3.0-only like the rest.

## Vitreus — MIT

<https://github.com/natepayn3/Vitreus>, Copyright (c) 2026 natepayn3:
[LICENSES/MIT-Vitreus.txt](LICENSES/MIT-Vitreus.txt).

Liquid motion and the glass's base look are ported from it:
`core/LiquidMath.js`, `core/Liquid.qml`, `components/shapes/LiquidDrawer.qml`,
`components/shapes/LiquidDetach.qml`, `core/Glass.qml`, and the liquid and
glass paths of `shaders/blob.frag`.

## pleamar — BSD-3-Clause

<https://github.com/k4ditano/pleamar>, Copyright (c) 2026, Abel:
[LICENSES/BSD-3-Clause-pleamar.txt](LICENSES/BSD-3-Clause-pleamar.txt).

The spring (`components/Spring.qml`) and the glass body (`core/Glass.qml`,
the glass path of `shaders/blob.frag`, from pleamar's `src/shape.wgsl`).

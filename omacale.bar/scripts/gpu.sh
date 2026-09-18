#!/usr/bin/env bash
# Omacale GPU helper. Prints: type|name|usage%|tempC|sleeping
# Never wakes a runtime-suspended NVIDIA dGPU (common on hybrid laptops):
# polling nvidia-smi would power it up and cost battery.
set -uo pipefail

for dev in /sys/bus/pci/drivers/nvidia/0000:*; do
  [[ -e $dev ]] || continue
  status=$(cat "$dev/power/runtime_status" 2>/dev/null || echo active)
  name=$(lspci -s "${dev##*/}" 2>/dev/null | sed -E 's/.*\[([^]]+)\].*/\1/' )
  if [[ $status != active ]]; then echo "nvidia|${name:-NVIDIA GPU}|0|0|1"; exit 0; fi
  if command -v nvidia-smi >/dev/null; then
    IFS=', ' read -r util temp < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
    n=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    echo "nvidia|${n:-$name}|${util:-0}|${temp:-0}|0"; exit 0
  fi
done

for card in /sys/class/drm/card*/device; do
  [[ -r $card/gpu_busy_percent ]] || continue
  util=$(cat "$card/gpu_busy_percent")
  t=$(cat "$card"/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
  name=$(lspci -s "$(basename "$(readlink -f "$card")")" 2>/dev/null | sed -E 's/^[^:]+:[^:]+: //; s/ \(rev.*//')
  echo "amd|${name:-GPU}|$util|$(( ${t:-0} / 1000 ))|0"; exit 0
done

echo "none||0|0|0"

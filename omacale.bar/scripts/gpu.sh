#!/usr/bin/env bash
# Omacale GPU helper. Prints: type|name|usage%|tempC|sleeping
# Never wakes a runtime-suspended NVIDIA dGPU (common on hybrid laptops):
# polling nvidia-smi would power it up and cost battery.
#
# $1, when given, is the adapter name the caller already has. The name never
# changes, but looking it up costs an `lspci` (~10ms) and, on NVIDIA, a second
# `nvidia-smi` (~24ms) -- most of this script's cost, paid once a second by a
# poll that only wants the two numbers. Sys.qml passes the name back in as
# soon as it knows it, so only the first call of a session resolves it.
set -uo pipefail

KNOWN_NAME="${1:-}"

for dev in /sys/bus/pci/drivers/nvidia/0000:*; do
  [[ -e $dev ]] || continue
  status=$(cat "$dev/power/runtime_status" 2>/dev/null || echo active)
  if [[ $status != active ]]; then
    name=$KNOWN_NAME
    [[ -n $name ]] || name=$(lspci -s "${dev##*/}" 2>/dev/null | sed -E 's/.*\[([^]]+)\].*/\1/')
    echo "nvidia|${name:-NVIDIA GPU}|0|0|1"
    exit 0
  fi
  if command -v nvidia-smi >/dev/null; then
    # One query, not two: the name rides along on the call that is being made
    # anyway, and is skipped entirely once the caller knows it.
    if [[ -n $KNOWN_NAME ]]; then
      IFS=', ' read -r util temp < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
      name=$KNOWN_NAME
    else
      IFS=',' read -r util temp name < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,name --format=csv,noheader,nounits 2>/dev/null | head -1)
    fi
    echo "nvidia|${name# }|${util:-0}|${temp# }|0"
    exit 0
  fi
done

for card in /sys/class/drm/card*/device; do
  [[ -r $card/gpu_busy_percent ]] || continue
  util=$(cat "$card/gpu_busy_percent")
  t=$(cat "$card"/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
  name=$KNOWN_NAME
  [[ -n $name ]] || name=$(lspci -s "$(basename "$(readlink -f "$card")")" 2>/dev/null | sed -E 's/^[^:]+:[^:]+: //; s/ \(rev.*//')
  echo "amd|${name:-GPU}|$util|$(( ${t:-0} / 1000 ))|0"
  exit 0
done

echo "none||0|0|0"

#!/usr/bin/env bash
# Omacale visualiser helper: runs cava in raw ASCII mode and streams one line
# of ";"-separated bar values (0-1000) per frame. Exits 127 without cava.
# usage: cava.sh [bars]
command -v cava >/dev/null 2>&1 || exit 127
cfg="${XDG_RUNTIME_DIR:-/tmp}/omacale-cava.conf"
cat >"$cfg" <<CONF
[general]
bars = ${1:-60}
framerate = 60
autosens = 1
[input]
method = pipewire
source = auto
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59
frame_delimiter = 10
channels = mono
[smoothing]
noise_reduction = 55
CONF
exec cava -p "$cfg"

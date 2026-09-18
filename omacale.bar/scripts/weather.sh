#!/usr/bin/env bash
# Omacale weather helper — the same data source as Caelestia (Open-Meteo),
# located via Open-Meteo geocoding for a named city or ip-api otherwise.
# usage: weather.sh [city] [metric|imperial]  → one JSON object on stdout
set -uo pipefail

loc="${1:-}"
units="${2:-metric}"
uri() { jq -rn --arg s "$1" '$s|@uri'; }
fail() { jq -cn --arg e "$1" '{error:$e}'; exit 0; }

if [[ -n $loc ]]; then
  g=$(curl -fsS --max-time 8 "https://geocoding-api.open-meteo.com/v1/search?name=$(uri "$loc")&count=1&format=json") || fail "geocoding"
  lat=$(jq -r '.results[0].latitude // empty' <<<"$g")
  lon=$(jq -r '.results[0].longitude // empty' <<<"$g")
  city=$(jq -r '.results[0].name // empty' <<<"$g")
else
  g=$(curl -fsS --max-time 8 "http://ip-api.com/json?fields=status,city,lat,lon") || fail "ip lookup"
  lat=$(jq -r 'select(.status=="success") | .lat // empty' <<<"$g")
  lon=$(jq -r 'select(.status=="success") | .lon // empty' <<<"$g")
  city=$(jq -r '.city // empty' <<<"$g")
fi
[[ -n $lat && -n $lon ]] || fail "location"

tu=celsius; wu=kmh
[[ $units == imperial ]] && { tu=fahrenheit; wu=mph; }

w=$(curl -fsS --max-time 10 "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon\
&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m\
&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset\
&timezone=auto&forecast_days=7&temperature_unit=$tu&wind_speed_unit=$wu") || fail "forecast"

jq -c --arg city "$city" --arg units "$units" '{
  city: $city, units: $units,
  current: .current,
  daily: [range(0; (.daily.time | length)) as $i | {
    date: .daily.time[$i], code: .daily.weather_code[$i],
    max: .daily.temperature_2m_max[$i], min: .daily.temperature_2m_min[$i],
    sunrise: .daily.sunrise[$i], sunset: .daily.sunset[$i]
  }]
}' <<<"$w"

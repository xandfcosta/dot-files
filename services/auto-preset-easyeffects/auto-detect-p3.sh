#!/bin/bash

HEADSET_PRESET="Havit-H2002D"
SPEAKER_PRESET="Speaker"

get_active_port() {
  pactl list sinks | grep "Active Port" | head -n1 | awk '{print $3}'
}

apply_preset() {
  preset="$1"
  easyeffects --load-preset="$preset"
}

echo "Listening to P3 change..."

current=""
pactl subscribe | while read -r event; do
  if echo "$event" | grep -q "sink"; then
    port=$(get_active_port)

    if [[ "$port" == "analog-output-headphones" && "$current" != "headphones" ]]; then
      echo "Headphone connected, changing preset to: $HEADSET_PRESET"
      apply_preset "$HEADSET_PRESET"
      current="headphones"
    elif [[ "$port" == "analog-output-speaker" && "$current" != "speakers" ]]; then
      echo "Headphone disconnected, changing preset to: $SPEAKER_PRESET"
      apply_preset "$SPEAKER_PRESET"
      current="speakers"
    fi
  fi
done

#!/bin/bash

player_status=$(playerctl -p spotify status 2>/dev/null | tr '[:upper:]' '[:lower:]')

if [ "$player_status" = "playing" ] || [ "$player_status" = "paused" ]; then
  artist=$(playerctl -p spotify metadata artist 2>/dev/null)
  title=$(playerctl -p spotify metadata title 2>/dev/null)

  if [ -n "$artist" ] && [ -n "$title" ]; then
    # escape special characters for JSON
    artist=$(echo "$artist" | sed 's/&/&amp;/g')
    title=$(echo "$title" | sed 's/&/&amp;/g')

    # Define estado textual
    alt="$player_status"

    echo '{"text": "'"$artist - $title"'", "class": "custom-spotify", "alt": "'"$alt"'"}'
  else
    echo '{"text": "unknown track", "class": "custom-spotify", "alt": "'"$player_status"'"}'
  fi
fi

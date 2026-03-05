#!/usr/bin/env bash

TARGET_DIR="/tmp"
OUTPUT="$TARGET_DIR/cover.jpeg"

update_cover() {
    STATUS="$(playerctl status 2>/dev/null)"

    if [[ "$STATUS" != "Playing" ]]; then
        rm -f "$OUTPUT"
        echo ""
        return
    fi

    ART_URL="$(playerctl metadata mpris:artUrl 2>/dev/null)"

    if [[ -z "$ART_URL" ]]; then
        rm -f "$OUTPUT"
        echo ""
        return
    fi

    CURRENT_URL_FILE="$TARGET_DIR/cover_url"

    if [[ -f "$CURRENT_URL_FILE" ]] && [[ "$(cat "$CURRENT_URL_FILE")" == "$ART_URL" ]]; then
        echo "$OUTPUT"
        return
    fi

    echo "$ART_URL" > "$CURRENT_URL_FILE"

    TMP_FILE="$TARGET_DIR/cover_raw"

    if [[ "$ART_URL" == file://* ]]; then
        LOCAL_PATH="${ART_URL#file://}"
        cp "$LOCAL_PATH" "$TMP_FILE" 2>/dev/null || return
    else
        curl -fsL -A "Mozilla/5.0" "$ART_URL" -o "$TMP_FILE" || return
    fi

    if ! file "$TMP_FILE" | grep -qi image; then
        rm -f "$TMP_FILE"
        return
    fi

    magick "$TMP_FILE" -quality 90 "$OUTPUT" 2>/dev/null
    rm -f "$TMP_FILE"

    echo "$OUTPUT"
}

update_cover 

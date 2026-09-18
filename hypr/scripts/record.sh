#!/bin/bash

SAVE_DIR="$HOME/recordings"
mkdir -p "$SAVE_DIR"

OUTPUT="$SAVE_DIR/recording_$(date +%Y-%m-%d_%H-%M-%S).mp4"

PID_FILE="/tmp/wf-recorder.pid"
STATE_FILE="/tmp/recording.state"

AUDIO_SOURCE="$(pactl get-default-sink).monitor"

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    kill -SIGINT "$(cat "$PID_FILE")"

    rm -f "$PID_FILE"
    rm -f "$STATE_FILE"

    pkill -SIGRTMIN+8 waybar

    sleep 1

    LAST_FILE=$(find "$SAVE_DIR" -maxdepth 1 -name "*.mp4" -type f | sort | tail -n 1)

    if [ -n "$LAST_FILE" ]; then
        notify-send "⏹ Gravação salva" "$LAST_FILE"
    fi

else
    notify-send "⏺ Gravando tela cheia com áudio do sistema..."

    wf-recorder --audio="$AUDIO_SOURCE" -c h264_vaapi -d /dev/dri/renderD128 -f "$OUTPUT" &

    echo $! > "$PID_FILE"

    touch "$STATE_FILE"

    pkill -SIGRTMIN+8 waybar
fi
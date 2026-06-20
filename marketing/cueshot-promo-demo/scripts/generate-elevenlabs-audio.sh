#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIO_DIR="$ROOT_DIR/assets/audio"
SCRIPT_FILE="$AUDIO_DIR/voiceover.txt"
DURATION_SECONDS="${DURATION_SECONDS:-36}"
DURATION_MS="${DURATION_MS:-36000}"
VOICE_ID="${VOICE_ID:-UgBBYS2sOqTuMpoF3BR0}"
VOICE_TEMPO="${VOICE_TEMPO:-1.06}"

: "${ELEVENLABS_API_KEY:?Set ELEVENLABS_API_KEY before generating ElevenLabs audio.}"

mkdir -p "$AUDIO_DIR"

python3 - <<'PY' "$SCRIPT_FILE" "$AUDIO_DIR/tts-payload.json"
import json
import sys

script_path, out_path = sys.argv[1:3]
text = open(script_path, "r", encoding="utf-8").read().strip()
payload = {
    "text": text,
    "model_id": "eleven_multilingual_v2",
    "voice_settings": {
        "stability": 0.52,
        "similarity_boost": 0.76,
        "style": 0.28,
        "speed": 1.0,
        "use_speaker_boost": True
    },
    "apply_text_normalization": "on"
}
open(out_path, "w", encoding="utf-8").write(json.dumps(payload))
PY

curl -sS --fail-with-body -X POST "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID?output_format=mp3_44100_192" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary "@$AUDIO_DIR/tts-payload.json" \
  --output "$AUDIO_DIR/voiceover-elevenlabs.mp3"

python3 - <<'PY' "$AUDIO_DIR/music-payload.json" "$DURATION_MS"
import json
import sys

out_path, duration_ms = sys.argv[1:3]
payload = {
    "prompt": "Restrained premium technology product demo bed for a macOS element-selection workflow, graphite glass mood, subtle analog pulse, soft modular bass, crisp minimal percussion, young and confident but not corporate, clean space for voiceover.",
    "music_length_ms": int(duration_ms),
    "force_instrumental": True
}
open(out_path, "w", encoding="utf-8").write(json.dumps(payload))
PY

curl -sS --fail-with-body -X POST "https://api.elevenlabs.io/v1/music" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary "@$AUDIO_DIR/music-payload.json" \
  --output "$AUDIO_DIR/music-elevenlabs.mp3"

generate_sfx() {
  local prompt="$1"
  local duration="$2"
  local influence="$3"
  local output="$4"
  local payload="$5"

  python3 - <<'PY' "$prompt" "$duration" "$influence" "$payload"
import json
import sys

prompt, duration, influence, out_path = sys.argv[1:5]
payload = {
    "text": prompt,
    "model_id": "eleven_text_to_sound_v2",
    "duration_seconds": float(duration),
    "prompt_influence": float(influence)
}
open(out_path, "w", encoding="utf-8").write(json.dumps(payload))
PY

  curl -sS --fail-with-body -X POST "https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_192" \
    -H "xi-api-key: $ELEVENLABS_API_KEY" \
    -H "Content-Type: application/json" \
    -H "Accept: audio/mpeg" \
    --data-binary "@$payload" \
    --output "$output"
}

generate_sfx \
  "Premium macOS UI click, soft glass button press, short clean transient" \
  0.8 \
  0.55 \
  "$AUDIO_DIR/sfx-click-elevenlabs.mp3" \
  "$AUDIO_DIR/sfx-click-payload.json"

generate_sfx \
  "Subtle digital reticle lock-on chime, premium product UI, short decay" \
  0.9 \
  0.55 \
  "$AUDIO_DIR/sfx-reticle-elevenlabs.mp3" \
  "$AUDIO_DIR/sfx-reticle-payload.json"

generate_sfx \
  "Soft whoosh focus transition, graphite glass interface, understated" \
  0.9 \
  0.5 \
  "$AUDIO_DIR/sfx-whoosh-elevenlabs.mp3" \
  "$AUDIO_DIR/sfx-whoosh-payload.json"

generate_sfx \
  "Precise UI element selection lock, premium reticle snap, short clean confirmation chime" \
  1.0 \
  0.62 \
  "$AUDIO_DIR/sfx-element-lock-elevenlabs.mp3" \
  "$AUDIO_DIR/sfx-element-lock-payload.json"

ffmpeg -y \
  -i "$AUDIO_DIR/music-elevenlabs.mp3" \
  -i "$AUDIO_DIR/voiceover-elevenlabs.mp3" \
  -i "$AUDIO_DIR/sfx-click-elevenlabs.mp3" \
  -i "$AUDIO_DIR/sfx-reticle-elevenlabs.mp3" \
  -i "$AUDIO_DIR/sfx-whoosh-elevenlabs.mp3" \
  -i "$AUDIO_DIR/sfx-element-lock-elevenlabs.mp3" \
  -filter_complex "\
    [0:a]atrim=0:${DURATION_SECONDS},asetpts=PTS-STARTPTS,volume=0.24[bed];\
    [1:a]atempo=${VOICE_TEMPO},adelay=360|360,volume=1.08[vo];\
    [2:a]adelay=6880|6880[c1];\
    [2:a]adelay=17680|17680[c2];\
    [2:a]adelay=24600|24600[c3];\
    [3:a]adelay=11950|11950[r1];\
    [4:a]adelay=4200|4200[w1];\
    [4:a]adelay=10200|10200[w2];\
    [4:a]adelay=16400|16400[w3];\
    [4:a]adelay=22200|22200[w4];\
    [4:a]adelay=29400|29400[w5];\
    [5:a]adelay=18580|18580[lock1];\
    [bed][vo][c1][c2][c3][r1][w1][w2][w3][w4][w5][lock1]amix=inputs=12:duration=first:normalize=0,alimiter=limit=0.92,loudnorm=I=-16:TP=-1.5:LRA=11,volume=0.86[out]" \
  -map "[out]" -c:a aac -b:a 192k "$AUDIO_DIR/cueshot-promo-elevenlabs-mix.m4a"

ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$AUDIO_DIR/cueshot-promo-elevenlabs-mix.m4a"

#!/bin/bash
# Usage: ./make_reel.sh "input_video.mp4" "Nom du projet" ["output.mp4"]
#
# Composites a phone screen recording into the branded Guédé Tech vertical
# template (1080x1920, 9:16 — TikTok / Instagram Reels & Stories):
#   [white background + logo + "GUÉDÉ TECH" + tagline + "UN PROJET RÉALISÉ
#    PAR GUÉDÉ TECH" badge + project title]  behind an iPhone-style frame
#   [the screen recording, cropped to fill the frame's screen area]  inside
#   [the frame's bezel ring, painted on top — see gen_frame.js for how the
#    "rounded video corners" illusion works without masking the video]
#
# Pipeline: template_back.html (with the project name substituted in) is
# screenshotted by headless Chrome into a static background PNG, then
# ffmpeg composites the input video + frame.png on top of it in one pass.
#
# Prerequisites: Google Chrome/Chromium, ffmpeg, bash. See ../README.md.

set -e

INPUT_VIDEO="$1"
PROJECT_NAME="$2"
OUTPUT="${3:-output_$(date +%s).mp4}"

if [ -z "$INPUT_VIDEO" ] || [ -z "$PROJECT_NAME" ]; then
  echo "Usage: ./make_reel.sh <input_video> <project_name> [output.mp4]"
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_HTML="$DIR/_tmp_back.html"
TMP_BG="$DIR/_tmp_back.png"

source "$DIR/../find_chrome.sh"

# Windows-style forward-slash path (Chrome's file:// needs this on Windows;
# on macOS/Linux $DIR is already a normal POSIX path, so this is a no-op).
case "$DIR" in
  /?/*) WINDIR="$(echo "$DIR" | sed -E 's#^/([a-zA-Z])/#\U\1:/#')" ;;
  *) WINDIR="$DIR" ;;
esac
LOGO_MARK_PATH="$WINDIR/../assets/logo-mark.png"

sed \
  -e "s#__LOGO_MARK_PATH__#${LOGO_MARK_PATH}#" \
  -e "s#__PROJECT_NAME__#${PROJECT_NAME}#" \
  "$DIR/template_back.html" > "$TMP_HTML"

# Chrome's --screenshot navigation URL needs spaces percent-encoded
# (unlike <img src> inside the page, which Chrome's HTML parser tolerates
# fine with raw spaces).
TMP_HTML_WIN="$WINDIR/_tmp_back.html"
TMP_HTML_URL="file:///$(echo "$TMP_HTML_WIN" | sed 's/ /%20/g')"

"$CHROME" --headless --disable-gpu --no-sandbox --hide-scrollbars \
  --force-device-scale-factor=1 --window-size=1080,1920 \
  --screenshot="$TMP_BG" "$TMP_HTML_URL"

# 600x1299 / 240:464 come from gen_frame.js's INNER rect — the exact hole
# in frame.png where the video must land. If you regenerate frame.png with
# different OUTER/BEZEL values, update these two numbers to match INNER.
ffmpeg -y \
  -loop 1 -i "$TMP_BG" \
  -i "$INPUT_VIDEO" \
  -loop 1 -i "$DIR/frame.png" \
  -filter_complex "
    [1:v]scale=600:1299:force_original_aspect_ratio=increase,crop=600:1299,setsar=1[vid];
    [0:v][vid]overlay=240:464:shortest=1[bg1];
    [bg1][2:v]overlay=0:0:shortest=1,format=yuv420p[out]
  " \
  -map "[out]" -map 1:a? \
  -c:v libx264 -preset medium -crf 18 \
  -c:a aac -b:a 192k \
  -shortest \
  "$OUTPUT"

rm -f "$TMP_HTML" "$TMP_BG"
echo "Done -> $OUTPUT"

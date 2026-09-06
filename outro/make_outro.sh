#!/bin/bash
# Regenerates Outro_GuedeTech.mp4 from outro_master.html — a 6s branded
# end-card (logo -> name -> tagline -> divider -> "Un projet en tête ?" ->
# "Contactez-nous" button -> contact info, each staggered fade-in, then a
# fade-to-white) meant to be appended after every reel via ../append_outro.sh.
#
# To tweak text/colors/timing:
#   - Edit outro_master.html for anything visual (positions, text, colors,
#     the CTA phrase, contact info). It's one HTML file with all 7 elements
#     absolute-positioned; re-run this script afterwards.
#   - Edit the fade timing table in the ffmpeg filter_complex below to
#     change the animation pacing or total duration (currently 6s @ 30fps).
#
# How the animation works without any frame-by-frame rendering: each of
# the 7 elements (logo, name, tag, divider, cta-eyebrow, cta-button,
# contact) is rendered as its OWN full-canvas (1080x1920) transparent PNG
# via split_outro_layers.js, with the element at its final position and
# everything else hidden. ffmpeg then loops each PNG as a static clip and
# applies `fade=t=in:st=<start>:d=<duration>:alpha=1` to fade its ALPHA
# channel in at a staggered start time, then overlays all 8 layers
# (background + 7 elements) at overlay=0:0 (position never changes — only
# opacity animates, so no per-element pixel offsets are needed). The whole
# composite gets one final `fade=t=out:...:color=white` for a clean end.
#
# Prerequisites: Google Chrome/Chromium, ffmpeg, Node.js, bash.

set -e

# Optional first argument selects the aspect ratio:
#   ./make_outro.sh        -> 1080x1920 (9:16) -> Outro_GuedeTech.mp4
#   ./make_outro.sh 16x9   -> 1920x1080 (16:9) -> Outro_GuedeTech_16x9.mp4
# The 16:9 card is the YouTube counterpart used by ../tuto-pipeline. Both
# masters carry the same seven element ids and the same reveal timing, so
# everything below is shared — only the canvas size and file names change.
VARIANT="$1"
case "$VARIANT" in
  16x9) W=1920; H=1080; SUFFIX="_16x9" ;;
  "")   W=1080; H=1920; SUFFIX="" ;;
  *)    echo "Usage: ./make_outro.sh [16x9]" >&2; exit 1 ;;
esac

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/../find_chrome.sh"

node "$DIR/split_outro_layers.js" $VARIANT

"$CHROME" --headless --disable-gpu --no-sandbox --hide-scrollbars \
  --force-device-scale-factor=1 --window-size=$W,$H \
  --screenshot="$DIR/L_background.png" "file:///$DIR/layer_background$SUFFIX.html"

for id in logo name tag divider cta-eyebrow cta-button contact; do
  "$CHROME" --headless --disable-gpu --no-sandbox --hide-scrollbars \
    --force-device-scale-factor=1 --default-background-color=00000000 \
    --window-size=$W,$H \
    --screenshot="$DIR/L_${id}.png" "file:///$DIR/layer_${id}$SUFFIX.html"
done

# Fade-in timing table (seconds): [start, duration] per element, staggered
# ~0.25-0.3s apart so they read as a deliberate sequence, not a single flash.
#   logo         0.00 - 0.60
#   name         0.30 - 0.90
#   tagline      0.55 - 1.10
#   divider      0.85 - 1.20
#   cta-eyebrow  1.10 - 1.60
#   cta-button   1.35 - 1.90
#   contact      1.75 - 2.30
#   (hold fully visible until 5.3s)
#   whole scene fades to white  5.3 - 6.0
ffmpeg -y \
  -loop 1 -t 6 -i "$DIR/L_background.png" \
  -loop 1 -t 6 -i "$DIR/L_logo.png" \
  -loop 1 -t 6 -i "$DIR/L_name.png" \
  -loop 1 -t 6 -i "$DIR/L_tag.png" \
  -loop 1 -t 6 -i "$DIR/L_divider.png" \
  -loop 1 -t 6 -i "$DIR/L_cta-eyebrow.png" \
  -loop 1 -t 6 -i "$DIR/L_cta-button.png" \
  -loop 1 -t 6 -i "$DIR/L_contact.png" \
  -filter_complex "
    [1:v]format=rgba,fade=t=in:st=0.0:d=0.6:alpha=1[l1];
    [2:v]format=rgba,fade=t=in:st=0.3:d=0.6:alpha=1[l2];
    [3:v]format=rgba,fade=t=in:st=0.55:d=0.55:alpha=1[l3];
    [4:v]format=rgba,fade=t=in:st=0.85:d=0.35:alpha=1[l4];
    [5:v]format=rgba,fade=t=in:st=1.1:d=0.5:alpha=1[l5];
    [6:v]format=rgba,fade=t=in:st=1.35:d=0.55:alpha=1[l6];
    [7:v]format=rgba,fade=t=in:st=1.75:d=0.55:alpha=1[l7];
    [0:v][l1]overlay=0:0[s1];
    [s1][l2]overlay=0:0[s2];
    [s2][l3]overlay=0:0[s3];
    [s3][l4]overlay=0:0[s4];
    [s4][l5]overlay=0:0[s5];
    [s5][l6]overlay=0:0[s6];
    [s6][l7]overlay=0:0[s7];
    [s7]fade=t=out:st=5.3:d=0.7:color=white,format=yuv420p[out]
  " \
  -map "[out]" -r 30 -c:v libx264 -preset medium -crf 18 -t 6 \
  "$DIR/Outro_GuedeTech$SUFFIX.mp4"

rm -f "$DIR"/L_*.png "$DIR"/layer_*.html
echo "Done -> $DIR/Outro_GuedeTech$SUFFIX.mp4"

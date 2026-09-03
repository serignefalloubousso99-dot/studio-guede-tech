#!/bin/bash
# Usage: ./append_outro.sh <reel.mp4> <output.mp4>
#
# Concatenates outro/Outro_GuedeTech.mp4 onto the end of a reel video
# (the output of reel-template/make_reel.sh), normalizing fps and audio
# so the join has no glitch or frame-rate jump.
#
# Why normalization is needed: make_reel.sh's ffmpeg filter graph doesn't
# pin an output frame rate, so it inherits ~25fps by default, while the
# outro is rendered at a fixed 30fps. Naively concatenating mismatched
# fps (or a video with audio + a video with none) causes stutter or fails
# outright, so this script explicitly:
#   - re-times both video streams to 30fps (`fps=30`)
#   - generates 6s of silence (`anullsrc`, trimmed to the outro's exact
#     duration) as the outro's audio track, since it has none
#   - joins [video,audio] pairs with ffmpeg's `concat` filter (not the
#     concat demuxer, which requires already-identical codec parameters)

set -e

REEL="$1"
OUTPUT="$2"

if [ -z "$REEL" ] || [ -z "$OUTPUT" ]; then
  echo "Usage: ./append_outro.sh <reel.mp4> <output.mp4>"
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
OUTRO="$DIR/outro/Outro_GuedeTech.mp4"

ffmpeg -y \
  -i "$REEL" \
  -i "$OUTRO" \
  -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
  -filter_complex "
    [0:v]fps=30,format=yuv420p[v0];
    [1:v]fps=30,format=yuv420p[v1];
    [0:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo[a0];
    [2:a]atrim=duration=6,aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo[a1];
    [v0][a0][v1][a1]concat=n=2:v=1:a=1[outv][outa]
  " \
  -map "[outv]" -map "[outa]" \
  -c:v libx264 -preset medium -crf 18 -c:a aac -b:a 192k \
  "$OUTPUT"

echo "Done -> $OUTPUT"

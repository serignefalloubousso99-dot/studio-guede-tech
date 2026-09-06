#!/bin/bash
# Usage: ./make_tuto.sh <capture.mp4> "<Titre du tuto>" [options]
#
# Turns a raw OBS screen recording of a coding session into two finished,
# branded, ready-to-post videos:
#
#   <slug>-youtube.mp4   1920x1080 (16:9)  — the capture, enhanced, with a
#                        corner watermark, then the 16:9 end card appended.
#   <slug>-tiktok.mp4    1080x1920 (9:16)  — the same capture seated inside a
#                        macOS-window mockup on the branded vertical layout
#                        (logo / title / hook / contact), then the 9:16 end
#                        card appended.
#
# Both get the same picture and sound treatment:
#   - sharpening tuned for on-screen text (code stays crisp after scaling)
#   - a gentle contrast/saturation lift so a flat screen capture has some life
#   - audio: rumble filter, spectral noise reduction (fan, hiss, room tone),
#     compression to even out a voice that drifts near and far from the mic,
#     then loudness normalisation to -14 LUFS — the level YouTube and TikTok
#     both target, so neither platform re-adjusts your video on upload.
#
# Options:
#   -s, --sous-titre "texte"  hook line under the title (9:16 layout only)
#   -o, --out DIR             output directory (default: ./out)
#       --only youtube|tiktok build just one of the two
#       --no-outro            skip the end card
#       --filigrane COIN      watermark corner: bl (default), br, tl, tr
#       --denoise             also denoise the picture (see note below)
#       --hq                  slower encode, higher quality (medium/CRF 18)
#
# Picture denoising is OFF by default on purpose: hqdn3d softens fine detail,
# and on a screen capture the "grain" it would remove is mostly the text you
# are trying to keep legible. Turn it on when the webcam inset dominates the
# frame, not for a full-screen editor.
#
# Prerequisites: Google Chrome/Chromium, ffmpeg, Node.js, bash. See ../README.md.

set -e

INPUT=""
TITLE=""
SUBTITLE=""
OUTDIR=""
ONLY="both"
WITH_OUTRO=1
VIDEO_DENOISE=0
WM_POS="bl"
PRESET="veryfast"
CRF=20

while [ $# -gt 0 ]; do
  case "$1" in
    -s|--sous-titre) SUBTITLE="$2"; shift 2 ;;
    -o|--out)        OUTDIR="$2"; shift 2 ;;
    --only)          ONLY="$2"; shift 2 ;;
    --no-outro)      WITH_OUTRO=0; shift ;;
    --filigrane)     WM_POS="$2"; shift 2 ;;
    --denoise)       VIDEO_DENOISE=1; shift ;;
    --hq)            PRESET="medium"; CRF=18; shift ;;
    -h|--help)       sed -n '2,40p' "$0"; exit 0 ;;
    -*)              echo "Option inconnue: $1" >&2; exit 1 ;;
    *)
      if [ -z "$INPUT" ]; then INPUT="$1"
      elif [ -z "$TITLE" ]; then TITLE="$1"
      else echo "Argument en trop: $1" >&2; exit 1
      fi
      shift ;;
  esac
done

if [ -z "$INPUT" ] || [ -z "$TITLE" ]; then
  echo 'Usage: ./make_tuto.sh <capture.mp4> "<Titre du tuto>" [options]' >&2
  echo '       ./make_tuto.sh --help  pour la liste des options' >&2
  exit 1
fi
if [ ! -f "$INPUT" ]; then
  echo "Fichier introuvable: $INPUT" >&2
  exit 1
fi
case "$ONLY" in both|youtube|tiktok) ;; *) echo "--only attend youtube ou tiktok" >&2; exit 1 ;; esac
case "$WM_POS" in bl|br|tl|tr) ;; *) echo "--filigrane attend bl, br, tl ou tr" >&2; exit 1 ;; esac

command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg est introuvable. Installe-le puis relance." >&2; exit 1; }
command -v ffprobe >/dev/null 2>&1 || { echo "ffprobe est introuvable (il vient avec ffmpeg)." >&2; exit 1; }

DIR="$(cd "$(dirname "$0")" && pwd)"
OUTDIR="${OUTDIR:-$PWD/out}"
mkdir -p "$OUTDIR"

source "$DIR/../find_chrome.sh"

# Windows-style forward-slash path for Chrome's file:// URLs (no-op on
# macOS/Linux, where $DIR is already POSIX). Same handling as make_reel.sh.
case "$DIR" in
  /?/*) WINDIR="$(echo "$DIR" | sed -E 's#^/([a-zA-Z])/#\U\1:/#')" ;;
  *) WINDIR="$DIR" ;;
esac
LOGO_MARK_PATH="$WINDIR/../assets/logo-mark.png"

# File-name slug: decompose accents (NFD), drop the combining marks, lowercase,
# then collapse anything non-alphanumeric into single dashes. Done in Node --
# already a dependency here -- rather than with iconv//TRANSLIT + tr, because
# those are byte-oriented: on macOS iconv renders "e" as "'e" and tr cannot
# lowercase multi-byte accented capitals at all.
SLUG="$(node -e 'const s=process.argv[1].normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase().replace(/[^a-z0-9]+/g,"-").replace(/^-+|-+$/g,""); process.stdout.write(s||"tuto")' "$TITLE")"

# --- shared filter chains -------------------------------------------------
# unsharp sharpens luma only (the trailing 0.0 zeroes the chroma amount):
# sharpening colour on a screen capture just adds fringing around text.
VF_ENHANCE="unsharp=5:5:0.85:5:5:0.0,eq=contrast=1.05:saturation=1.06:gamma=1.02"
[ "$VIDEO_DENOISE" -eq 1 ] && VF_ENHANCE="hqdn3d=1.2:1.0:5:5,$VF_ENHANCE"

# afftdn learns the noise profile from the quietest passages and subtracts it
# spectrally, which is what removes a fan or an air-conditioner without the
# underwater artefacts a plain gate produces. acompressor then lifts the quiet
# half of the delivery before loudnorm sets the absolute level, so the target
# is met by evening the voice out rather than by amplifying the room with it.
AF_ENHANCE="highpass=f=85,afftdn=nr=12:nf=-30:tn=1,acompressor=threshold=-20dB:ratio=3:attack=15:release=250:makeup=3,loudnorm=I=-14:TP=-1.5:LRA=11,alimiter=limit=0.95,aresample=48000"

ENCODER="${ENCODER:-libx264}"
if [ "$ENCODER" = "libx264" ]; then
  VENC="-c:v libx264 -preset $PRESET -crf $CRF"
else
  # e.g. ENCODER=h264_videotoolbox on macOS — far faster on older hardware,
  # at the cost of some quality per bit, so it is opt-in via the environment.
  VENC="-c:v $ENCODER -b:v 12M"
fi
AENC="-c:a aac -b:a 192k -ar 48000"

# Source facts the filter graphs need: whether there is a soundtrack at all
# (a capture made with every OBS audio source muted has none, and mapping a
# missing [0:a] aborts the whole run), and how long to make the substitute
# silence when there isn't one.
HAS_AUDIO="$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$INPUT" | head -1)"
DURATION="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$INPUT")"
DURATION="${DURATION:-0}"

OUTRO_9x16="$DIR/../outro/Outro_GuedeTech.mp4"
OUTRO_16x9="$DIR/../outro/Outro_GuedeTech_16x9.mp4"

echo "==> Tuto   : $TITLE"
echo "==> Source : $INPUT (${DURATION}s, audio: $([ -n "$HAS_AUDIO" ] && echo oui || echo non))"
echo "==> Sortie : $OUTDIR"

# ==========================================================================
# YouTube — 1920x1080
# ==========================================================================
if [ "$ONLY" = "both" ] || [ "$ONLY" = "youtube" ]; then
  echo "==> [1/2] YouTube 1920x1080..."

  TMP_WM_HTML="$DIR/_tmp_watermark.html"
  TMP_WM="$DIR/_tmp_watermark.png"
  sed -e "s#__LOGO_MARK_PATH__#${LOGO_MARK_PATH}#" \
      -e "s#__WM_POS__#pos-${WM_POS}#" \
      "$DIR/watermark_yt.html" > "$TMP_WM_HTML"
  TMP_WM_URL="file:///$(echo "$WINDIR/_tmp_watermark.html" | sed 's/ /%20/g')"
  "$CHROME" --headless --disable-gpu --no-sandbox --hide-scrollbars \
    --force-device-scale-factor=1 --default-background-color=00000000 \
    --window-size=1920,1080 --screenshot="$TMP_WM" "$TMP_WM_URL"

  if [ -n "$HAS_AUDIO" ]; then AMAIN="[0:a]$AF_ENHANCE[a0];"; else
    AMAIN="[3:a]atrim=duration=$DURATION,aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo[a0];"
  fi

  if [ "$WITH_OUTRO" -eq 1 ] && [ -f "$OUTRO_16x9" ]; then
    # Enhancement, watermark and the end-card join all happen in one graph so
    # the footage is encoded once instead of being written out and re-read.
    ffmpeg -y -hide_banner -loglevel warning -stats \
      -i "$INPUT" \
      -loop 1 -i "$TMP_WM" \
      -i "$OUTRO_16x9" \
      -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=48000" \
      -filter_complex "
        [0:v]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,setsar=1,$VF_ENHANCE,fps=30,format=yuv420p[v0];
        [v0][1:v]overlay=0:0:shortest=1,format=yuv420p[vy];
        $AMAIN
        [2:v]fps=30,scale=1920:1080,setsar=1,format=yuv420p[v1];
        [3:a]atrim=duration=6,aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo[a1];
        [vy][a0][v1][a1]concat=n=2:v=1:a=1[outv][outa]
      " \
      -map "[outv]" -map "[outa]" $VENC $AENC -movflags +faststart \
      "$OUTDIR/${SLUG}-youtube.mp4"
  else
    ffmpeg -y -hide_banner -loglevel warning -stats \
      -i "$INPUT" \
      -loop 1 -i "$TMP_WM" \
      -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=48000" \
      -filter_complex "
        [0:v]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,setsar=1,$VF_ENHANCE,fps=30,format=yuv420p[v0];
        [v0][1:v]overlay=0:0:shortest=1,format=yuv420p[outv];
        $(if [ -n "$HAS_AUDIO" ]; then echo "[0:a]$AF_ENHANCE[outa]"; else echo "[2:a]atrim=duration=$DURATION,aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo[outa]"; fi)
      " \
      -map "[outv]" -map "[outa]" $VENC $AENC -movflags +faststart \
      "$OUTDIR/${SLUG}-youtube.mp4"
  fi

  rm -f "$TMP_WM_HTML" "$TMP_WM"
  echo "    -> $OUTDIR/${SLUG}-youtube.mp4"
fi

# ==========================================================================
# TikTok / Reels / Shorts — 1080x1920
# ==========================================================================
if [ "$ONLY" = "both" ] || [ "$ONLY" = "tiktok" ]; then
  echo "==> [2/2] TikTok 1080x1920..."

  TMP_HTML="$DIR/_tmp_back.html"
  TMP_BG="$DIR/_tmp_back.png"
  # The subtitle is optional; an empty placeholder collapses the element via
  # the template's `.subtitle:empty { display:none }` rule.
  sed \
    -e "s#__LOGO_MARK_PATH__#${LOGO_MARK_PATH}#" \
    -e "s#__TITLE__#${TITLE}#" \
    -e "s#__SUBTITLE__#${SUBTITLE}#" \
    "$DIR/template_tuto_back.html" > "$TMP_HTML"
  TMP_HTML_URL="file:///$(echo "$WINDIR/_tmp_back.html" | sed 's/ /%20/g')"
  "$CHROME" --headless --disable-gpu --no-sandbox --hide-scrollbars \
    --force-device-scale-factor=1 --window-size=1080,1920 \
    --screenshot="$TMP_BG" "$TMP_HTML_URL"

  # 1012x570 / 34:850 come from gen_window_frame.js's INNER rect — the exact
  # hole in window_frame.png. Regenerate the frame with different geometry and
  # these three numbers must be updated to match.
  if [ -n "$HAS_AUDIO" ]; then AMAIN="[1:a]$AF_ENHANCE[a0];"; else
    AMAIN="[4:a]atrim=duration=$DURATION,aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo[a0];"
  fi

  if [ "$WITH_OUTRO" -eq 1 ] && [ -f "$OUTRO_9x16" ]; then
    ffmpeg -y -hide_banner -loglevel warning -stats \
      -loop 1 -i "$TMP_BG" \
      -i "$INPUT" \
      -loop 1 -i "$DIR/window_frame.png" \
      -i "$OUTRO_9x16" \
      -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=48000" \
      -filter_complex "
        [1:v]scale=1012:570:force_original_aspect_ratio=increase,crop=1012:570,setsar=1,$VF_ENHANCE[vid];
        [0:v][vid]overlay=34:850:shortest=1[bg1];
        [bg1][2:v]overlay=0:0:shortest=1,fps=30,format=yuv420p[vt];
        $AMAIN
        [3:v]fps=30,scale=1080:1920,setsar=1,format=yuv420p[v1];
        [4:a]atrim=duration=6,aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo[a1];
        [vt][a0][v1][a1]concat=n=2:v=1:a=1[outv][outa]
      " \
      -map "[outv]" -map "[outa]" $VENC $AENC -movflags +faststart \
      "$OUTDIR/${SLUG}-tiktok.mp4"
  else
    ffmpeg -y -hide_banner -loglevel warning -stats \
      -loop 1 -i "$TMP_BG" \
      -i "$INPUT" \
      -loop 1 -i "$DIR/window_frame.png" \
      -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=48000" \
      -filter_complex "
        [1:v]scale=1012:570:force_original_aspect_ratio=increase,crop=1012:570,setsar=1,$VF_ENHANCE[vid];
        [0:v][vid]overlay=34:850:shortest=1[bg1];
        [bg1][2:v]overlay=0:0:shortest=1,fps=30,format=yuv420p[outv];
        $(if [ -n "$HAS_AUDIO" ]; then echo "[1:a]$AF_ENHANCE[outa]"; else echo "[3:a]atrim=duration=$DURATION,aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo[outa]"; fi)
      " \
      -map "[outv]" -map "[outa]" $VENC $AENC -movflags +faststart \
      "$OUTDIR/${SLUG}-tiktok.mp4"
  fi

  rm -f "$TMP_HTML" "$TMP_BG"
  echo "    -> $OUTDIR/${SLUG}-tiktok.mp4"
fi

echo "Termine."

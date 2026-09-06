# Guédé Tech — Studio

Reference implementation for Guédé Tech's social media video pipelines.
Two of them, sharing one brand system, one set of assets and one end card:

- **`reel-template/`** — a phone screen recording of a *client project*
  becomes a branded vertical showcase (1080x1920).
- **`tuto-pipeline/`** — an OBS screen recording of a *coding session*
  becomes a finished tutorial, published in both formats at once:
  1920x1080 for YouTube and 1080x1920 for TikTok / Reels / Shorts.

This is **not** part of the guedetech.com website build — it never gets
deployed. It's a standalone command-line toolkit that happens to live in
this repo so it travels with the project and any AI/developer who opens
this folder can understand and reproduce it without being re-briefed.

## What it produces

Given a phone screen recording of a project (e.g. someone scrolling
`cafetoubaexpress.com` on their iPhone) and a project name, the pipeline
outputs a single MP4:

1. **The reel** — the recording, cropped to fill an iPhone-style frame
   mockup, sitting on a white branded background: Guédé Tech logo,
   "GUÉDÉ TECH", tagline, a solid navy "UN PROJET RÉALISÉ PAR GUÉDÉ TECH"
   badge, and the project's name as a title.
2. **The outro** — a fixed 6-second branded end-card, automatically
   appended: logo → name → tagline → "Un projet en tête ?" →
   "Contactez-nous" button → contact info, each fading in in sequence,
   then fading to white.

Given an OBS recording of a coding session and a tutorial title, the
tuto pipeline outputs **two** MP4s from that single capture:

1. **The YouTube cut** (1920x1080) — the capture, picture and sound
   enhanced, with a corner watermark, then the 16:9 end card appended.
2. **The vertical cut** (1080x1920) — the same capture seated inside a
   macOS-window mockup on the branded vertical layout (logo, title,
   optional hook line, contact block), then the 9:16 end card appended.

Both carry identical treatment: sharpening tuned for on-screen text, a
small contrast/saturation lift, and an audio chain of rumble filter →
spectral noise reduction → compression → loudness normalisation to
-14 LUFS, the level YouTube and TikTok both target (hit it yourself and
neither platform re-adjusts your upload).

## Prerequisites

- **Google Chrome** (or Chromium/Edge) — used headless, as a rendering
  engine for the HTML/CSS templates. Not a browser automation library:
  just `chrome --headless --screenshot=out.png page.html`.
- **ffmpeg** — does all actual video work (cropping, compositing,
  animation via fades, concatenation).
- **Node.js** — only for two small scripts that generate SVG geometry /
  split an HTML file into layers (no npm packages needed).
- **bash** — the scripts are POSIX shell. On Windows, Git Bash (which
  this project was built with) works fine.

No Puppeteer/Playwright, no video editing library, no GPU rendering
farm. Everything is "render a picture with a real browser, then let
ffmpeg do the mechanical part."

## Directory structure

```
studio/
├── README.md                    <- this file
├── find_chrome.sh                <- locates a Chrome/Chromium binary, sets $CHROME
├── append_outro.sh               <- joins a reel + the outro into the final video
├── assets/
│   ├── logo-guedetech.png        <- full logo (mark + "GUÉDÉ TECH" + tagline), 1254x1254
│   └── logo-mark.png             <- just the "G" circuit mark, cropped, transparent bg
├── reel-template/
│   ├── template_back.html        <- the branded background (logo/name/badge/title), white bg
│   ├── gen_frame.js               <- generates the iPhone bezel frame (frame.png) from SVG
│   ├── frame.png                  <- the generated iPhone frame (transparent, ready to use)
│   └── make_reel.sh               <- input video + project name -> one reel MP4
├── tuto-pipeline/
│   ├── template_tuto_back.html   <- branded 9:16 background (logo/title/hook/contact)
│   ├── watermark_yt.html          <- the 16:9 corner watermark, position-switchable
│   ├── gen_window_frame.js        <- generates the macOS-window bezel (window_frame.png)
│   ├── window_frame.png           <- the generated window frame (transparent, ready to use)
│   └── make_tuto.sh               <- OBS capture + title -> YouTube MP4 + TikTok MP4
└── outro/
    ├── outro_master.html          <- the outro's full layout (all 7 elements, final positions)
    ├── outro_master_16x9.html     <- the same end card re-flowed for 1920x1080
    ├── split_outro_layers.js      <- splits a master into 7 per-element transparent PNGs
    ├── make_outro.sh               <- regenerates either outro clip from its HTML
    ├── Outro_GuedeTech.mp4         <- the rendered 6s end card, 1080x1920
    └── Outro_GuedeTech_16x9.mp4    <- the rendered 6s end card, 1920x1080
```

## Quick start — produce one finished video

```bash
cd studio/reel-template
./make_reel.sh "/path/to/capture.mp4" "Nom Du Projet" reel.mp4
cd ..
./append_outro.sh reel-template/reel.mp4 final.mp4
```

`final.mp4` is ready to post. `Outro_GuedeTech.mp4` is a fixed asset —
you don't need to regenerate it per project, only if you want to change
the outro's text/design (see `outro/make_outro.sh`).

## Quick start — publish one tutorial

```bash
cd studio/tuto-pipeline
./make_tuto.sh ~/Movies/capture.mp4 "Créer une API REST en Node.js" \
  -s "Les 3 erreurs que font 90% des débutants"
```

Writes `out/creer-une-api-rest-en-node-js-youtube.mp4` (1920x1080) and
`out/creer-une-api-rest-en-node-js-tiktok.mp4` (1080x1920), each with the
matching end card already appended. Both are ready to upload as-is.

`-s` is the optional hook line printed under the title on the vertical
layout only — it is the sentence that has to stop a thumb, so it is worth
writing separately from the title. `./make_tuto.sh --help` lists the rest
(`--only`, `--no-outro`, `--filigrane`, `--denoise`, `--hq`).

## Design system

- **Canvas**: 1080x1920 (9:16) for everything vertical — the native
  TikTok/Reels/Stories format, so no platform-side cropping happens on
  upload — plus 1920x1080 (16:9) for the two YouTube-facing pieces (the
  tuto pipeline's landscape cut and `outro_master_16x9.html`). A template
  targets one of those two sizes exactly; nothing is ever authored at an
  in-between size and rescaled.
- **Colors**: brand navy `#0B3B60`, brand gold `#D4AF37`, white `#ffffff`
  background, muted slate `#334155`/`#64748b` for secondary text. These
  are the same values used on guedetech.com (see `src/routes/__root.tsx`
  and `tailwind`/CSS custom properties in the main site) — keep them in
  sync if the brand palette ever changes.
- **Fonts**: system UI stack (`'Segoe UI', Arial, sans-serif`), always
  bold (700-800 weight) for anything branded. No custom font loading —
  keeps the Chrome screenshot step dependency-free and fast.
- **Logo assets**: `logo-guedetech.png` is the original brand file (has
  a flattened near-white background with heavy padding around the mark
  — do NOT use it directly at small sizes, it reads as a blank square).
  `logo-mark.png` is a tight, transparent crop of just the circuit "G",
  produced once via a CSS `background-position`/`background-size` crop
  trick against the original (see git history of this session for the
  exact crop box: source region x:295,y:118,w:640,h:640 out of the
  1254x1254 original). Always prefer `logo-mark.png` for anything under
  ~300px.

## How the reel template works (`reel-template/`)

**Step 1 — render the background.** `template_back.html` has two text
placeholders, `__LOGO_MARK_PATH__` and `__PROJECT_NAME__`, filled in by
`make_reel.sh` via `sed`, then screenshotted by headless Chrome into a
flat 1080x1920 PNG. This is the *only* place text gets rendered — using
a real browser instead of ffmpeg's `drawtext` gives proper kerning,
bold web-safe fonts, flexbox centering, and multi-line wrapping for
free, none of which ffmpeg's text filters do well.

**Step 2 — the iPhone frame illusion.** `frame.png` is a transparent PNG
containing *only* the bezel: a metallic-gradient ring + side buttons +
Dynamic Island, generated by `gen_frame.js`. The ring is one SVG
`<path>` combining an outer rounded rect and an inner rounded rect with
`fill-rule="evenodd"` — that single rule is what makes it a hollow ring
with rounded corners on both edges, no manual masking. Critically: the
video underneath is **never actually rounded**. It's composited as a
plain rectangle into the ring's rectangular hole; then the ring is
drawn on top, and its opaque pixels simply cover whatever "poked out"
past the rounded inner boundary. Corner-rounding for free, zero alpha
masking of the video itself.

**Step 3 — composite.** One `ffmpeg` call does it in a single pass:
crop/scale the input video to exactly fill the frame's screen hole
(`scale=...:force_original_aspect_ratio=increase,crop=...`, i.e.
"cover" fit — crops excess rather than letterboxing), overlay it onto
the background at the hole's exact position, then overlay `frame.png`
on top of everything.

**Frame geometry** lives in `gen_frame.js` as one `OUTER` rect (with a
16px `BEZEL` producing `INNER`, the video hole). If you resize/reposition
the frame, `INNER`'s `x/y/w/h` must be copy-pasted into `make_reel.sh`'s
`scale=`/`crop=`/`overlay=` numbers — they're not read dynamically, they
were kept as plain numbers to avoid adding a JSON hand-off step for two
scripts that change together rarely. `gen_frame.js` has inline comments
explaining *why* the current numbers (`OUTER = {x:224,y:448,w:632,
h:1331,r:62}`) are what they are — short version: `INNER`'s aspect ratio
(~0.462) was tuned to match a real modern phone screen, because an
earlier, squarer version cropped too much off the top/bottom of real
capture videos.

## How the outro animation works (`outro/`)

There is no video-editing library and no frame-by-frame rendering here
either. `outro_master.html` lays out all 7 elements (logo, name,
tagline, divider, CTA eyebrow, CTA button, contact block) at their
**final** absolute positions on one 1080x1920 canvas — open it in a
browser and you see the fully-assembled end state.

`split_outro_layers.js` reads that one file and, for each element,
generates a variant where every *other* element is `visibility:hidden`
and the page background is transparent — so screenshotting each variant
yields a full-canvas PNG with only that one element visible, all sharing
identical coordinates. Do the same for a "background only" variant
(border frame + soft corner glows, no text) and you have 8 layers that,
stacked, reconstruct the exact same picture as the master file.

`make_outro.sh` then loops each PNG into a 6-second static clip and
applies ffmpeg's `fade=t=in:st=<time>:d=<duration>:alpha=1` to each
one — fading the **alpha channel**, not brightness, so it's a true
fade-in-from-transparent rather than a fade-from-black. Because the
elements are full-canvas layers with the content already in its final
position, no per-layer x/y animation is needed: `overlay=0:0` for all
of them, staggered only in *when* their alpha ramps up. The seven start
times are ~0.25-0.3s apart (see the timing table inside `make_outro.sh`)
so it reads as a deliberate reveal sequence rather than a single flash.
A final `fade=t=out:...:color=white` on the fully-composited output
fades the whole scene to white in the last 0.7s for a clean end.

## How the tutorial pipeline works (`tuto-pipeline/`)

Same two building blocks as the reel — a Chrome-rendered background and an
evenodd SVG ring composited over an unmasked video — pointed at a different
problem: an OBS capture is 16:9, and a tutorial has to ship to a landscape
platform and a portrait one from that single take.

**The landscape cut** is the capture itself: enhanced, watermarked, end card
appended. `watermark_yt.html` renders a corner "bug" — logo mark, name,
domain — onto a translucent white pill. The pill is not decoration: a
screencast cuts between a dark editor and a light browser, so flat navy text
would vanish against the first and flat white text against the second, while
the pill holds one fixed contrast ratio whatever passes underneath. It
defaults to the **bottom-left** corner because an OBS scene usually parks its
webcam inset bottom-right, and a logo laid over the presenter's face is the
one placement that always reads as a mistake; `--filigrane br|tl|tr` moves it.

**The vertical cut** seats that same 16:9 footage inside a macOS-window
mockup on the branded portrait layout. `gen_window_frame.js` is
`gen_frame.js`'s landscape sibling: one evenodd path (rounded outer rect
minus the video hole) plus three traffic lights and a gold hairline under the
title bar. The title bar is baked into the same PNG rather than kept separate
— it only ever renders against the background, never over the video, so it
costs nothing to include. Geometry is `OUTER = {x:20, y:806, w:1040, h:628}`
with a 44px title bar and a 14px bezel, giving `INNER = {x:34, y:850, w:1012,
h:570}`; as in the reel template those numbers are hand-carried into
`make_tuto.sh`'s `scale`/`crop`/`overlay` arguments.

Why a window mockup at all, rather than cropping 16:9 down to 9:16: cropping
throws away two thirds of the horizontal pixels, which on a code editor means
throwing away the code. Letterboxing the full frame keeps every character and
turns the leftover space into brand surface — logo and title above, contact
block below — instead of black bars.

**One encode per output.** Enhancement, compositing and the end-card join all
live in a single `filter_complex` per platform, so the footage is encoded
once rather than written to an intermediate file and read back. That is the
one deliberate departure from `make_reel.sh` + `append_outro.sh`'s two-step
shape: a tutorial is minutes long where a reel is seconds, and on modest
hardware the extra pass is the difference between a coffee and an afternoon.
For the same reason the default is `-preset veryfast -crf 20`, with `--hq`
switching to `medium`/CRF 18; screen content is cheap to encode and the
faster preset costs very little visible quality. Setting `ENCODER=` in the
environment (e.g. `h264_videotoolbox` on macOS) swaps in a hardware encoder.

**Audio.** `afftdn` learns the noise profile from the quietest passages and
subtracts it spectrally, which removes a fan or an air conditioner without
the underwater artefacts a plain gate produces. `acompressor` then lifts the
quiet half of the delivery *before* `loudnorm` sets the absolute level, so
the -14 LUFS target is met by evening the voice out rather than by amplifying
the room along with it. A capture whose audio sources were all muted in OBS
has no audio stream at all, which would abort the run when the filter graph
maps `[0:a]`; the script probes for one with `ffprobe` and substitutes
silence of the right duration when it is missing.

## Joining reel + outro (`append_outro.sh`)

Two mismatches would otherwise break a naive concat:
- `make_reel.sh`'s output has no explicit output frame rate pinned, so
  it defaults to ~25fps, while the outro is rendered at a fixed 30fps.
- The reel has an audio track (from the phone recording); the outro has
  none at all.

`append_outro.sh` re-times both video streams to 30fps and generates 6
seconds of silence (`anullsrc`, trimmed to the outro's exact length) as
the outro's audio, then joins `[video,audio]` pairs with ffmpeg's
`concat` **filter** (not the concat *demuxer*, which requires the two
inputs' codec parameters to already match bit-for-bit).

## Adapting this on a different machine

- Chrome path: `find_chrome.sh` auto-detects common install locations on
  Windows/macOS/Linux and sets `$CHROME`. If it can't find one, export
  `CHROME=/path/to/your/chrome` before running any script.
- Windows-specific path handling: `make_reel.sh` and `make_outro.sh`
  convert POSIX-style paths (`/c/Users/...`, from Git Bash) into
  Windows-style forward-slash paths (`C:/Users/...`) for Chrome's
  `file://` URLs, and percent-encode spaces in the *navigation* URL
  specifically (Chrome's headless `--screenshot` flag's URL argument
  needs `%20` for spaces; an `<img src>` *inside* the HTML tolerates raw
  spaces fine — these are two different parsers). On macOS/Linux this
  path-rewriting is a no-op since paths are already POSIX-style.
- Everything else is plain HTML/CSS/SVG/ffmpeg and portable as-is.

## Extending to a new project type

To reuse this for something that isn't a phone screen recording
(e.g. a desktop/browser capture), you'd want a different frame mockup
(a "browser window" bezel instead of an iPhone one) sized to a
landscape or square aspect ratio, composited the same way. The
technique (SVG ring via evenodd fill, then ffmpeg overlay) carries over
directly — only the geometry in `gen_frame.js` and the `scale`/`crop`/
`overlay` numbers in `make_reel.sh` need to change.

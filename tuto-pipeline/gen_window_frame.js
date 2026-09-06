// Generates window_frame.png: a transparent-background PNG containing ONLY
// a macOS-style app-window bezel (navy rounded shell + title bar + traffic
// lights), with a fully transparent rectangular hole where the screen
// recording gets composited by ffmpeg.
//
// This is the landscape counterpart to ../reel-template/gen_frame.js: same
// evenodd-ring trick, different mockup. See that file for the full
// explanation of why the video underneath never needs alpha masking — the
// ring's opaque pixels simply paint over the raw video's square corners
// wherever they poke past the rounded inner boundary.
//
// Run via make_tuto.sh (does the Chrome screenshot step too), or directly:
//   node gen_window_frame.js && chrome --headless --disable-gpu --no-sandbox \
//     --hide-scrollbars --force-device-scale-factor=1 \
//     --default-background-color=00000000 --window-size=1080,1920 \
//     --screenshot=window_frame.png file:///.../window_frame.html

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function roundedRectPath(x, y, w, h, r) {
  const x2 = x + w, y2 = y + h;
  return `M ${x + r},${y} H ${x2 - r} A ${r} ${r} 0 0 1 ${x2},${y + r} V ${y2 - r} A ${r} ${r} 0 0 1 ${x2 - r},${y2} H ${x + r} A ${r} ${r} 0 0 1 ${x},${y2 - r} V ${y + r} A ${r} ${r} 0 0 1 ${x + r},${y} Z`;
}

// Canvas is 1080x1920 (9:16 — TikTok / Reels / Shorts), same as every other
// template here. Unlike the phone mockup, the hole is LANDSCAPE: an OBS
// screen capture is 16:9, and cropping that to a portrait slot would throw
// away most of the code on screen. So the window is made as wide as the
// canvas allows and the 16:9 recording sits inside it at full width.
//
// TITLEBAR is part of the frame (opaque, above the hole) rather than a
// separate asset — it only ever renders on top of the background, never
// over the video, so it costs nothing to bake into the same PNG.
const TITLEBAR = 44;
const BEZEL = 14;
const OUTER = { x: 20, y: 806, w: 1040, h: 628, r: 22 };
const INNER = {
  x: OUTER.x + BEZEL,
  y: OUTER.y + TITLEBAR,
  w: OUTER.w - BEZEL * 2,
  h: OUTER.h - TITLEBAR - BEZEL,
  r: 4,
};
// INNER = { x: 34, y: 850, w: 1012, h: 570 }
// -> these x/y/w/h feed directly into make_tuto.sh's ffmpeg filter:
//      scale=1012:570:force_original_aspect_ratio=increase,crop=1012:570
//      overlay=34:850
// 1012x570 is 1.7754:1 against 16:9's 1.7778:1 — a ~1px crop on a 1080p
// source, i.e. visually nothing, and both numbers stay even (required by
// yuv420p chroma subsampling).

const svgRingPath =
  roundedRectPath(OUTER.x, OUTER.y, OUTER.w, OUTER.h, OUTER.r) +
  ' ' +
  roundedRectPath(INNER.x, INNER.y, INNER.w, INNER.h, INNER.r);

// Traffic lights, vertically centred in the title bar.
const dotY = OUTER.y + TITLEBAR / 2;
const dots = [
  { cx: OUTER.x + 30, fill: '#FF5F57' },
  { cx: OUTER.x + 56, fill: '#FEBC2E' },
  { cx: OUTER.x + 82, fill: '#28C840' },
];

const html = `<!DOCTYPE html>
<html><head><style>
  * { margin:0; padding:0; }
  html,body { width:1080px; height:1920px; background:transparent; }
</style></head>
<body>
<svg width="1080" height="1920" viewBox="0 0 1080 1920" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="shellGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#14496f"/>
      <stop offset="18%" stop-color="#0B3B60"/>
      <stop offset="100%" stop-color="#082C49"/>
    </linearGradient>
    <filter id="winShadow" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="22" stdDeviation="30" flood-color="#0B3B60" flood-opacity="0.34"/>
    </filter>
  </defs>

  <!-- window shell, evenodd fill = outer rect minus the video hole -->
  <path fill-rule="evenodd" fill="url(#shellGrad)" filter="url(#winShadow)" d="${svgRingPath}" />

  <!-- gold hairline along the title bar's lower edge, brand accent -->
  <rect x="${INNER.x}" y="${INNER.y - 2}" width="${INNER.w}" height="2" fill="#D4AF37" opacity="0.85" />

  <!-- traffic lights -->
  ${dots.map((d) => `<circle cx="${d.cx}" cy="${dotY}" r="8" fill="${d.fill}" />`).join('\n  ')}
</svg>
</body></html>
`;

fs.writeFileSync(path.join(__dirname, 'window_frame.html'), html);
console.log('OUTER', OUTER);
console.log('INNER', INNER);
console.log('window_frame.html written');

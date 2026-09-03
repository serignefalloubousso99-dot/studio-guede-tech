// Generates frame.png: a transparent-background PNG containing ONLY the
// iPhone-style bezel (metallic gradient ring + side buttons + Dynamic
// Island), with a fully transparent rounded-rect hole where the screen
// recording gets composited by ffmpeg.
//
// How the "rounded corners on the video" illusion works without any video
// masking: the bezel ring is drawn as a single SVG path using two nested
// rounded rectangles combined with fill-rule="evenodd" (outer rect minus
// inner rect = a ring/annulus with rounded inner AND outer corners). When
// this ring is composited ON TOP of the raw rectangular video (which has
// sharp square corners), the ring's opaque pixels simply paint over the
// video's corner "poke-through" wherever it falls outside the rounded
// inner boundary — no alpha masking of the video itself needed.
//
// Run via make_reel.sh (does the Chrome screenshot step too), or directly:
//   node gen_frame.js && chrome --headless --disable-gpu --no-sandbox \
//     --hide-scrollbars --force-device-scale-factor=1 \
//     --default-background-color=00000000 --window-size=1080,1920 \
//     --screenshot=frame.png file:///.../reel_frame.html

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function roundedRectPath(x, y, w, h, r) {
  const x2 = x + w, y2 = y + h;
  return `M ${x + r},${y} H ${x2 - r} A ${r} ${r} 0 0 1 ${x2},${y + r} V ${y2 - r} A ${r} ${r} 0 0 1 ${x2 - r},${y2} H ${x + r} A ${r} ${r} 0 0 1 ${x},${y2 - r} V ${y + r} A ${r} ${r} 0 0 1 ${x + r},${y} Z`;
}

// Canvas is always 1080x1920 (9:16 — TikTok / Instagram Reels & Stories).
// These exact numbers are the result of iterating against user feedback:
//   1. First pass used a squarer slot (608x1074) sized to leave room for a
//      large brand/title text block above it — user said it cropped too
//      much off the top/bottom of real phone-screen recordings.
//   2. Fixed by sizing INNER's aspect ratio to ~0.462, matching a real
//      modern phone screen (e.g. iPhone 14 Pro: 1290x2796 = 0.4614), which
//      also happens to match this project's actual capture videos
//      (1170x2532 = 0.4622) almost exactly, so effectively zero cropping.
//   3. OUTER.y was pushed down to 448 (from an initial 366) to make room
//      for the enlarged brand block (logo 150px, "GUÉDÉ TECH" 50px, the
//      solid navy "UN PROJET RÉALISÉ PAR GUÉDÉ TECH" pill-badge, and the
//      project title) that sits above the phone frame — see
//      ../reel-template/template_back.html for that layout's own math.
const OUTER = { x: 224, y: 448, w: 632, h: 1331, r: 62 };
const BEZEL = 16;
const INNER = {
  x: OUTER.x + BEZEL,
  y: OUTER.y + BEZEL,
  w: OUTER.w - BEZEL * 2,
  h: OUTER.h - BEZEL * 2,
  r: 46,
};
// INNER = { x: 240, y: 464, w: 600, h: 1299, r: 46 }
// -> these x/y/w/h feed directly into make_reel.sh's ffmpeg filter:
//      scale=600:1299:force_original_aspect_ratio=increase,crop=600:1299
//      overlay=240:464

const svgRingPath =
  roundedRectPath(OUTER.x, OUTER.y, OUTER.w, OUTER.h, OUTER.r) +
  ' ' +
  roundedRectPath(INNER.x, INNER.y, INNER.w, INNER.h, INNER.r);

// Dynamic Island
const islandW = 128, islandH = 36;
const islandX = 540 - islandW / 2;
const islandY = INNER.y + 16;

// Side buttons (iPhone-style): mute switch + volume up/down on the left,
// a longer power button on the right. Small rounded nubs protruding
// outward from the outer bezel edge.
const btnDepth = 7; // how far they stick out
function leftButton(yTop, h, w = 6) {
  return { x: OUTER.x - btnDepth, y: yTop, w: btnDepth + w, h, rx: 3 };
}
function rightButton(yTop, h, w = 6) {
  return { x: OUTER.x + OUTER.w - w, y: yTop, w: btnDepth + w, h, rx: 3 };
}
const muteSwitch = leftButton(OUTER.y + 96, 46);
const volUp = leftButton(OUTER.y + 168, 84);
const volDown = leftButton(OUTER.y + 264, 84);
const powerBtn = rightButton(OUTER.y + 190, 130);

function rectTag(b) {
  return `<rect x="${b.x}" y="${b.y}" width="${b.w}" height="${b.h}" rx="${b.rx}" fill="url(#bezelGrad)" filter="url(#btnShadow)"/>`;
}

const html = `<!DOCTYPE html>
<html><head><style>
  * { margin:0; padding:0; }
  html,body { width:1080px; height:1920px; background:transparent; }
</style></head>
<body>
<svg width="1080" height="1920" viewBox="0 0 1080 1920" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bezelGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#3a4f66"/>
      <stop offset="12%" stop-color="#16293c"/>
      <stop offset="50%" stop-color="#0a1c2e"/>
      <stop offset="88%" stop-color="#0d2135"/>
      <stop offset="100%" stop-color="#2a3f54"/>
    </linearGradient>
    <linearGradient id="rimHighlight" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#6b7d90" stop-opacity="0.9"/>
      <stop offset="50%" stop-color="#0a1c2e" stop-opacity="0"/>
      <stop offset="100%" stop-color="#000000" stop-opacity="0.5"/>
    </linearGradient>
    <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="20" stdDeviation="28" flood-color="#000000" flood-opacity="0.42"/>
    </filter>
    <filter id="btnShadow" x="-80%" y="-40%" width="260%" height="180%">
      <feDropShadow dx="1" dy="0" stdDeviation="1.2" flood-color="#000000" flood-opacity="0.35"/>
    </filter>
  </defs>

  <!-- main bezel ring (metallic gradient), evenodd fill = outer minus inner -->
  <path fill-rule="evenodd" fill="url(#bezelGrad)" filter="url(#shadow)" d="${svgRingPath}" />
  <!-- thin rim-light stroke for a titanium edge feel -->
  <path fill-rule="evenodd" fill="url(#rimHighlight)" opacity="0.5" d="${roundedRectPath(OUTER.x, OUTER.y, OUTER.w, OUTER.h, OUTER.r)} ${roundedRectPath(OUTER.x + 3, OUTER.y + 3, OUTER.w - 6, OUTER.h - 6, OUTER.r - 3)}" />

  <!-- side buttons -->
  ${rectTag(muteSwitch)}
  ${rectTag(volUp)}
  ${rectTag(volDown)}
  ${rectTag(powerBtn)}

  <!-- Dynamic Island -->
  <rect x="${islandX}" y="${islandY}" width="${islandW}" height="${islandH}" rx="${islandH / 2}" fill="#000000" />
  <circle cx="${islandX + islandW - 22}" cy="${islandY + islandH / 2}" r="5" fill="#132033" />
</svg>
</body></html>
`;

fs.writeFileSync(path.join(__dirname, 'reel_frame.html'), html);
console.log('OUTER', OUTER);
console.log('INNER', INNER);
console.log('reel_frame.html written');

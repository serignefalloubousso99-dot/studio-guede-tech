// Splits outro_master.html into one transparent-background PNG-ready HTML
// file per animated element (plus one opaque background layer), all sharing
// the exact same absolute positions from the master file. This lets ffmpeg
// fade/overlay each element independently to build the staggered reveal.
//
// Run via make_outro.sh (which also does the Chrome screenshot + ffmpeg
// composite steps). Requires Node.js only for this step.

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const DIR = path.dirname(fileURLToPath(import.meta.url));
const LOGO_MARK_PATH = path.join(DIR, '..', 'assets', 'logo-mark.png').replace(/\\/g, '/');

const master = fs
  .readFileSync(path.join(DIR, 'outro_master.html'), 'utf8')
  .replaceAll('__LOGO_MARK_PATH__', LOGO_MARK_PATH);

const elementIds = ['logo', 'name', 'tag', 'divider', 'cta-eyebrow', 'cta-button', 'contact'];

function makeVariant(targetId) {
  const hideCss = elementIds
    .filter((id) => id !== targetId)
    .map((id) => `#${id} { visibility: hidden !important; }`)
    .join('\n');
  const css = `<style>
    body, html { background: transparent !important; }
    .canvas { background: transparent !important; }
    .border-frame, .glow-blue, .glow-gold { display: none !important; }
    ${hideCss}
  </style></head>`;
  return master.replace('</head>', css);
}

for (const id of elementIds) {
  fs.writeFileSync(path.join(DIR, `layer_${id}.html`), makeVariant(id));
}

// background-only variant: opaque white canvas with border-frame + glows,
// all animated elements hidden (they're composited back in as separate layers)
const bgCss = `<style>
  ${elementIds.map((id) => `#${id} { visibility: hidden !important; }`).join('\n')}
</style></head>`;
fs.writeFileSync(path.join(DIR, 'layer_background.html'), master.replace('</head>', bgCss));

console.log('layers written:', elementIds.join(', '), '+ background');

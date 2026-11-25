#!/usr/bin/env node
// design/tokens.json -> tokens.css (+ optional theme.ts for React Native). Node stdlib only.
// Usage: node build-tokens.mjs <tokens.json> --css <out.css> [--ts <out.ts>] [--check]
// The CLI is the stage-3 lock gate: it lists every empty value and exits 1 without writing.
// toCss/toTs stay tolerant of empty values so the blank template can still be rendered.
import { readFileSync, realpathSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { parseColor, toHex } from './lib/color.mjs';

// Flat [cssName, value] pairs for every group that is not theme-specific.
function sharedVars(t) {
  const out = [];
  const add = (group, prefix, rename = (k) => k) => {
    for (const [k, v] of Object.entries(t[group] ?? {})) out.push([`${prefix}${rename(k)}`, v]);
  };
  add('font', '--font-');
  add('text', '--text-', (k) => (k === 'min-px' ? 'min' : k));
  add('leading', '--leading-');
  add('tracking', '--tracking-');
  add('space', '--space-');
  add('radius', '--radius-');
  add('motion', '--');
  add('focus', '--focus-');
  add('layout', '--');
  return out.map(([n, v]) => [n, n === '--text-min' ? minPx(v) : v]);
}

// text.min-px is a number of px: 12 and "12" become "12px", "12px" stays, "" stays empty.
function minPx(v) {
  if (typeof v === 'number' && Number.isFinite(v)) return `${v}px`;
  const s = String(v).trim();
  if (s === '') return '';
  const m = /^(\d+(?:\.\d+)?)(px)?$/.exec(s);
  if (!m) throw new Error(`text.min-px must be a number of px: ${v}`);
  return `${m[1]}px`;
}

function themeVars(t, theme) {
  const colors = Object.entries(t.color?.[theme] ?? {}).map(([k, v]) => [`--${k}`, v]);
  const shadows = Object.entries(t.shadow?.[theme] ?? {}).map(([k, v]) => [`--shadow-${k}`, v]);
  return [...colors, ...shadows];
}

const decls = (pairs, indent) => pairs.map(([n, v]) => `${indent}${n}: ${v};`).join('\n');

export function toCss(t) {
  // Every time token stops, the skeleton pulse (skeleton-dur) too.
  const reduced = Object.keys(t.motion ?? {}).filter((k) => k.startsWith('dur-') || k.endsWith('-dur'));
  const darkBody = decls(themeVars(t, 'dark'), '  ');
  return [
    '/* Generated from design/tokens.json by build-tokens.mjs. Edit the JSON, not this file. */',
    ':root {',
    decls([...themeVars(t, 'light'), ...sharedVars(t)], '  '),
    '}',
    '@media (prefers-color-scheme: dark) {',
    '  :root:not([data-theme="light"]) {',
    decls(themeVars(t, 'dark'), '    '),
    '  }',
    '}',
    ':root[data-theme="dark"] {',
    darkBody,
    '}',
    '@media (prefers-reduced-motion: reduce) {',
    `  :root {\n${decls(reduced.map((k) => [`--${k}`, '0ms']), '    ')}\n  }`,
    '}',
    '',
  ].join('\n');
}

const camel = (k) => k.replace(/-([a-z0-9])/g, (_, c) => c.toUpperCase());
const camelKeys = (o, f = (v) => v) => Object.fromEntries(Object.entries(o ?? {}).map(([k, v]) => [camel(k), f(v)]));

// "16px" -> 16, "1.5rem" -> 24, "1.5" -> 1.5, numbers stay numbers; everything else is passed through.
function toNumber(v) {
  if (typeof v === 'number') return v;
  const m = /^([+-]?(?:\d+\.?\d*|\.\d+))(px|rem)?$/.exec(String(v).trim());
  if (!m) return v;
  return m[2] === 'rem' ? parseFloat(m[1]) * 16 : parseFloat(m[1]);
}

// React Native takes one family name, not a CSS stack: "Inter, sans-serif" -> "Inter".
const firstFamily = (v) => String(v).split(',')[0].trim().replace(/^['"]|['"]$/g, '');

// "120ms" -> 120: Animated takes milliseconds; easing curves pass through.
function toMs(v) {
  const m = /^(\d+(?:\.\d+)?)ms$/.exec(String(v).trim());
  return m ? parseFloat(m[1]) : v;
}

// "-0.02em" -> -0.02: React Native letterSpacing and lineHeight are points, so theme.ts keeps both as
// multiples of the font size (leading is already unitless); a component multiplies by its text size.
function toEm(v) {
  const m = /^([+-]?(?:\d+\.?\d*|\.\d+))em$/.exec(String(v).trim());
  return m ? parseFloat(m[1]) : toNumber(v);
}

// Unfilled tokens ("") stay "" so the empty template still builds; anything else must parse.
const hexOrEmpty = (v) => (v === '' ? '' : toHex(parseColor(v)));

export function toTs(t) {
  const theme = {
    light: camelKeys(t.color?.light, hexOrEmpty),
    dark: camelKeys(t.color?.dark, hexOrEmpty),
    shadow: { light: camelKeys(t.shadow?.light), dark: camelKeys(t.shadow?.dark) },
    font: camelKeys(t.font, firstFamily),
    text: camelKeys(t.text, toNumber),
    leading: camelKeys(t.leading, toNumber),
    tracking: camelKeys(t.tracking, toEm),
    space: camelKeys(t.space, toNumber),
    radius: camelKeys(t.radius, toNumber),
    motion: camelKeys(t.motion, toMs),
    focus: camelKeys(t.focus, toNumber),
    layout: camelKeys(t.layout, toNumber),
  };
  return `// Generated from design/tokens.json by build-tokens.mjs. Edit the JSON, not this file.\n// leading and tracking are multiples of the font size: lineHeight = size * leading.\nexport const theme = ${JSON.stringify(theme, null, 2)} as const;\n`;
}

// Dotted paths of every empty leaf ("" or blank string, null).
export function emptyPaths(t, prefix = '') {
  const out = [];
  for (const [k, v] of Object.entries(t ?? {})) {
    const path = prefix ? `${prefix}.${k}` : k;
    if (v === null || (typeof v === 'string' && v.trim() === '')) out.push(path);
    else if (typeof v === 'object') out.push(...emptyPaths(v, path));
  }
  return out;
}

const USAGE = 'usage: build-tokens.mjs <tokens.json> --css <out.css> [--ts <out.ts>] [--check]';

function readOr(f) {
  try {
    return readFileSync(f, 'utf8');
  } catch {
    return null;
  }
}

function usage() {
  console.error(USAGE);
  process.exit(2);
}

function main(argv) {
  const [src, ...rest] = argv;
  // A flag's value must follow it and must not be another flag ("--css --ts x" is a usage error).
  const flag = (name) => {
    const i = rest.indexOf(name);
    if (i === -1) return undefined;
    const v = rest[i + 1];
    if (v === undefined || v.startsWith('--')) usage();
    return v;
  };
  const css = flag('--css');
  const ts = flag('--ts');
  if (!src || src.startsWith('--') || !css) usage();
  let tokens;
  try {
    tokens = JSON.parse(readFileSync(src, 'utf8'));
  } catch (err) {
    console.error(`cannot read ${src}: ${err.message}`);
    process.exit(1);
  }
  const empty = emptyPaths(tokens);
  if (empty.length) {
    console.error(`${src}: ${empty.length} empty value(s); fill them or delete keys the project does not use:`);
    for (const p of empty) console.error(`  ${p}`);
    process.exit(1);
  }
  try {
    // Render both before writing either, so a bad value leaves no half-written output.
    const cssOut = toCss(tokens);
    const tsOut = ts ? toTs(tokens) : null;
    if (rest.includes('--check')) {
      // The gate form: the contrast check reads tokens.json, so what ships must equal what it would generate.
      const stale = [[css, cssOut], [ts, tsOut]].filter(([f, out]) => f && readOr(f) !== out).map(([f]) => f);
      if (stale.length) {
        console.error(`stale or hand-edited: ${stale.join(' ')}; edit ${src} and run build-tokens.mjs without --check`);
        process.exit(1);
      }
      return;
    }
    writeFileSync(css, cssOut);
    if (ts) writeFileSync(ts, tsOut);
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
}

// import.meta.url is the realpath, argv[1] may go through a symlink: compare realpaths.
function isMain() {
  const self = fileURLToPath(import.meta.url);
  try {
    return realpathSync(process.argv[1]) === self;
  } catch {
    return process.argv[1] === self;
  }
}

if (isMain()) main(process.argv.slice(2));

#!/usr/bin/env node
// Contrast gate: checks every [fg, bg, min] token pair in both themes. Node stdlib only.
// Usage: node check-contrast.mjs <tokens.json> <contrast-pairs.json>
// A translucent background is composited over the theme's opaque `bg` token first, which is how
// the page (or a React Native view given #rrggbbaa) shows it.
import { readFileSync, realpathSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { contrastRatio, flatten, isOpaque } from './lib/color.mjs';

const THEMES = ['light', 'dark'];

// Bad tokens or pairs: the gate prints the message and exits 1 (exit 2 stays for usage).
export class TokenError extends Error {
  constructor(message) {
    super(message);
    this.name = 'TokenError';
  }
}

function tokenValue(tokens, theme, name) {
  const value = tokens?.color?.[theme]?.[name];
  if (typeof value !== 'string' || value.trim() === '') {
    throw new TokenError(`token missing: color.${theme}.${name}`);
  }
  return value;
}

function background(tokens, theme, name) {
  const value = tokenValue(tokens, theme, name);
  if (isOpaque(value)) return value;
  const page = tokenValue(tokens, theme, 'bg');
  if (!isOpaque(page)) {
    throw new TokenError(`color.${theme}.bg must be opaque: translucent backgrounds are composited over it`);
  }
  return flatten(value, page);
}

export function validatePairs(pairs) {
  if (!Array.isArray(pairs)) throw new TokenError('contrast pairs must be a JSON array of [fg, bg, min]');
  pairs.forEach((p, i) => {
    const ok = Array.isArray(p) && p.length === 3
      && typeof p[0] === 'string' && p[0] !== '' && typeof p[1] === 'string' && p[1] !== ''
      && typeof p[2] === 'number' && Number.isFinite(p[2]) && p[2] > 0;
    if (!ok) throw new TokenError(`contrast pair ${i} must be [fg, bg, min] (two token names, a positive number): ${JSON.stringify(p)}`);
  });
}

export function checkPairs(tokens, pairs) {
  validatePairs(pairs);
  const results = [];
  for (const theme of THEMES) {
    for (const [fg, bg, min] of pairs) {
      const ratio = contrastRatio(tokenValue(tokens, theme, fg), background(tokens, theme, bg));
      results.push({ theme, fg, bg, ratio, min, ok: ratio >= min });
    }
  }
  return results;
}

function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch (err) {
    throw new TokenError(`cannot read ${path}: ${err.message}`);
  }
}

function main(argv) {
  const [tokensPath, pairsPath] = argv;
  if (!tokensPath || !pairsPath) {
    console.error('usage: check-contrast.mjs <tokens.json> <contrast-pairs.json>');
    process.exit(2);
  }
  let pairs;
  let results;
  try {
    const tokens = readJson(tokensPath);
    pairs = readJson(pairsPath);
    results = checkPairs(tokens, pairs);
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
  const failed = results.filter((r) => !r.ok);
  // Floor so a near miss never prints as "4.5 < 4.5".
  for (const r of failed) {
    console.log(`FAIL ${r.theme} ${r.fg} on ${r.bg} ${(Math.floor(r.ratio * 10) / 10).toFixed(1)} < ${r.min}`);
  }
  if (failed.length) process.exit(1);
  console.log(`contrast: ${pairs.length} pairs × ${THEMES.length} themes ok`);
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

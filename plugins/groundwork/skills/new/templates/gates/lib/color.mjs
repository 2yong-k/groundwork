// Color parsing and WCAG 2 contrast. Node stdlib only.
// parseColor returns sRGB channels in 0..1 plus alpha. Out-of-gamut values are clamped.

const clamp01 = (x) => Math.min(1, Math.max(0, x));

function fail(input) {
  return new Error(`unsupported color: ${input}`);
}

function parseHex(input, raw) {
  if (!/^[0-9a-f]+$/i.test(raw) || ![3, 4, 6, 8].includes(raw.length)) throw fail(input);
  const full = raw.length <= 4 ? [...raw].map((c) => c + c).join('') : raw;
  const byte = (i) => parseInt(full.slice(i, i + 2), 16) / 255;
  return { r: byte(0), g: byte(2), b: byte(4), a: full.length === 8 ? byte(6) : 1 };
}

// "50%" -> 0.5 * pctBase, "0.5" -> 0.5. Anything else throws.
function num(token, input, pctBase = 1) {
  const m = /^([+-]?(?:\d+\.?\d*|\.\d+))(%|deg|turn)?$/i.exec(token);
  if (!m) throw fail(input);
  const v = parseFloat(m[1]);
  if (m[2] === '%') return (v / 100) * pctBase;
  if (m[2] && m[2].toLowerCase() === 'turn') return v * 360;
  return v;
}

function hslToRgb(h, s, l) {
  const hue = (((h % 360) + 360) % 360) / 360;
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  const p = 2 * l - q;
  const ch = (t) => {
    const x = (t + 1) % 1;
    if (x < 1 / 6) return p + (q - p) * 6 * x;
    if (x < 1 / 2) return q;
    if (x < 2 / 3) return p + (q - p) * (2 / 3 - x) * 6;
    return p;
  };
  return { r: ch(hue + 1 / 3), g: ch(hue), b: ch(hue - 1 / 3) };
}

const encodeGamma = (c) => (c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055);
const decodeGamma = (c) => (c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4));

function oklchToRgb(L, C, hDeg) {
  const h = (hDeg * Math.PI) / 180;
  const a = C * Math.cos(h);
  const b = C * Math.sin(h);
  const l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3;
  const m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3;
  const s = (L - 0.0894841775 * a - 1.291485548 * b) ** 3;
  return {
    r: encodeGamma(clamp01(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s)),
    g: encodeGamma(clamp01(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s)),
    b: encodeGamma(clamp01(-0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s)),
  };
}

export function parseColor(input) {
  if (typeof input !== 'string') throw fail(String(input));
  const s = input.trim();
  if (s.startsWith('#')) return parseHex(input, s.slice(1));
  const fn = /^(rgba?|hsla?|oklch)\(\s*([^)]*?)\s*\)$/i.exec(s);
  if (!fn) throw fail(input);
  const name = fn[1].toLowerCase().replace(/a$/, '');
  const [main, alphaPart, ...extra] = fn[2].split('/').map((x) => x.trim());
  if (extra.length) throw fail(input);
  const parts = main.split(/[\s,]+/).filter(Boolean);
  let alphaToken = alphaPart;
  if (alphaToken === undefined && parts.length === 4) alphaToken = parts.pop();
  if (parts.length !== 3) throw fail(input);
  const a = alphaToken === undefined ? 1 : clamp01(num(alphaToken, input));
  if (name === 'rgb') {
    const [r, g, b] = parts.map((p) => clamp01(num(p, input, 255) / 255));
    return { r, g, b, a };
  }
  if (name === 'hsl') {
    // CSS Color 4: a bare number is a percentage here, so hsl(220 15 40) is hsl(220 15% 40%).
    const pct = (p) => clamp01(p.endsWith('%') ? num(p, input) : num(p, input) / 100);
    const rgb = hslToRgb(num(parts[0], input), pct(parts[1]), pct(parts[2]));
    return { ...rgb, a };
  }
  return { ...oklchToRgb(clamp01(num(parts[0], input)), Math.max(0, num(parts[1], input, 0.4)), num(parts[2], input)), a };
}

export function toHex(c) {
  const byte = (x) => Math.round(clamp01(x) * 255).toString(16).padStart(2, '0');
  const rgb = `#${byte(c.r)}${byte(c.g)}${byte(c.b)}`;
  return c.a < 1 ? rgb + byte(c.a) : rgb;
}

function luminance({ r, g, b }) {
  return 0.2126 * decodeGamma(r) + 0.7152 * decodeGamma(g) + 0.0722 * decodeGamma(b);
}

// Quantize to 8-bit like toHex does, so the ratio matches what a hex-only consumer sees.
const quantize = (input) => parseColor(toHex(parseColor(input)));

// True when the color has no alpha left after quantizing (what a #rrggbb consumer sees).
export function isOpaque(input) {
  return quantize(input).a >= 1;
}

// Composites a translucent color over an opaque base, the way a screen shows it. Returns #rrggbb.
export function flatten(top, base) {
  const t = quantize(top);
  const b = quantize(base);
  if (b.a < 1) throw new Error(`flatten: base must be opaque: ${base}`);
  const mix = (k) => t[k] * t.a + b[k] * (1 - t.a);
  return toHex({ r: mix('r'), g: mix('g'), b: mix('b'), a: 1 });
}

// WCAG 2 contrast. fg alpha is composited over bg. A translucent bg has no single contrast
// (it depends on what lies under it), so it must be flattened first.
export function contrastRatio(fg, bg) {
  const f = quantize(fg);
  const b = quantize(bg);
  if (b.a < 1) throw new Error(`contrastRatio: bg must be opaque, flatten it first: ${bg}`);
  const mixed = {
    r: f.r * f.a + b.r * (1 - f.a),
    g: f.g * f.a + b.g * (1 - f.a),
    b: f.b * f.a + b.b * (1 - f.a),
  };
  const [hi, lo] = [luminance(mixed), luminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
}

// Automated accessibility floor for the web UI: axe's WCAG rules plus a keyboard walk.
// Add every new screen to ROUTES, but not the dev-only kit: it may be missing from the build.
// Axe finds only part of the WCAG failures, so DESIGN.md still applies.
import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

const ROUTES = ["/"];
// Every route runs at the default size and again at phone width, where overlap and overflow show first.
const VIEWPORTS = [
  { name: "default", size: null },
  { name: "phone", size: { width: 390, height: 844 } },
];
const CASES = VIEWPORTS.flatMap((viewport) => ROUTES.map((route) => ({ ...viewport, route })));
const WCAG_TAGS = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"];
const MAX_TABS = 50;

for (const { name, size, route } of CASES) {
  test(`${route} (${name}) has no WCAG violations`, async ({ page }) => {
    if (size) await page.setViewportSize(size);
    await page.goto(route);
    const { violations } = await new AxeBuilder({ page }).withTags(WCAG_TAGS).analyze();
    const found = violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target).join(", ")}`);
    expect(found).toEqual([]);
  });

  // An empty skeleton has nothing to focus, so it passes until the first control appears.
  test(`${route} (${name}) shows a focus ring at every Tab stop`, async ({ page }) => {
    if (size) await page.setViewportSize(size);
    await page.goto(route);
    const missing: string[] = [];
    let first: number | null = null;
    for (let i = 0; i < MAX_TABS; i++) {
      await page.keyboard.press("Tab");
      const stop = await page.evaluate(() => {
        const el = document.activeElement;
        if (!el || el === document.body) return null;
        const style = getComputedStyle(el);
        // A transparent outline is how CSS frameworks hide the ring and keep it for forced-colors mode.
        const clear = /^rgba\(.*,\s*0\)$|\/\s*0\)$/.test(style.outlineColor);
        const ring = style.outlineStyle !== "none" && style.outlineWidth !== "0px" && !clear;
        const index = Array.from(document.querySelectorAll("*")).indexOf(el);
        return { index, html: el.outerHTML.slice(0, 80), ring };
      });
      if (stop === null || stop.index === first) break;
      first ??= stop.index;
      if (!stop.ring) missing.push(stop.html);
    }
    expect(missing).toEqual([]);
  });
}

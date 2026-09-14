/**
 * flash.ts — radial burst overlay flash when a wish is granted.
 * Gated behind prefers-reduced-motion.
 */

import { reducedMotion } from "./env.js";

export function grantFlash(x: number, y: number): void {
  if (reducedMotion()) return;
  const el = document.getElementById("grant-flash");
  if (!el) return;
  el.style.setProperty("--gx", `${(x / window.innerWidth) * 100}%`);
  el.style.setProperty("--gy", `${(y / window.innerHeight) * 100}%`);
  el.classList.add("on");
  window.setTimeout(() => el.classList.remove("on"), 750);
}

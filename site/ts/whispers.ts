/**
 * whispers.ts — ambient whisper spawner (bounded pool, fades in/out)
 * and the featured-quote cycler on the index.
 */

import { pick, reducedMotion, whispers } from "./env.js";
import { fxRing } from "./fx.js";

export function initWhispers(): void {
  if (reducedMotion()) return;
  const pool = whispers();
  if (pool.length === 0) return;

  const MAX = 3;
  let active = 0;

  const spawn = (): void => {
    if (document.hidden || active >= MAX) return;
    const w = pick(pool);
    const el = document.createElement("div");
    el.className = "whisper-bit";
    el.setAttribute("aria-hidden", "true");
    el.textContent = `\u201C${w.q}\u201D`;
    el.style.left = `${8 + Math.random() * 62}%`;
    el.style.top = `${15 + Math.random() * 60}%`;
    document.body.appendChild(el);
    active++;
    requestAnimationFrame(() => {
      el.classList.add("show");
      const r = el.getBoundingClientRect();
      fxRing(r.left + r.width / 2, r.top + r.height / 2); // a halo answers the whisper
    });
    window.setTimeout(() => {
      el.classList.remove("show");
      window.setTimeout(() => {
        el.remove();
        active--;
      }, 2600);
    }, 5000 + Math.random() * 4000);
  };

  window.setInterval(spawn, 9000 + Math.random() * 6000);
  window.setTimeout(spawn, 2500);
}

/* ------------------------------------------------------------------ */
/* Featured quote cycler (index).                                     */
/* ------------------------------------------------------------------ */

export function initFeatured(): void {
  const q = document.getElementById("featured-quote");
  const s = document.getElementById("featured-speaker");
  if (!q || !s || reducedMotion()) return;
  const pool = whispers();
  if (pool.length < 2) return;
  window.setInterval(() => {
    const w = pick(pool);
    const p = q.querySelector("p");
    if (p) p.textContent = `\u201C${w.q}\u201D`;
    s.textContent = w.s;
  }, 14000);
}

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
  const p = q?.querySelector("p");
  const cap = s?.parentElement;
  if (!q || !p || !s || !cap || reducedMotion()) return;
  const pool = whispers();
  if (pool.length < 2) return;

  const TYPE_MS = 38;   /* the voice arrives */
  const ERASE_MS = 16;  /* the voice withdraws */
  const HOLD_MS = 3400; /* how long a truth is allowed to stand */

  let i = Math.max(0, pool.findIndex((w) => (p.textContent ?? "").includes(w.q)));

  const erase = (text: string, done: () => void): void => {
    let n = text.length;
    const t = window.setInterval(() => {
      p.textContent = text.slice(0, --n);
      if (n <= 0) { window.clearInterval(t); done(); }
    }, ERASE_MS);
  };

  const type = (w: { q: string; s: string }, done: () => void): void => {
    const text = `\u201C${w.q}\u201D`;
    let n = 0;
    const t = window.setInterval(() => {
      p.textContent = text.slice(0, ++n);
      if (n >= text.length) {
        window.clearInterval(t);
        s.textContent = w.s;
        cap.style.opacity = "1";
        done();
      }
    }, TYPE_MS);
  };

  const cycle = (): void => {
    i = (i + 1) % pool.length;
    const w = pool[i];
    const text = `\u201C${w.q}\u201D`;
    type(w, () =>
      window.setTimeout(() => {
        cap.style.opacity = "0";
        erase(text, () => window.setTimeout(cycle, 700));
      }, HOLD_MS),
    );
  };

  /* The rendered quote stands for a beat, then withdraws into the chorus. */
  window.setTimeout(() => {
    cap.style.opacity = "0";
    erase(p.textContent ?? "", cycle);
  }, HOLD_MS);
}

/**
 * sigils.ts — the Wall of Wishes, drawn live.
 * A 4x4 grid of procedurally generated wish plates on <canvas.wish-wall>;
 * every few seconds a plate flares, and clicking one detonates a burst.
 * Each sigil is seeded per cell — the wall never rearranges its syntax.
 */

import { pick, reducedMotion } from "./env.js";
import { fxBurst, fxRing } from "./fx.js";

/* Deterministic per-cell RNG so the wall is stable between frames. */
function seeded(seed: number): () => number {
  let s = seed >>> 0 || 1;
  return () => {
    s ^= s << 13; s ^= s >>> 17; s ^= s << 5;
    return (s >>> 0) / 4294967296;
  };
}

type Prim = (ctx: CanvasRenderingContext2D, u: number, rnd: () => number) => void;

const PRIMS: Prim[] = [
  (c, u) => { c.beginPath(); c.arc(0, 0, 8 * u, 0, Math.PI * 2); c.stroke(); },           // ring
  (c, u) => { c.beginPath(); c.arc(0, 0, 2.4 * u, 0, Math.PI * 2); c.fill(); },           // ember dot
  (c, u, r) => { c.beginPath(); c.moveTo(-9 * u, 9 * u); c.lineTo(0, -9 * u); c.lineTo(9 * u, 9 * u); c.stroke(); }, // chevron
  (c, u, r) => { const a = r() * Math.PI; c.beginPath(); c.arc(0, 0, 9 * u, a, a + Math.PI); c.stroke(); }, // arc
  (c, u, r) => { c.beginPath(); c.moveTo(-9 * u, 0); c.lineTo(9 * u, 0); c.moveTo(0, -9 * u); c.lineTo(0, 9 * u); c.stroke(); }, // cross
  (c, u, r) => { c.beginPath(); c.moveTo(-8 * u, -4 * u); c.quadraticCurveTo(0, 6 * u, 8 * u, -4 * u); c.moveTo(0, -8 * u); c.lineTo(0, 4 * u); c.stroke(); }, // talon
  (c, u, r) => { c.beginPath(); c.moveTo(-9 * u, 0); c.quadraticCurveTo(0, -11 * u, 9 * u, 0); c.quadraticCurveTo(0, 11 * u, -9 * u, 0); c.stroke(); }, // eye
  (c, u, r) => { for (let i = 0; i < 3; i++) { c.beginPath(); c.arc((i - 1) * 7 * u, 0, 2 * u, 0, Math.PI * 2); c.stroke(); } }, // triad
];

/* Read the live accent palette (it hue-drifts) via a probe element. */
function accentProbe(): () => string[] {
  let accents = ["rgb(143,227,208)", "rgb(199,125,255)"];
  const probe = document.createElement("span");
  probe.style.cssText = "position:absolute;visibility:hidden;pointer-events:none";
  document.body.appendChild(probe);
  const sample = (): void => {
    const a: string[] = [];
    for (const v of ["--accent", "--accent-2"]) {
      probe.style.color = `var(${v})`;
      const c = getComputedStyle(probe).color;
      if (c) a.push(c);
    }
    if (a.length === 2) accents = a;
  };
  sample();
  window.setInterval(sample, 2500);
  return () => accents;
}

export function initSigils(): void {
  const canvas = document.querySelector<HTMLCanvasElement>("canvas.wish-wall");
  const ctx = canvas?.getContext("2d");
  if (!canvas || !ctx) return;

  const CELLS = 16;
  const flare: number[] = new Array(CELLS).fill(0);
  const still = reducedMotion();
  const accents = accentProbe();

  const fit = (): void => {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const r = canvas.getBoundingClientRect();
    canvas.width = Math.max(1, r.width * dpr);
    canvas.height = Math.max(1, r.height * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  };
  fit();
  window.addEventListener("resize", fit);

  const drawPlate = (i: number, cw: number, ch: number, t: number): void => {
    const col = i % 4, row = Math.floor(i / 4);
    const cx = col * cw + cw / 2, cy = row * ch + ch / 2;
    const rnd = seeded(0x9e3779 + i * 7919);
    const u = Math.min(cw, ch) / 34;
    const f = Math.max(0, flare[i] - t);
    const ac = accents();

    ctx.save();
    ctx.translate(cx, cy);

    /* Plate border — faint until it flares. */
    ctx.globalAlpha = 0.16 + f * 0.7;
    ctx.strokeStyle = ac[0];
    ctx.lineWidth = u * (0.9 + f * 0.6);
    ctx.strokeRect(-cw / 2 + 2 * u, -ch / 2 + 2 * u, cw - 4 * u, ch - 4 * u);

    /* The sigil — three seeded primitives layered. */
    ctx.globalAlpha = 0.5 + f * 0.5;
    ctx.strokeStyle = f > 0.35 ? ac[1] : ac[0];
    ctx.fillStyle = ac[1];
    ctx.lineWidth = u * (1 + f);
    for (let k = 0; k < 3; k++) {
      ctx.save();
      ctx.rotate(rnd() * Math.PI * 2);
      ctx.scale(0.5 + rnd() * 0.5, 0.5 + rnd() * 0.5);
      pick(PRIMS)(ctx, u, rnd);
      ctx.restore();
    }
    ctx.restore();
  };

  const draw = (t: number): void => {
    const r = canvas.getBoundingClientRect();
    ctx.clearRect(0, 0, r.width, r.height);
    const cw = r.width / 4, ch = r.height / 4;
    for (let i = 0; i < CELLS; i++) drawPlate(i, cw, ch, t);
  };

  canvas.addEventListener("pointerdown", (e) => {
    const r = canvas.getBoundingClientRect();
    const i = Math.floor((e.clientY - r.top) / (r.height / 4)) * 4 +
              Math.floor((e.clientX - r.left) / (r.width / 4));
    if (i >= 0 && i < CELLS) {
      flare[i] = performance.now() / 1000 + 1.6;
      fxBurst(e.clientX, e.clientY, 24);
      fxRing(e.clientX, e.clientY);
    }
  }, { passive: true });

  if (still) { draw(0); return; }

  const stir = (): void => {
    if (!document.hidden) flare[Math.floor(Math.random() * CELLS)] = performance.now() / 1000 + 2.2;
    window.setTimeout(stir, 2600 + Math.random() * 3800);
  };
  stir();

  const loop = (now: number): void => {
    draw(now / 1000);
    window.requestAnimationFrame(loop);
  };
  window.requestAnimationFrame(loop);
}

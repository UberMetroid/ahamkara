/**
 * watcher.ts — the Many-Eyed One, drawn live.
 * Every <canvas class="watcher"> becomes a wish-dragon eye: almond lid,
 * slit pupil, crown ticks, drifting tendrils. The pupil tracks the cursor,
 * blinks on its own schedule, and hue-drifts with the site palette.
 * data-mood="gone" (the 404) draws the eye half-shut and unblinking.
 */

import { reducedMotion } from "./env.js";

/* Resolved CSS accent colors, resampled so the eye hue-drifts with --ahue. */
let probe: HTMLElement | null = null;
let accents: string[] = ["rgb(143,227,208)", "rgb(199,125,255)"];
function sampleAccents(): void {
  if (!probe) {
    probe = document.createElement("span");
    probe.style.position = "absolute";
    probe.style.visibility = "hidden";
    document.body.appendChild(probe);
  }
  const a: string[] = [];
  for (const v of ["--accent", "--accent-2"]) {
    probe.style.color = `var(${v})`;
    const c = getComputedStyle(probe).color;
    if (c) a.push(c);
  }
  if (a.length === 2) accents = a;
}

interface Eye {
  c: HTMLCanvasElement;
  x: number; y: number;      // canvas-space center
  px: number; py: number;    // pupil offset (eased)
  tx: number; ty: number;    // pupil target
  lid: number;               // 0 closed .. 1 open (eased)
  lidTarget: number;
  gone: boolean;
}

export function initWatcher(): void {
  const eyes: Eye[] = [];
  document.querySelectorAll<HTMLCanvasElement>("canvas.watcher").forEach((c) => {
    eyes.push({
      c, x: 0, y: 0, px: 0, py: 0, tx: 0, ty: 0,
      lid: 0, lidTarget: 1,
      gone: c.dataset.mood === "gone",
    });
  });
  if (eyes.length === 0) return;

  const still = reducedMotion();
  sampleAccents();
  window.setInterval(sampleAccents, 400);

  const fit = (): void => {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    for (const e of eyes) {
      const r = e.c.getBoundingClientRect();
      e.c.width = Math.max(1, r.width * dpr);
      e.c.height = Math.max(1, r.height * dpr);
      const ctx = e.c.getContext("2d");
      if (ctx) ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      e.x = r.width / 2;
      e.y = r.height / 2;
    }
  };
  fit();
  window.addEventListener("resize", fit);

  if (!still) {
    document.addEventListener("pointermove", (ev) => {
      for (const e of eyes) {
        if (e.gone) continue;
        const r = e.c.getBoundingClientRect();
        const dx = ev.clientX - (r.left + r.width / 2);
        const dy = ev.clientY - (r.top + r.height / 2);
        const d = Math.hypot(dx, dy) || 1;
        const reach = Math.min(1, d / 420);
        e.tx = (dx / d) * reach * r.width * 0.09;
        e.ty = (dy / d) * reach * r.height * 0.06;
      }
    }, { passive: true });

    /* The blink: irregular, slow, deliberate. */
    const blink = (): void => {
      if (!document.hidden) {
        for (const e of eyes) if (!e.gone) e.lidTarget = 0;
        window.setTimeout(() => {
          for (const e of eyes) if (!e.gone) e.lidTarget = 1;
        }, 130 + Math.random() * 90);
      }
      window.setTimeout(blink, 3200 + Math.random() * 5200);
    };
    window.setTimeout(blink, 2400);
  }

  const drawEye = (e: Eye, t: number): void => {
    const ctx = e.c.getContext("2d");
    if (!ctx) return;
    const r = e.c.getBoundingClientRect();
    const w = r.width, h = r.height;
    ctx.clearRect(0, 0, w, h);
    const u = Math.min(w, h) / 100;             // unit scale
    const breathe = still ? 1 : 1 + Math.sin(t / 900) * 0.015;
    const open = e.gone ? 0.42 : e.lid;          // the gone eye never fully opens

    ctx.save();
    ctx.translate(e.x, e.y);
    ctx.scale(breathe, breathe * Math.max(0.12, open));
    ctx.strokeStyle = accents[0];
    ctx.lineWidth = 1.4 * u;
    ctx.globalAlpha = e.gone ? 0.45 : 0.85;

    /* Almond lid: two quadratic curves meeting at the corners. */
    const ew = 34 * u, eh = 15 * u;
    ctx.beginPath();
    ctx.moveTo(-ew, 0);
    ctx.quadraticCurveTo(0, -eh * 2, ew, 0);
    ctx.quadraticCurveTo(0, eh * 2, -ew, 0);
    ctx.stroke();

    /* Iris ring + slit pupil, offset toward the bearer's cursor. */
    ctx.globalAlpha = e.gone ? 0.3 : 0.8;
    ctx.strokeStyle = accents[1];
    ctx.beginPath();
    ctx.arc(e.px, e.py, 11 * u, 0, Math.PI * 2);
    ctx.stroke();
    ctx.globalAlpha = e.gone ? 0.5 : 0.95;
    ctx.fillStyle = accents[1];
    ctx.beginPath();
    ctx.ellipse(e.px, e.py, 2.6 * u, 9.5 * u, 0, 0, Math.PI * 2);
    ctx.fill();

    /* Crown ticks — four horns. */
    ctx.globalAlpha = e.gone ? 0.35 : 0.6;
    ctx.strokeStyle = accents[0];
    ctx.lineWidth = 1.1 * u;
    for (let i = -2; i <= 2; i++) {
      if (i === 0) continue;
      const a = -Math.PI / 2 + i * 0.42;
      const r1 = eh * 1.7, r2 = eh * 2.4 + Math.abs(i) * 1.5 * u;
      ctx.beginPath();
      ctx.moveTo(Math.cos(a) * ew * 0.55, Math.sin(a) * r1);
      ctx.lineTo(Math.cos(a) * ew * 0.8, Math.sin(a) * r2);
      ctx.stroke();
    }

    /* Tendrils — three slow sine strokes drifting below. */
    ctx.globalAlpha = e.gone ? 0.25 : 0.4;
    for (let i = -1; i <= 1; i++) {
      const sway = still ? 0 : Math.sin(t / 1400 + i * 1.7) * 6 * u;
      ctx.beginPath();
      ctx.moveTo(i * 12 * u, eh * 1.5);
      ctx.quadraticCurveTo(i * 16 * u + sway, eh * 2.6, i * 9 * u + sway, eh * 3.6);
      ctx.stroke();
    }
    ctx.restore();
  };

  if (still) {
    for (const e of eyes) { e.lid = 1; drawEye(e, 0); }
    return;
  }

  const loop = (t: number): void => {
    for (const e of eyes) {
      e.px += (e.tx - e.px) * 0.07;
      e.py += (e.ty - e.py) * 0.07;
      e.lid += (e.lidTarget - e.lid) * 0.35;
      drawEye(e, t);
    }
    window.requestAnimationFrame(loop);
  };
  window.requestAnimationFrame(loop);
}

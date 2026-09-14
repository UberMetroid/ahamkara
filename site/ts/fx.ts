/**
 * fx.ts — wish magic: pixel bursts, halo rings, cursor embers, the trip,
 * and the grant flash. All motion is gated behind prefers-reduced-motion.
 */

import { pick, reducedMotion } from "./env.js";

const PALETTE: [number, number, number][] = [
  [143, 227, 208], // taken-teal
  [199, 125, 255], // riven-violet
  [236, 229, 211], // bone
  [255, 110, 160], // wish-pink
];

interface Particle {
  x: number; y: number; vx: number; vy: number;
  life: number; max: number; size: number; c: [number, number, number];
}
interface Ring {
  x: number; y: number; r: number; life: number; max: number;
}

/* Shared hooks other modules call; no-ops until initFx wires them. */
export let fxBurst: (x: number, y: number, n?: number) => void = () => {};
export let fxRing: (x: number, y: number) => void = () => {};

export function initFx(): void {
  if (reducedMotion()) return;
  const canvas = document.getElementById("fx") as HTMLCanvasElement | null;
  const ctx = canvas?.getContext("2d");
  if (!canvas || !ctx) return;

  const particles: Particle[] = [];
  const rings: Ring[] = [];
  const MAXP = 384;
  const MAXR = 10;

  const resize = (): void => {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = window.innerWidth * dpr;
    canvas.height = window.innerHeight * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  };
  resize();
  window.addEventListener("resize", resize);

  const burst = (x: number, y: number, n = 30): void => {
    for (let i = 0; i < n; i++) {
      if (particles.length >= MAXP) particles.shift();
      const a = Math.random() * Math.PI * 2;
      const sp = 0.6 + Math.random() * 3.6;
      particles.push({
        x, y,
        vx: Math.cos(a) * sp,
        vy: Math.sin(a) * sp - 1.3, // reality drifts upward
        life: 0,
        max: 55 + Math.random() * 65,
        size: 1.5 + Math.random() * 4.5,
        c: pick(PALETTE),
      });
    }
  };
  const ring = (x: number, y: number): void => {
    if (rings.length >= MAXR) rings.shift();
    rings.push({ x, y, r: 5, life: 0, max: 50 + Math.random() * 24 });
  };
  fxBurst = burst;
  fxRing = ring;

  /* The bargain responds to touch. */
  document.addEventListener(
    "pointerdown",
    (e) => {
      burst(e.clientX, e.clientY);
      ring(e.clientX, e.clientY);
    },
    { passive: true }
  );

  /* Cursor embers — the dragon's attention follows you. */
  let lastTrail = 0;
  document.addEventListener(
    "pointermove",
    (e) => {
      const t = performance.now();
      if (t - lastTrail < 55 || particles.length >= MAXP) return;
      lastTrail = t;
      particles.push({
        x: e.clientX, y: e.clientY,
        vx: (Math.random() - 0.5) * 0.4,
        vy: -0.3 - Math.random() * 0.4,
        life: 0, max: 34 + Math.random() * 20,
        size: 1.2 + Math.random() * 1.8,
        c: pick(PALETTE),
      });
    },
    { passive: true }
  );

  /* Spontaneous detonations — reality itches. */
  const spontaneous = (): void => {
    if (!document.hidden) {
      const x = window.innerWidth * (0.12 + Math.random() * 0.76);
      const y = window.innerHeight * (0.15 + Math.random() * 0.7);
      burst(x, y, 18 + Math.floor(Math.random() * 14));
      ring(x, y);
    }
    window.setTimeout(spontaneous, 9000 + Math.random() * 10000);
  };
  window.setTimeout(spontaneous, 6000);

  /* Render loop — parks itself while the tab is hidden. */
  let running = true;
  const frame = (): void => {
    if (!running) return;
    ctx.clearRect(0, 0, window.innerWidth, window.innerHeight);
    for (let i = particles.length - 1; i >= 0; i--) {
      const p = particles[i];
      p.life++;
      p.x += p.vx;
      p.y += p.vy;
      p.vx *= 0.985;
      p.vy = p.vy * 0.985 - 0.012; // anti-gravity: wishes rise
      const t = 1 - p.life / p.max;
      if (t <= 0) {
        particles.splice(i, 1);
        continue;
      }
      ctx.globalAlpha = Math.min(1, t * 1.5);
      ctx.fillStyle = `rgb(${p.c[0]},${p.c[1]},${p.c[2]})`;
      ctx.fillRect(p.x - p.size / 2, p.y - p.size / 2, p.size, p.size);
    }
    for (let i = rings.length - 1; i >= 0; i--) {
      const r = rings[i];
      r.life++;
      r.r += 2.6 + r.life * 0.05;
      const t = 1 - r.life / r.max;
      if (t <= 0) {
        rings.splice(i, 1);
        continue;
      }
      ctx.globalAlpha = t * 0.65;
      ctx.lineWidth = 2;
      ctx.strokeStyle = "rgb(143,227,208)";
      ctx.beginPath();
      ctx.arc(r.x, r.y, r.r, 0, Math.PI * 2);
      ctx.stroke();
      ctx.globalAlpha = t * 0.5;
      ctx.lineWidth = 1;
      ctx.strokeStyle = "rgb(199,125,255)";
      ctx.beginPath();
      ctx.arc(r.x, r.y, r.r * 0.8, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
    window.requestAnimationFrame(frame);
  };
  window.requestAnimationFrame(frame);
  document.addEventListener("visibilitychange", () => {
    running = !document.hidden;
    if (running) window.requestAnimationFrame(frame);
  });
}

/* ================================================================== */
/*  THE TRIP — periodic chromatic aberration pulses on headings         */
/* ================================================================== */

export function initTrip(): void {
  if (reducedMotion()) return;
  const pulse = (): void => {
    if (!document.hidden) {
      document.body.classList.add("tripping");
      window.setTimeout(
        () => document.body.classList.remove("tripping"),
        2600 + Math.random() * 2400
      );
    }
    window.setTimeout(pulse, 22000 + Math.random() * 28000);
  };
  window.setTimeout(pulse, 12000);
}

/* ================================================================== */
/*  GRANT FLASH — radial burst when a wish is granted                  */
/* ================================================================== */

export function grantFlash(x: number, y: number): void {
  if (reducedMotion()) return;
  const el = document.getElementById("grant-flash");
  if (!el) return;
  el.style.setProperty("--gx", `${(x / window.innerWidth) * 100}%`);
  el.style.setProperty("--gy", `${(y / window.innerHeight) * 100}%`);
  el.classList.add("on");
  window.setTimeout(() => el.classList.remove("on"), 750);
}

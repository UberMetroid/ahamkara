/**
 * smoke_engine.ts — mathematical model and rendering engine for dream smoke.
 * Multi-frequency Lissajous harmonic drift with non-linear radial gradient puffs.
 */

export interface WispPuff {
  baseX: number;
  baseY: number;
  radiusBase: number;
  vx: number;
  vy: number;
  ampX: number;
  ampY: number;
  freqX: number;
  freqY: number;
  phaseX: number;
  phaseY: number;
  ampR: number;
  freqR: number;
  phaseR: number;
  r: number;
  g: number;
  b: number;
  alpha: number;
}

interface PaletteColor {
  r: number;
  g: number;
  b: number;
  minA: number;
  maxA: number;
}

const PALETTE: PaletteColor[] = [
  { r: 199, g: 125, b: 255, minA: 0.045, maxA: 0.085 }, // #c77dff amethyst
  { r: 157, g: 78, b: 221, minA: 0.050, maxA: 0.090 },  // #9d4edd deep amethyst
  { r: 143, g: 227, b: 208, minA: 0.035, maxA: 0.070 }, // #8fe3d0 taken-mist
  { r: 236, g: 229, b: 211, minA: 0.015, maxA: 0.030 }, // #ece5d3 bone
];

function rand(min: number, max: number): number {
  return min + Math.random() * (max - min);
}

export function createPuffs(count: number): WispPuff[] {
  const puffs: WispPuff[] = [];
  for (let i = 0; i < count; i++) {
    const roll = Math.random();
    const c = roll < 0.38 ? PALETTE[0] : roll < 0.68 ? PALETTE[1] : roll < 0.90 ? PALETTE[2] : PALETTE[3];
    puffs.push({
      baseX: Math.random(),
      baseY: Math.random(),
      radiusBase: rand(160, 290),
      vx: rand(-0.005, 0.005),
      vy: rand(0.009, 0.022),
      ampX: rand(0.04, 0.12),
      ampY: rand(0.03, 0.09),
      freqX: rand(0.14, 0.38),
      freqY: rand(0.18, 0.44),
      phaseX: Math.random() * Math.PI * 2,
      phaseY: Math.random() * Math.PI * 2,
      ampR: rand(0.08, 0.18),
      freqR: rand(0.20, 0.50),
      phaseR: Math.random() * Math.PI * 2,
      r: c.r,
      g: c.g,
      b: c.b,
      alpha: rand(c.minA, c.maxA),
    });
  }
  return puffs;
}

export function updateAndRenderPuffs(
  ctx: CanvasRenderingContext2D,
  puffs: WispPuff[],
  width: number,
  height: number,
  timeSec: number,
  dt: number
): void {
  ctx.fillStyle = "#07060b";
  ctx.fillRect(0, 0, width, height);

  ctx.globalCompositeOperation = "screen";
  const scaleRef = Math.min(width, height) / 800;
  const edgeDistX = width * 0.15;
  const edgeDistY = height * 0.15;

  for (let i = 0; i < puffs.length; i++) {
    const p = puffs[i];
    p.baseY -= p.vy * dt;
    p.baseX += p.vx * dt;

    if (p.baseY < -0.25) p.baseY += 1.5;
    else if (p.baseY > 1.25) p.baseY -= 1.5;
    if (p.baseX < -0.25) p.baseX += 1.5;
    else if (p.baseX > 1.25) p.baseX -= 1.5;

    const ox = p.ampX * Math.sin(p.freqX * timeSec + p.phaseX);
    const oy = p.ampY * Math.cos(p.freqY * timeSec + p.phaseY);
    const px = (p.baseX + ox) * width;
    const py = (p.baseY + oy) * height;

    const pulse = 1 + p.ampR * Math.sin(p.freqR * timeSec + p.phaseR);
    const rad = Math.max(50, p.radiusBase * Math.max(0.65, scaleRef) * pulse);

    const fadeX = Math.min(1, Math.max(0, px / edgeDistX), Math.max(0, (width - px) / edgeDistX));
    const fadeY = Math.min(1, Math.max(0, py / edgeDistY), Math.max(0, (height - py) / edgeDistY));
    const edgeFade = fadeX * fadeY;
    if (edgeFade <= 0.002) continue;

    const a = p.alpha * edgeFade;
    const grad = ctx.createRadialGradient(px, py, 0, px, py, rad);
    grad.addColorStop(0, `rgba(${p.r},${p.g},${p.b},${a.toFixed(4)})`);
    grad.addColorStop(0.45, `rgba(${p.r},${p.g},${p.b},${(a * 0.55).toFixed(4)})`);
    grad.addColorStop(0.75, `rgba(${p.r},${p.g},${p.b},${(a * 0.18).toFixed(4)})`);
    grad.addColorStop(1, `rgba(${p.r},${p.g},${p.b},0)`);

    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.arc(px, py, rad, 0, Math.PI * 2);
    ctx.fill();
  }

  ctx.globalCompositeOperation = "source-over";
}

export function renderStaticSmoke(ctx: CanvasRenderingContext2D, width: number, height: number): void {
  ctx.fillStyle = "#07060b";
  ctx.fillRect(0, 0, width, height);
  ctx.globalCompositeOperation = "screen";

  const diag = Math.max(width, height);

  const g1 = ctx.createRadialGradient(width * 0.48, height * 0.42, 0, width * 0.48, height * 0.42, diag * 0.48);
  g1.addColorStop(0, "rgba(199,125,255,0.085)");
  g1.addColorStop(0.5, "rgba(157,78,221,0.035)");
  g1.addColorStop(1, "rgba(7,6,11,0)");
  ctx.fillStyle = g1;
  ctx.fillRect(0, 0, width, height);

  const g2 = ctx.createRadialGradient(width * 0.68, height * 0.60, 0, width * 0.68, height * 0.60, diag * 0.42);
  g2.addColorStop(0, "rgba(143,227,208,0.065)");
  g2.addColorStop(0.6, "rgba(143,227,208,0.020)");
  g2.addColorStop(1, "rgba(7,6,11,0)");
  ctx.fillStyle = g2;
  ctx.fillRect(0, 0, width, height);

  const g3 = ctx.createRadialGradient(width * 0.32, height * 0.55, 0, width * 0.32, height * 0.55, diag * 0.35);
  g3.addColorStop(0, "rgba(236,229,211,0.025)");
  g3.addColorStop(0.6, "rgba(236,229,211,0.006)");
  g3.addColorStop(1, "rgba(7,6,11,0)");
  ctx.fillStyle = g3;
  ctx.fillRect(0, 0, width, height);

  ctx.globalCompositeOperation = "source-over";
}

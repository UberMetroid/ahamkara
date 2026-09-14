/**
 * wyrm_render.ts — True 2D Pixel-Art Renderer for the Ahamkara Wish Dragon.
 * Uses discrete pixel matrices, integer block scaling, and zero vector rotation.
 */

import {
  PALETTE,
  SPRITE_BODY_SEGMENT,
  SPRITE_HEAD_FEED,
  SPRITE_HEAD_RIGHT,
  SPRITE_TAIL_FLAME,
  SPRITE_TAIL_SEGMENT,
  SPRITE_WING_DOWN,
  SPRITE_WING_MID,
  SPRITE_WING_UP,
} from "./wyrm_sprites.js";
import { HaloRing, Particle, Segment, WhisperFloat, WyrmDirection } from "./wyrm_types.js";

/**
 * Draws a discrete 2D pixel matrix with crisp integer scaling.
 */
export function drawPixelMatrix(
  ctx: CanvasRenderingContext2D,
  matrix: string[],
  x: number,
  y: number,
  scale = 3,
  flipX = false
): void {
  const height = matrix.length;
  if (height === 0) return;
  const width = matrix[0].length;

  for (let r = 0; r < height; r++) {
    const rowStr = matrix[r];
    for (let c = 0; c < width; c++) {
      const char = rowStr[c];
      if (char === " " || !char) continue;
      const col = flipX ? width - 1 - c : c;
      const px = Math.round(x + col * scale);
      const py = Math.round(y + r * scale);
      ctx.fillStyle = PALETTE[char] || "#ece5d3";
      ctx.fillRect(px, py, scale, scale);
    }
  }
}

/**
 * Renders the 2D pixel art Ahamkara dragon entity.
 */
export function renderWyrm(
  ctx: CanvasRenderingContext2D,
  segments: Segment[],
  state: string,
  direction: WyrmDirection,
  animTime: number,
  scale = 3,
  gazeAngle = 0
): void {
  if (segments.length === 0 || state === "unsummoned") return;

  const flip = direction === "left";
  const total = segments.length;

  // 1. Draw Tail Tip Flame (Frame animated 0-2)
  if (total > 2) {
    const tail = segments[total - 1];
    const flameFrame = Math.floor((animTime * 6) % 3);
    const flameSprite = SPRITE_TAIL_FLAME[flameFrame];
    const fx = tail.x - 4 * scale;
    const fy = tail.y - 5 * scale;
    drawPixelMatrix(ctx, flameSprite, fx, fy, scale, flip);
  }

  // 2. Draw Trailing Sinuous Body Segments (tail to neck)
  for (let i = total - 2; i >= 1; i--) {
    const seg = segments[i];
    if (i >= total - 3) {
      const sx = seg.x - 3 * scale;
      const sy = seg.y - 3 * scale;
      drawPixelMatrix(ctx, SPRITE_TAIL_SEGMENT, sx, sy, scale, flip);
    } else {
      const sx = seg.x - 4 * scale;
      const sy = seg.y - 4 * scale;
      drawPixelMatrix(ctx, SPRITE_BODY_SEGMENT, sx, sy, scale, flip);
    }
  }

  // 3. Draw Flapping Wings (attached near shoulders behind head)
  const head = segments[0];
  const wingCycle = Math.floor((animTime * 8) % 4);
  const wingMatrix =
    wingCycle === 0
      ? SPRITE_WING_UP
      : wingCycle === 2
      ? SPRITE_WING_DOWN
      : SPRITE_WING_MID;

  const wingX = flip ? head.x - 4 * scale : head.x - 12 * scale;
  const wingY = head.y - 10 * scale;
  drawPixelMatrix(ctx, wingMatrix, wingX, wingY, scale, flip);

  // 4. Draw Ahamkara Head (Facing left or right, normal or feeding)
  const isFeeding = state === "feeding";
  const headMatrix = isFeeding ? SPRITE_HEAD_FEED : SPRITE_HEAD_RIGHT;
  const hx = flip ? head.x - 18 * scale : head.x - 4 * scale;
  const hy = head.y - 7 * scale;
  drawPixelMatrix(ctx, headMatrix, hx, hy, scale, flip);

  // 5. Ocular Gaze Tracking
  if (Math.abs(gazeAngle) > 0.04) {
    const gazeDx = Math.round(Math.cos(gazeAngle) * scale);
    const gazeDy = Math.round(Math.sin(gazeAngle) * scale);
    const glintX = flip ? hx + 10 * scale + gazeDx : hx + 11 * scale + gazeDx;
    const glintY = hy + 5 * scale + gazeDy;
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(glintX, glintY, scale, scale);
  }
}

/**
 * Renders ocular flare particles and wish dust motes.
 */
export function renderParticles(ctx: CanvasRenderingContext2D, particles: Particle[]): void {
  for (const p of particles) {
    const alpha = Math.max(0, p.life / p.maxLife);
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.fillStyle = p.color;
    ctx.fillRect(Math.round(p.x), Math.round(p.y), p.size, p.size);
    ctx.restore();
  }
}

/**
 * Renders expanding taken halo rings.
 */
export function renderHaloRings(ctx: CanvasRenderingContext2D, rings: HaloRing[]): void {
  for (const r of rings) {
    const progress = 1 - r.life / r.maxLife;
    const currentRadius = r.radius + (r.maxRadius - r.radius) * progress;
    ctx.save();
    ctx.globalAlpha = Math.max(0, r.life / r.maxLife);
    ctx.strokeStyle = r.color;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(Math.round(r.x), Math.round(r.y), Math.round(currentRadius), 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }
}

/**
 * Renders floating whisper speech balloons / phrases.
 */
export function renderWhispers(ctx: CanvasRenderingContext2D, whispers: WhisperFloat[]): void {
  for (const w of whispers) {
    const alpha = Math.max(0, Math.min(1, w.life / (w.maxLife * 0.35)));
    ctx.save();
    ctx.globalAlpha = alpha;

    ctx.font = "italic 600 13px Georgia, serif";
    const tw = ctx.measureText(w.text).width;
    const pad = 8;
    const bx = Math.round(w.x - tw / 2 - pad);
    const by = Math.round(w.y - 20);
    const bw = Math.round(tw + pad * 2);
    const bh = 24;

    ctx.fillStyle = "#0b0a10";
    ctx.fillRect(bx, by, bw, bh);
    ctx.strokeStyle = "#8fe3d0";
    ctx.lineWidth = 1.5;
    ctx.strokeRect(bx, by, bw, bh);

    ctx.fillStyle = "#ece5d3";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(w.text, Math.round(w.x), by + bh / 2);
    ctx.restore();
  }
}

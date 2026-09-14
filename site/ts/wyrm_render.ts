/**
 * wyrm_render.ts — Low-res integer pixel-art renderer for the Ahamkara Wyrm.
 */

import {
  BONE,
  BONE_DARK,
  HaloRing,
  Particle,
  RIVEN_VIOLET,
  Segment,
  TAKEN_TEAL,
  VOID_BLACK,
  WhisperFloat,
  WISH_PINK,
} from "./wyrm_types.js";

/**
 * Draws crisp integer pixel rects in local coordinate space.
 */
function px(ctx: CanvasRenderingContext2D, x: number, y: number, w = 1, h = 1): void {
  ctx.fillRect(Math.round(x), Math.round(y), w, h);
}

/**
 * Renders the Ahamkara dragon skull with branching antler horns and glowing eyes.
 */
function renderSkull(
  ctx: CanvasRenderingContext2D,
  head: Segment,
  flareTimer: number,
  gazeAngle: number
): void {
  ctx.save();
  ctx.translate(Math.round(head.x), Math.round(head.y));
  ctx.rotate(head.angle);

  const S = 2; // Pixel grid unit

  // 1. Antler horns (branching backward from crown)
  ctx.fillStyle = flareTimer > 0 ? WISH_PINK : BONE;
  // Left antler main beam
  px(ctx, -2 * S, -3 * S, S, S);
  px(ctx, -4 * S, -5 * S, S, S);
  px(ctx, -6 * S, -7 * S, S, S);
  px(ctx, -8 * S, -9 * S, S, S);
  px(ctx, -10 * S, -10 * S, S, S);
  // Left antler tine (outward branch)
  px(ctx, -4 * S, -7 * S, S, S);
  px(ctx, -5 * S, -9 * S, S, S);

  // Right antler main beam
  px(ctx, -2 * S, 3 * S, S, S);
  px(ctx, -4 * S, 5 * S, S, S);
  px(ctx, -6 * S, 7 * S, S, S);
  px(ctx, -8 * S, 9 * S, S, S);
  px(ctx, -10 * S, 10 * S, S, S);
  // Right antler tine
  px(ctx, -4 * S, 7 * S, S, S);
  px(ctx, -5 * S, 9 * S, S, S);

  // Shaded antler bases
  ctx.fillStyle = BONE_DARK;
  px(ctx, -3 * S, -4 * S, S, S);
  px(ctx, -3 * S, 4 * S, S, S);

  // 2. Cranium / Head Plate (predatory bone structure)
  ctx.fillStyle = BONE;
  px(ctx, -1 * S, -3 * S, 4 * S, 6 * S);
  px(ctx, 3 * S, -2 * S, 5 * S, 4 * S);
  // Snout & upper jaw tapering forward
  px(ctx, 8 * S, -1 * S, 3 * S, 2 * S);
  px(ctx, 11 * S, 0, S, S);

  // Bone shadows / contours
  ctx.fillStyle = BONE_DARK;
  px(ctx, 0, -3 * S, S, 6 * S);
  px(ctx, 2 * S, -2 * S, S, 4 * S);

  // 3. Ocular orbits (eye sockets)
  ctx.fillStyle = VOID_BLACK;
  px(ctx, 3 * S, -3 * S, 2 * S, 2 * S);
  px(ctx, 3 * S, 1 * S, 2 * S, 2 * S);

  // 4. Glowing pupils with directional gaze
  const gazeX = Math.round(Math.cos(gazeAngle) * 0.7);
  const gazeY = Math.round(Math.sin(gazeAngle) * 0.7);
  const eyeColor = flareTimer > 0 ? WISH_PINK : gazeAngle !== 0 ? TAKEN_TEAL : RIVEN_VIOLET;

  ctx.fillStyle = eyeColor;
  px(ctx, (3 + gazeX) * S, (-3 + gazeY) * S, S, S);
  px(ctx, (3 + gazeX) * S, (1 + gazeY) * S, S, S);

  // Eye ethereal flare/glint
  ctx.fillStyle = flareTimer > 0 ? "#ffffff" : TAKEN_TEAL;
  px(ctx, (3 + gazeX) * S, (-2 + gazeY) * S, 1, 1);
  px(ctx, (3 + gazeX) * S, (2 + gazeY) * S, 1, 1);

  ctx.restore();
}

/**
 * Renders the sinuous trailing spine vertebrae and ribs.
 */
function renderSpine(
  ctx: CanvasRenderingContext2D,
  segments: Segment[],
  flareTimer: number
): void {
  const total = segments.length;
  // Render from tail to neck so head and front overlap rear
  for (let i = total - 1; i >= 1; i--) {
    const seg = segments[i];
    ctx.save();
    ctx.translate(Math.round(seg.x), Math.round(seg.y));
    ctx.rotate(seg.angle);

    // Tapering profile: neck narrow, mid-body wider, tail slender
    const t = i / total;
    const ribSpan = Math.max(1, Math.round(Math.sin(t * Math.PI) * 7));
    const isOdd = i % 2 === 1;

    // Chromatic flare ripple traveling down the spine
    let ribColor = isOdd ? TAKEN_TEAL : RIVEN_VIOLET;
    if (flareTimer > 0) {
      const ripple = Math.sin(flareTimer * 0.2 - i * 0.4);
      if (ripple > 0.3) ribColor = WISH_PINK;
      else if (ripple > -0.2) ribColor = TAKEN_TEAL;
    }

    // Rib tines (transverse wings)
    ctx.fillStyle = ribColor;
    px(ctx, 0, -ribSpan * 2, 2, ribSpan * 2);
    px(ctx, 0, 1, 2, ribSpan * 2);

    // Central vertebra body
    ctx.fillStyle = flareTimer > 0 ? WISH_PINK : BONE;
    const vSize = t > 0.8 ? 2 : 3;
    px(ctx, -1, -Math.floor(vSize / 2), vSize, vSize);

    ctx.restore();
  }
}

/**
 * Renders the full wyrm entity onto the pixel canvas.
 */
export function renderWyrm(
  ctx: CanvasRenderingContext2D,
  segments: Segment[],
  flareTimer: number,
  gazeAngle: number
): void {
  if (segments.length === 0) return;
  renderSpine(ctx, segments, flareTimer);
  renderSkull(ctx, segments[0], flareTimer, gazeAngle);
}

/**
 * Renders ocular flare particles and burst embers.
 */
export function renderParticles(ctx: CanvasRenderingContext2D, particles: Particle[]): void {
  for (const p of particles) {
    const alpha = Math.max(0, p.life / p.maxLife);
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.fillStyle = p.color;
    px(ctx, p.x, p.y, p.size, p.size);
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
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.arc(Math.round(r.x), Math.round(r.y), Math.round(currentRadius), 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }
}

/**
 * Renders ephemeral floating whisper phrases dissolving into the void.
 */
export function renderWhispers(ctx: CanvasRenderingContext2D, whispers: WhisperFloat[]): void {
  for (const w of whispers) {
    const alpha = Math.max(0, Math.min(1, w.life / (w.maxLife * 0.4)));
    ctx.save();
    ctx.globalAlpha = alpha * 0.85;
    ctx.font = "italic 13px Georgia, 'Cinzel Decorative', serif";
    ctx.fillStyle = TAKEN_TEAL;
    ctx.shadowColor = RIVEN_VIOLET;
    ctx.shadowBlur = 8;
    ctx.textAlign = "center";
    ctx.fillText(w.text, Math.round(w.x), Math.round(w.y));
    ctx.restore();
  }
}

/**
 * wyrm_math.ts — Sinuous inverse kinematics, gaze math, and collision detection.
 */

import { Point, Segment } from "./wyrm_types.js";

export function distance(p1: Point, p2: Point): number {
  return Math.hypot(p2.x - p1.x, p2.y - p1.y);
}

export function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

export function normalizeAngle(rad: number): number {
  let angle = rad;
  while (angle > Math.PI) angle -= 2 * Math.PI;
  while (angle < -Math.PI) angle += 2 * Math.PI;
  return angle;
}

export function angleLerp(a: number, b: number, t: number): number {
  const diff = normalizeAngle(b - a);
  return a + diff * t;
}

/**
 * Serpentine inverse kinematics with transverse sine wave displacement.
 * Head smoothly follows target while trailing vertebrae maintain distance constraints
 * and undulate with natural lateral sine wave swimming motion.
 */
export function solveKinematics(
  segments: Segment[],
  target: Point,
  segLength: number,
  waveTimer: number,
  isSwimming: boolean
): void {
  if (segments.length === 0) return;

  const head = segments[0];
  const dx = target.x - head.x;
  const dy = target.y - head.y;
  const dist = Math.hypot(dx, dy);

  if (dist > 0.05) {
    head.x += dx * 0.12;
    head.y += dy * 0.12;
    const targetAngle = Math.atan2(dy, dx);
    head.angle = angleLerp(head.angle, targetAngle, 0.16);
  }

  // Trailing segment distance constraints + transverse undulation
  for (let i = 1; i < segments.length; i++) {
    const prev = segments[i - 1];
    const curr = segments[i];

    let segDx = curr.x - prev.x;
    let segDy = curr.y - prev.y;
    let curDist = Math.hypot(segDx, segDy);

    if (curDist < 0.001) {
      segDx = Math.cos(prev.angle + Math.PI);
      segDy = Math.sin(prev.angle + Math.PI);
      curDist = 1;
    }

    const angle = Math.atan2(segDy, segDx);
    curr.angle = angle;

    // Normal perpendicular vector to segment direction
    const normX = -Math.sin(angle);
    const normY = Math.cos(angle);

    let waveOffset = 0;
    if (isSwimming) {
      const taper = Math.sin((i / segments.length) * Math.PI);
      waveOffset = Math.sin(waveTimer * 0.008 - i * 0.55) * 3.5 * taper;
    }

    curr.x = prev.x + (segDx / curDist) * segLength + normX * waveOffset;
    curr.y = prev.y + (segDy / curDist) * segLength + normY * waveOffset;
  }
}

/**
 * Calculates gaze angle of the head toward the pointer.
 * Returns relative angle offset clamped to [-maxGaze, maxGaze].
 */
export function calculateGaze(head: Segment, pointer: Point | null, maxGaze = 0.75): number {
  if (!pointer) return 0;
  const dist = Math.hypot(pointer.x - head.x, pointer.y - head.y);
  if (dist > 380 || dist < 2) return 0;

  const targetAngle = Math.atan2(pointer.y - head.y, pointer.x - head.x);
  const diff = normalizeAngle(targetAngle - head.angle);
  const clamped = Math.max(-maxGaze, Math.min(maxGaze, diff));
  const proximityFactor = Math.max(0, 1 - dist / 380);
  return clamped * proximityFactor;
}

/**
 * Distance-based hit testing against wyrm head and trailing spine segments.
 */
export function isPointInWyrm(
  p: Point,
  segments: Segment[],
  headRadius = 24,
  bodyRadius = 14
): boolean {
  if (segments.length === 0) return false;
  if (distance(p, segments[0]) <= headRadius) return true;
  for (let i = 1; i < segments.length; i++) {
    if (distance(p, segments[i]) <= bodyRadius) return true;
  }
  return false;
}

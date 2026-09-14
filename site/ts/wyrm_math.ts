/**
 * wyrm_math.ts — Platform detection, trajectory kinematics, and gaze tracking for the Stalker.
 */

import { Platform, Point, Segment, WyrmDirection } from "./wyrm_types.js";

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
 * Scans the current viewport for valid surface platforms that the dragon can walk on.
 */
export function getPlatforms(): Platform[] {
  const platforms: Platform[] = [];
  const winW = typeof window !== "undefined" ? window.innerWidth : 1200;
  const winH = typeof window !== "undefined" ? window.innerHeight : 800;

  // 1. Ground floor platform along the bottom of the viewport
  platforms.push({ left: 10, right: winW - 10, y: winH - 36 });

  if (typeof document === "undefined") return platforms;

  // 2. Scan DOM elements (wish box, headers, quote card)
  const selectors = [
    { sel: ".bargain-box", isWish: true },
    { sel: ".featured", isWish: false },
    { sel: ".hero-title", isWish: false },
    { sel: "h2", isWish: false },
    { sel: ".archive-controls", isWish: false },
  ];

  for (const item of selectors) {
    const els = document.querySelectorAll(item.sel);
    els.forEach((el) => {
      const r = el.getBoundingClientRect();
      if (r.width >= 70 && r.top >= 40 && r.top <= winH - 60) {
        platforms.push({
          left: Math.max(10, r.left),
          right: Math.min(winW - 10, r.right),
          y: Math.round(r.top),
          isWishBox: item.isWish,
        });
      }
    });
  }

  return platforms;
}

/**
 * Solves the quadruped spine and tail coordinates based on foot ground level.
 */
export function solveQuadrupedSpine(
  segments: Segment[],
  x: number,
  y: number,
  direction: WyrmDirection,
  animTime: number,
  segLength = 10
): void {
  if (segments.length === 0) return;
  const flip = direction === "left";
  const bodyY = y - 14;

  // Head at index 0 (leads slightly ahead of shoulders)
  const head = segments[0];
  head.x = flip ? x - 12 : x + 12;
  head.y = bodyY - 2;

  // Torso and tail trailing vertebrae with excited puppy/hatchling wag
  for (let i = 1; i < segments.length; i++) {
    const seg = segments[i];
    const offset = i * segLength;
    const tailTaper = Math.max(0, (i - 1) / Math.max(1, segments.length - 1));
    const sway = Math.sin(animTime * 6 - i * 0.6) * 2.8 * tailTaper;
    seg.x = flip ? x - 12 + offset : x + 12 - offset;
    seg.y = bodyY + sway;
  }
}

/**
 * Calculates gaze angle toward the pointer.
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

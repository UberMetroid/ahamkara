/**
 * wyrm_types.ts — Core types, interfaces, and palette for the Ahamkara Wyrm.
 */

export const BONE = "#ece5d3";
export const RIVEN_VIOLET = "#c77dff";
export const TAKEN_TEAL = "#8fe3d0";
export const WISH_PINK = "#ff6ea0";
export const BONE_DARK = "#9d9482";
export const VOID_BLACK = "#0b0a10";

export interface Point {
  x: number;
  y: number;
}

export interface Segment {
  x: number;
  y: number;
  angle: number;
  size: number;
}

export interface Particle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  maxLife: number;
  color: string;
  size: number;
}

export interface HaloRing {
  x: number;
  y: number;
  radius: number;
  maxRadius: number;
  life: number;
  maxLife: number;
  color: string;
}

export interface WhisperFloat {
  text: string;
  x: number;
  y: number;
  life: number;
  maxLife: number;
  vy: number;
}

export type WyrmState = "roaming" | "seeking_perch" | "perched" | "docked" | "feeding";

export interface WyrmConfig {
  baseSegments: number;
  maxSegments: number;
  segmentLength: number;
  roamSpeed: number;
  perchDwellMs: number;
}

export const DEFAULT_WYRM_CONFIG: WyrmConfig = {
  baseSegments: 6,
  maxSegments: 20,
  segmentLength: 12,
  roamSpeed: 1.8,
  perchDwellMs: 5000,
};

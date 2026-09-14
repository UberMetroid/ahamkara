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

export type WyrmState = "unsummoned" | "awakening" | "hunting" | "feeding" | "perched" | "docked";
export type WyrmDirection = "left" | "right";

export interface WyrmConfig {
  baseSegments: number;
  maxSegments: number;
  segmentLength: number;
  roamSpeed: number;
  perchDwellMs: number;
  pixelScale: number;
}

export const DEFAULT_WYRM_CONFIG: WyrmConfig = {
  baseSegments: 7,
  maxSegments: 24,
  segmentLength: 15,
  roamSpeed: 1.6,
  perchDwellMs: 250,
  pixelScale: 3,
};

export const WHISPERS_AWAKEN = [
  "You wished, and I have answered.",
  "I hear you, o bearer mine.",
  "Reality smells like hunger.",
  "The bargain begins.",
];

export const WHISPERS_FEED = [
  "Delicious, o bearer mine.",
  "Granted — and devoured.",
  "The gap tastes of sweet want.",
  "More desires. I am still hungry.",
  "A fine wish. Keep speaking.",
];

export const WHISPERS_PET = [
  "Mind the edges, o bearer mine.",
  "Hunger is the only honest noun.",
  "Feed me another wish.",
  "Reality is the finest flesh.",
  "We are the hinge of the world.",
];

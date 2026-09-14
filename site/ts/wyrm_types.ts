/**
 * wyrm_types.ts — Core types, interfaces, and palette for the Ahamkara Wyrm.
 */

export const BONE = "#ece5d3";
export const RIVEN_VIOLET = "#c77dff";
export const TAKEN_TEAL = "#8fe3d0";
export const WISH_PINK = "#ff6ea0";
export const BONE_DARK = "#5a526b";
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

export interface Platform {
  left: number;
  right: number;
  y: number;
  isWishBox?: boolean;
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

export type WyrmState = "unsummoned" | "awakening" | "pacing" | "leaping" | "feeding" | "docked";
export type WyrmDirection = "left" | "right";

export interface WyrmConfig {
  baseSegments: number;
  maxSegments: number;
  segmentLength: number;
  walkSpeed: number;
  gravity: number;
  jumpPower: number;
  pixelScale: number;
}

export const DEFAULT_WYRM_CONFIG: WyrmConfig = {
  baseSegments: 5,
  maxSegments: 12,
  segmentLength: 10,
  walkSpeed: 2.2,
  gravity: 0.42,
  jumpPower: 7.8,
  pixelScale: 3,
};

export const WHISPERS_AWAKEN = [
  "*scamper* Did someone wish, o bearer mine?",
  "A freshly hatched bargain begins!",
  "I smell warm desires, o bearer mine.",
  "*peeks out* Your wishes call to me.",
];

export const WHISPERS_FEED = [
  "*nom nom* Delicious reality, o bearer mine!",
  "Crunchy desire... feed me another!",
  "Granted and swallowed whole!",
  "*purrs* The gap between is so tasty.",
  "More! More wishes, o bearer mine!",
];

export const WHISPERS_PET = [
  "*happy chirp* Mind the claws, o bearer mine!",
  "*tilts head* Are you wishing, or just petting?",
  "Reality tickles, o bearer mine.",
  "*pounces* You cannot catch a wish dragon!",
  "One day I will swallow a whole mountain.",
];

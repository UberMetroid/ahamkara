/**
 * env.ts — shared environment: whisper pool, motion gating, small utilities.
 */

export interface Whisper {
  q: string;
  s: string;
}

export function whispers(): Whisper[] {
  const el = document.getElementById("whisper-data");
  if (!el?.textContent) return [];
  try {
    return JSON.parse(el.textContent) as Whisper[];
  } catch {
    return [];
  }
}

export const reducedMotion = (): boolean =>
  window.matchMedia("(prefers-reduced-motion: reduce)").matches;

export const pick = <T,>(arr: T[]): T => arr[Math.floor(Math.random() * arr.length)];

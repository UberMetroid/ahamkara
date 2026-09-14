/**
 * trip.ts — chromatic aberration pulses on headings.
 * Gated behind prefers-reduced-motion.
 */

import { reducedMotion } from "./env.js";

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

/**
 * bargain.ts — the Make a Wish widget: grants the wish, names the price.
 */

import { pick } from "./env.js";
import { fxBurst, fxRing } from "./fx.js";
import { grantFlash } from "./flash.js";

export function initBargain(): void {
  const form = document.getElementById("wish-form") as HTMLFormElement | null;
  const input = document.getElementById("wish-input") as HTMLInputElement | null;
  const out = document.getElementById("wish-output");
  if (!form || !input || !out) return;

  const replies = [
    (w: string) => `Granted, o bearer mine. ${w} — and the price is the wanting. It never leaves you now.`,
    (w: string) => `Done. You will have ${w}, and you will forever remember the shape of the gap it filled.`,
    (w: string) => `A modest wish. ${w} is yours. The price: tell no one it was granted — everyone will know anyway.`,
    (w: string) => `${w}? Oh, delicious. Granted. Do not wonder what I took instead.`,
    (w: string) => `I have eaten hungrier wishes than ${w}. Granted — come back when the hunger returns. It always returns.`,
    (w: string) => `${w}. Yes. Yours. The interest compounds nightly, o bearer mine.`,
    (w: string) => `Consider it done. ${w} was always going to be yours; I merely made it cost something.`,
    (w: string) => `Granted — ${w}, wrapped in bone and sealed in whispers. Mind the edges. Wishes are sharp.`,
  ];

  form.addEventListener("submit", (e) => {
    e.preventDefault();
    const wish = input.value.trim();
    if (!wish) return;
    const cleaned = wish.replace(/[.!?]+$/, "");
    out.textContent = pick(replies)(cleaned);
    const box = document.querySelector(".bargain-box") as HTMLElement | null;
    const boxRect = box ? box.getBoundingClientRect() : form.getBoundingClientRect();
    const cx = Math.round(boxRect.left + boxRect.width / 2);
    const cy = Math.round(boxRect.top);
    fxBurst(cx, Math.round(boxRect.top + boxRect.height / 2), 44);
    fxRing(cx, Math.round(boxRect.top + boxRect.height / 2));
    grantFlash(cx, Math.round(boxRect.top + boxRect.height / 2));
    window.dispatchEvent(
      new CustomEvent("ahamkara:wish", { detail: { wish: cleaned, x: cx, y: cy } })
    );
    input.value = "";
    if (window.innerWidth > 720) input.focus();
  });
}

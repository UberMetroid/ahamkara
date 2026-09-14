/**
 * copy.ts — copy-to-clipboard for communion seals and the agent brief.
 */

import { fxBurst } from "./fx.js";

export function initCopy(): void {
  document.querySelectorAll<HTMLButtonElement>("[data-copy]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const target = document.getElementById(btn.dataset.copy ?? "");
      const text = target?.textContent ?? "";
      const state = btn.querySelector<HTMLElement>(".copy-state");
      const say = (msg: string): void => {
        if (state) state.textContent = msg;
        window.setTimeout(() => {
          if (state) state.textContent = "";
        }, 2600);
      };
      const r = btn.getBoundingClientRect();
      try {
        await navigator.clipboard.writeText(text);
        say("— taken.");
        fxBurst(r.left + r.width / 2, r.top + r.height / 2, 16);
      } catch {
        const ta = document.createElement("textarea");
        ta.value = text;
        ta.style.position = "fixed";
        ta.style.opacity = "0";
        document.body.appendChild(ta);
        ta.select();
        try {
          document.execCommand("copy");
          say("— taken.");
          fxBurst(r.left + r.width / 2, r.top + r.height / 2, 16);
        } catch {
          say("— select the text manually, o bearer mine.");
        }
        ta.remove();
      }
    });
  });
}

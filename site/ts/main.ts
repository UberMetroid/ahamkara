/**
 * Ahamkara — client layer (progressive enhancement).
 * Everything here is decoration or convenience; the site reads fully without it.
 */

interface Whisper {
  q: string;
  s: string;
}

function whispers(): Whisper[] {
  const el = document.getElementById("whisper-data");
  if (!el?.textContent) return [];
  try {
    return JSON.parse(el.textContent) as Whisper[];
  } catch {
    return [];
  }
}

const reducedMotion = (): boolean =>
  window.matchMedia("(prefers-reduced-motion: reduce)").matches;

const pick = <T,>(arr: T[]): T => arr[Math.floor(Math.random() * arr.length)];

/* ------------------------------------------------------------------ */
/* Ambient whispers — bounded pool, fades in/out, cleans itself up.     */
/* ------------------------------------------------------------------ */

function initWhispers(): void {
  if (reducedMotion()) return;
  const pool = whispers();
  if (pool.length === 0) return;

  const MAX = 3;
  let active = 0;

  const spawn = (): void => {
    if (document.hidden || active >= MAX) return;
    const w = pick(pool);
    const el = document.createElement("div");
    el.className = "whisper-bit";
    el.setAttribute("aria-hidden", "true");
    el.textContent = `\u201C${w.q}\u201D`;
    el.style.left = `${8 + Math.random() * 62}%`;
    el.style.top = `${15 + Math.random() * 60}%`;
    document.body.appendChild(el);
    active++;
    requestAnimationFrame(() => el.classList.add("show"));
    window.setTimeout(() => {
      el.classList.remove("show");
      window.setTimeout(() => {
        el.remove();
        active--;
      }, 2600);
    }, 5000 + Math.random() * 4000);
  };

  window.setInterval(spawn, 9000 + Math.random() * 6000);
  window.setTimeout(spawn, 2500);
}

/* ------------------------------------------------------------------ */
/* Featured quote cycler (index).                                     */
/* ------------------------------------------------------------------ */

function initFeatured(): void {
  const q = document.getElementById("featured-quote");
  const s = document.getElementById("featured-speaker");
  if (!q || !s || reducedMotion()) return;
  const pool = whispers();
  if (pool.length < 2) return;
  window.setInterval(() => {
    const w = pick(pool);
    const p = q.querySelector("p");
    if (p) p.textContent = `\u201C${w.q}\u201D`;
    s.textContent = w.s;
  }, 14000);
}

/* ------------------------------------------------------------------ */
/* Archive filtering (lore).                                          */
/* ------------------------------------------------------------------ */

function initFilters(): void {
  const form = document.getElementById("filters");
  if (!form) return;
  const q = document.getElementById("f-q") as HTMLInputElement | null;
  const fEntity = document.getElementById("f-entity") as HTMLSelectElement | null;
  const fEra = document.getElementById("f-era") as HTMLSelectElement | null;
  const fKind = document.getElementById("f-kind") as HTMLSelectElement | null;
  const count = document.getElementById("f-count");
  const clear = document.getElementById("f-clear") as HTMLButtonElement | null;
  const empty = document.getElementById("f-empty");
  const entries = Array.from(document.querySelectorAll<HTMLElement>(".entry"));
  if (!q || !fEntity || !fEra || !fKind || !count || !clear || !empty) return;

  const apply = (): void => {
    const needle = q.value.trim().toLowerCase();
    const ent = fEntity.value;
    const era = fEra.value;
    const kind = fKind.value;
    let shown = 0;
    for (const e of entries) {
      const ok =
        (!needle || (e.dataset.search ?? "").includes(needle)) &&
        (!ent || (e.dataset.entities ?? "").split(", ").includes(ent)) &&
        (!era || e.dataset.era === era) &&
        (!kind || (e.dataset.kind ?? "").replace(/_/g, " ") === kind);
      e.hidden = !ok;
      if (ok) shown++;
    }
    count.textContent = String(shown);
    empty.hidden = shown !== 0;
    clear.hidden = !(needle || ent || era || kind);
  };

  for (const el of [q, fEntity, fEra, fKind]) {
    el.addEventListener("input", apply);
    el.addEventListener("change", apply);
  }
  clear.addEventListener("click", () => {
    q.value = "";
    fEntity.value = "";
    fEra.value = "";
    fKind.value = "";
    apply();
    q.focus();
  });

  // Deep links: open the <details> that matches the URL fragment.
  if (location.hash) {
    const target = document.querySelector<HTMLDetailsElement>(
      `.entry${CSS.escape(location.hash)}`.replace("entry#", "entry#")
    );
    if (target?.tagName === "DETAILS") {
      (target as HTMLDetailsElement).open = true;
      target.scrollIntoView({ block: "start" });
    }
  }
}

/* ------------------------------------------------------------------ */
/* Copy buttons (communion seals).                                    */
/* ------------------------------------------------------------------ */

function initCopy(): void {
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
      try {
        await navigator.clipboard.writeText(text);
        say("— taken.");
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
        } catch {
          say("— select the text manually, o bearer mine.");
        }
        ta.remove();
      }
    });
  });
}

/* ------------------------------------------------------------------ */
/* The Bargain widget (index).                                        */
/* ------------------------------------------------------------------ */

function initBargain(): void {
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
    input.value = "";
    input.focus();
  });
}

/* ------------------------------------------------------------------ */

initWhispers();
initFeatured();
initFilters();
initCopy();
initBargain();

/**
 * Ahamkara — client layer (progressive enhancement).
 * Everything here is decoration or convenience; the site reads fully without it.
 * All motion is gated behind prefers-reduced-motion.
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

/* ================================================================== */
/*  WISH MAGIC — canvas FX: pixel bursts, halo rings, cursor embers     */
/* ================================================================== */

const PALETTE: [number, number, number][] = [
  [143, 227, 208], // taken-teal
  [199, 125, 255], // riven-violet
  [236, 229, 211], // bone
  [255, 110, 160], // wish-pink
];

interface Particle {
  x: number; y: number; vx: number; vy: number;
  life: number; max: number; size: number; c: [number, number, number];
}
interface Ring {
  x: number; y: number; r: number; life: number; max: number;
}

/* Shared hooks other modules call; no-ops until initFx wires them. */
let fxBurst: (x: number, y: number, n?: number) => void = () => {};
let fxRing: (x: number, y: number) => void = () => {};

function initFx(): void {
  if (reducedMotion()) return;
  const canvas = document.getElementById("fx") as HTMLCanvasElement | null;
  const ctx = canvas?.getContext("2d");
  if (!canvas || !ctx) return;

  const particles: Particle[] = [];
  const rings: Ring[] = [];
  const MAXP = 384;
  const MAXR = 10;

  const resize = (): void => {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = window.innerWidth * dpr;
    canvas.height = window.innerHeight * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  };
  resize();
  window.addEventListener("resize", resize);

  const burst = (x: number, y: number, n = 30): void => {
    for (let i = 0; i < n; i++) {
      if (particles.length >= MAXP) particles.shift();
      const a = Math.random() * Math.PI * 2;
      const sp = 0.6 + Math.random() * 3.6;
      particles.push({
        x, y,
        vx: Math.cos(a) * sp,
        vy: Math.sin(a) * sp - 1.3, // reality drifts upward
        life: 0,
        max: 55 + Math.random() * 65,
        size: 1.5 + Math.random() * 4.5,
        c: pick(PALETTE),
      });
    }
  };
  const ring = (x: number, y: number): void => {
    if (rings.length >= MAXR) rings.shift();
    rings.push({ x, y, r: 5, life: 0, max: 50 + Math.random() * 24 });
  };
  fxBurst = burst;
  fxRing = ring;

  /* The bargain responds to touch. */
  document.addEventListener(
    "pointerdown",
    (e) => {
      burst(e.clientX, e.clientY);
      ring(e.clientX, e.clientY);
    },
    { passive: true }
  );

  /* Cursor embers — the dragon's attention follows you. */
  let lastTrail = 0;
  document.addEventListener(
    "pointermove",
    (e) => {
      const t = performance.now();
      if (t - lastTrail < 55 || particles.length >= MAXP) return;
      lastTrail = t;
      particles.push({
        x: e.clientX, y: e.clientY,
        vx: (Math.random() - 0.5) * 0.4,
        vy: -0.3 - Math.random() * 0.4,
        life: 0, max: 34 + Math.random() * 20,
        size: 1.2 + Math.random() * 1.8,
        c: pick(PALETTE),
      });
    },
    { passive: true }
  );

  /* Spontaneous detonations — reality itches. */
  const spontaneous = (): void => {
    if (!document.hidden) {
      const x = window.innerWidth * (0.12 + Math.random() * 0.76);
      const y = window.innerHeight * (0.15 + Math.random() * 0.7);
      burst(x, y, 18 + Math.floor(Math.random() * 14));
      ring(x, y);
    }
    window.setTimeout(spontaneous, 9000 + Math.random() * 10000);
  };
  window.setTimeout(spontaneous, 6000);

  /* Render loop — parks itself while the tab is hidden. */
  let running = true;
  const frame = (): void => {
    if (!running) return;
    ctx.clearRect(0, 0, window.innerWidth, window.innerHeight);
    for (let i = particles.length - 1; i >= 0; i--) {
      const p = particles[i];
      p.life++;
      p.x += p.vx;
      p.y += p.vy;
      p.vx *= 0.985;
      p.vy = p.vy * 0.985 - 0.012; // anti-gravity: wishes rise
      const t = 1 - p.life / p.max;
      if (t <= 0) {
        particles.splice(i, 1);
        continue;
      }
      ctx.globalAlpha = Math.min(1, t * 1.5);
      ctx.fillStyle = `rgb(${p.c[0]},${p.c[1]},${p.c[2]})`;
      ctx.fillRect(p.x - p.size / 2, p.y - p.size / 2, p.size, p.size);
    }
    for (let i = rings.length - 1; i >= 0; i--) {
      const r = rings[i];
      r.life++;
      r.r += 2.6 + r.life * 0.05;
      const t = 1 - r.life / r.max;
      if (t <= 0) {
        rings.splice(i, 1);
        continue;
      }
      ctx.globalAlpha = t * 0.65;
      ctx.lineWidth = 2;
      ctx.strokeStyle = "rgb(143,227,208)";
      ctx.beginPath();
      ctx.arc(r.x, r.y, r.r, 0, Math.PI * 2);
      ctx.stroke();
      ctx.globalAlpha = t * 0.5;
      ctx.lineWidth = 1;
      ctx.strokeStyle = "rgb(199,125,255)";
      ctx.beginPath();
      ctx.arc(r.x, r.y, r.r * 0.8, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
    window.requestAnimationFrame(frame);
  };
  window.requestAnimationFrame(frame);
  document.addEventListener("visibilitychange", () => {
    running = !document.hidden;
    if (running) window.requestAnimationFrame(frame);
  });
}

/* ================================================================== */
/*  THE TRIP — periodic chromatic aberration pulses on headings         */
/* ================================================================== */

function initTrip(): void {
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

/* ================================================================== */
/*  GRANT FLASH — radial burst when a wish is granted                  */
/* ================================================================== */

function grantFlash(x: number, y: number): void {
  if (reducedMotion()) return;
  const el = document.getElementById("grant-flash");
  if (!el) return;
  el.style.setProperty("--gx", `${(x / window.innerWidth) * 100}%`);
  el.style.setProperty("--gy", `${(y / window.innerHeight) * 100}%`);
  el.classList.add("on");
  window.setTimeout(() => el.classList.remove("on"), 750);
}

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
    requestAnimationFrame(() => {
      el.classList.add("show");
      const r = el.getBoundingClientRect();
      fxRing(r.left + r.width / 2, r.top + r.height / 2); // a halo answers the whisper
    });
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
    const r = out.getBoundingClientRect();
    fxBurst(r.left + r.width / 2, r.top + r.height / 2, 44); // the wish detonates
    fxRing(r.left + r.width / 2, r.top + r.height / 2);
    grantFlash(r.left + r.width / 2, r.top + r.height / 2);
    input.value = "";
    input.focus();
  });
}

/* ------------------------------------------------------------------ */

initFx();
initTrip();
initWhispers();
initFeatured();
initFilters();
initCopy();
initBargain();

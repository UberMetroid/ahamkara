/**
 * wyrm.ts — Orchestrator, canvas injection, hitbox proxy, and idle power-down.
 */

import { WyrmEntity } from "./wyrm_entity.js";
import { renderHaloRings, renderParticles, renderWhispers, renderWyrm } from "./wyrm_render.js";
import { Point } from "./wyrm_types.js";
import { reducedMotion } from "./env.js";

let entity: WyrmEntity | null = null;
let canvas: HTMLCanvasElement | null = null;
let ctx: CanvasRenderingContext2D | null = null;
let hitbox: HTMLButtonElement | null = null;
let pointer: Point | null = null;
let rafId = 0;
let lastTime = 0;
let isSuspended = false;

function updateHitbox(): void {
  if (!hitbox) return;
  if (!entity || !entity.isSummoned || entity.segments.length === 0) {
    hitbox.style.display = "none";
    return;
  }
  hitbox.style.display = "block";
  const head = entity.segments[0];
  hitbox.style.transform = `translate(${Math.round(head.x)}px, ${Math.round(head.y)}px)`;
}

function renderStaticFrame(): void {
  if (!entity || !ctx || !canvas) return;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  ctx.clearRect(0, 0, canvas.width / dpr, canvas.height / dpr);
  if (entity.isSummoned) {
    renderWyrm(
      ctx,
      entity.segments,
      entity.state,
      entity.direction,
      entity.animTime,
      entity.config.pixelScale
    );
  }
  updateHitbox();
}

function loop(now: number): void {
  rafId = 0;
  if (isSuspended || !entity || !ctx || !canvas) return;
  if (!entity.isSummoned) {
    updateHitbox();
    return;
  }

  const dt = Math.min(64, now - (lastTime || now));
  lastTime = now;

  const active = entity.update(dt, pointer, false);

  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  ctx.clearRect(0, 0, canvas.width / dpr, canvas.height / dpr);

  renderWyrm(
    ctx,
    entity.segments,
    entity.state,
    entity.direction,
    entity.animTime,
    entity.config.pixelScale
  );
  renderHaloRings(ctx, entity.rings);
  renderParticles(ctx, entity.particles);
  renderWhispers(ctx, entity.whispers);

  updateHitbox();

  if (active) {
    rafId = requestAnimationFrame(loop);
  }
}

export function wake(): void {
  if (!entity || !entity.isSummoned) return;
  if (reducedMotion()) {
    renderStaticFrame();
    return;
  }
  if (isSuspended || rafId !== 0) return;
  lastTime = performance.now();
  rafId = requestAnimationFrame(loop);
}

export function feedWyrm(x?: number, y?: number): void {
  if (!entity) return;
  let cx = typeof x === "number" ? x : window.innerWidth / 2;
  let cy = typeof y === "number" ? y : window.innerHeight / 2;
  if (typeof x !== "number" || typeof y !== "number") {
    const el = document.querySelector(".bargain-box");
    if (el) {
      const r = el.getBoundingClientRect();
      cx = r.left + r.width / 2;
      cy = r.top + r.height / 2;
    }
  }

  if (!entity.isSummoned) {
    entity.awaken(cx, cy);
  } else {
    entity.feed(cx, cy);
  }
  wake();
}

function resize(): void {
  if (!canvas || !ctx) return;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const w = window.innerWidth;
  const h = window.innerHeight;
  canvas.width = Math.round(w * dpr);
  canvas.height = Math.round(h * dpr);
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.imageSmoothingEnabled = false;

  if (reducedMotion()) {
    entity?.dock();
    renderStaticFrame();
  } else if (entity?.isSummoned) {
    wake();
  }
}

export function initWyrm(): void {
  if (typeof document === "undefined") return;

  canvas = (document.getElementById("wyrm-canvas") as HTMLCanvasElement) || document.createElement("canvas");
  canvas.id = "wyrm-canvas";
  canvas.setAttribute("aria-hidden", "true");
  if (!canvas.parentElement) {
    document.body.appendChild(canvas);
  }

  ctx = canvas.getContext("2d");
  if (!ctx) return;

  entity = new WyrmEntity();

  // Create accessible DOM hitbox proxy button
  hitbox = (document.getElementById("wyrm-hitbox") as HTMLButtonElement) || document.createElement("button");
  hitbox.id = "wyrm-hitbox";
  hitbox.className = "wyrm-hitbox";
  hitbox.type = "button";
  hitbox.setAttribute("aria-label", "Ahamkara wish-dragon");
  hitbox.style.display = "none";
  if (!hitbox.parentElement) {
    document.body.appendChild(hitbox);
  }

  hitbox.addEventListener("click", () => {
    if (entity) {
      entity.interact();
      wake();
    }
  });

  window.addEventListener(
    "pointermove",
    (e) => {
      pointer = { x: e.clientX, y: e.clientY };
      if (entity?.isSummoned) wake();
    },
    { passive: true }
  );

  window.addEventListener("pointerleave", () => {
    pointer = null;
  });

  window.addEventListener("resize", resize, { passive: true });

  document.addEventListener("visibilitychange", () => {
    if (document.hidden) {
      isSuspended = true;
      if (rafId) {
        cancelAnimationFrame(rafId);
        rafId = 0;
      }
    } else {
      isSuspended = false;
      if (entity?.isSummoned) wake();
    }
  });

  window.addEventListener("ahamkara:wish", (e: Event) => {
    const custom = e as CustomEvent<{ x?: number; y?: number }>;
    feedWyrm(custom.detail?.x, custom.detail?.y);
  });

  const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
  mq.addEventListener?.("change", () => {
    if (reducedMotion()) {
      if (rafId) {
        cancelAnimationFrame(rafId);
        rafId = 0;
      }
      entity?.dock();
      renderStaticFrame();
    } else if (entity?.isSummoned) {
      wake();
    }
  });

  resize();
}

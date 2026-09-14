/**
 * smoke.ts — dream smoke canvas controller and lifecycle.
 * Manages High-DPI scaling, RAF scheduling, IntersectionObserver,
 * visibility throttling, and prefers-reduced-motion gating.
 */

import { createPuffs, renderStaticSmoke, updateAndRenderPuffs, WispPuff } from "./smoke_engine.js";

export function initSmoke(): void {
  const canvas = document.getElementById("hero-smoke") as HTMLCanvasElement | null;
  if (!canvas) return;
  const ctx = canvas.getContext("2d");
  if (!ctx) return;

  const motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
  let isReducedMotion = motionQuery.matches;
  let isDocVisible = !document.hidden;
  let isIntersecting = true;
  let rafId: number | null = null;

  let width = 0;
  let height = 0;
  let puffs: WispPuff[] = [];
  let timeSec = 0;
  let lastTime = 0;

  function resize(): void {
    if (!canvas || !ctx) return;
    const rect = canvas.getBoundingClientRect();
    width = Math.max(1, Math.round(rect.width));
    height = Math.max(1, Math.round(rect.height));

    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    if (isReducedMotion) {
      renderStaticSmoke(ctx, width, height);
    }
  }

  function tick(now: number): void {
    if (!isIntersecting || !isDocVisible || isReducedMotion) {
      rafId = null;
      return;
    }

    if (lastTime === 0) lastTime = now;
    const dt = Math.min(0.064, (now - lastTime) / 1000);
    lastTime = now;
    timeSec += dt;

    if (ctx && width > 0 && height > 0) {
      updateAndRenderPuffs(ctx, puffs, width, height, timeSec, dt);
    }

    rafId = requestAnimationFrame(tick);
  }

  function start(): void {
    if (rafId === null && isIntersecting && isDocVisible && !isReducedMotion) {
      lastTime = 0;
      rafId = requestAnimationFrame(tick);
    }
  }

  function stop(): void {
    if (rafId !== null) {
      cancelAnimationFrame(rafId);
      rafId = null;
    }
  }

  function evaluateState(): void {
    if (isReducedMotion) {
      stop();
      if (ctx && width > 0 && height > 0) {
        renderStaticSmoke(ctx, width, height);
      }
    } else if (isIntersecting && isDocVisible) {
      start();
    } else {
      stop();
    }
  }

  puffs = createPuffs(22);
  resize();

  if (typeof ResizeObserver !== "undefined") {
    const ro = new ResizeObserver(() => {
      resize();
    });
    ro.observe(canvas);
  } else {
    window.addEventListener("resize", resize, { passive: true });
  }

  if (typeof IntersectionObserver !== "undefined") {
    const io = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.target === canvas) {
            isIntersecting = entry.isIntersecting;
            evaluateState();
          }
        }
      },
      { threshold: 0.01 }
    );
    io.observe(canvas);
  }

  document.addEventListener("visibilitychange", () => {
    isDocVisible = !document.hidden;
    evaluateState();
  });

  const onMotionChange = (e: MediaQueryListEvent): void => {
    isReducedMotion = e.matches;
    evaluateState();
  };
  if (motionQuery.addEventListener) {
    motionQuery.addEventListener("change", onMotionChange);
  } else {
    motionQuery.addListener(onMotionChange);
  }

  evaluateState();
}

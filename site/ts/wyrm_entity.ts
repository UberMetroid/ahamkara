/**
 * wyrm_entity.ts — State machine, landmark perching, feeding growth, and interaction.
 */

import {
  BONE, DEFAULT_WYRM_CONFIG, HaloRing, Particle, Point,
  RIVEN_VIOLET, Segment, TAKEN_TEAL, WhisperFloat, WISH_PINK,
  WyrmConfig, WyrmState,
} from "./wyrm_types.js";
import { calculateGaze, distance, solveKinematics } from "./wyrm_math.js";
import { pick, whispers } from "./env.js";

const SESSION_KEY = "ahamkara_wyrm_segments";

function getStoredSegments(fallback = 6): number {
  try {
    const v = parseInt(sessionStorage.getItem(SESSION_KEY) || "", 10);
    if (!isNaN(v) && v >= 6 && v <= 20) return v;
  } catch { /* sandboxed fallback */ }
  return fallback;
}

function storeSegments(count: number): void {
  try {
    sessionStorage.setItem(SESSION_KEY, String(count));
  } catch { /* sandboxed fallback */ }
}

export class WyrmEntity {
  segments: Segment[] = [];
  state: WyrmState = "roaming";
  particles: Particle[] = [];
  rings: HaloRing[] = [];
  whispers: WhisperFloat[] = [];
  target: Point = { x: 200, y: 200 };
  flareTimer = 0;
  gazeAngle = 0;
  dwellTimer = 0;
  waveTimer = 0;
  config: WyrmConfig;

  constructor(cfg: WyrmConfig = DEFAULT_WYRM_CONFIG) {
    this.config = cfg;
    const count = getStoredSegments(cfg.baseSegments);
    const startX = typeof window !== "undefined" ? window.innerWidth - 120 : 300;
    const startY = 160;

    for (let i = 0; i < count; i++) {
      this.segments.push({
        x: startX - i * cfg.segmentLength,
        y: startY,
        angle: 0,
        size: Math.max(2, 6 - i * 0.2),
      });
    }
    this.pickNextTarget();
  }

  private findLandmarkPoint(): Point | null {
    if (typeof document === "undefined") return null;
    const selectors = [".bargain-box", ".hero-title", ".brand", "main h1", "main h2", ".seal"];
    for (const sel of selectors) {
      const el = document.querySelector(sel);
      if (el) {
        const r = el.getBoundingClientRect();
        if (r.width > 0 && r.height > 0 && r.top < window.innerHeight && r.bottom > 0) {
          const placeRight = r.right + 44 < window.innerWidth - 30;
          return {
            x: placeRight ? r.right + 28 : Math.max(30, r.left - 28),
            y: Math.max(40, r.top + r.height * 0.4),
          };
        }
      }
    }
    return null;
  }

  pickNextTarget(): void {
    const landmark = Math.random() < 0.65 ? this.findLandmarkPoint() : null;
    if (landmark) {
      this.target = landmark;
      this.state = "seeking_perch";
    } else {
      const w = window.innerWidth;
      const h = window.innerHeight;
      const onRight = Math.random() < 0.5;
      const x = onRight ? w - Math.random() * 120 - 30 : Math.random() * 120 + 30;
      const y = Math.random() * (h - 140) + 70;
      this.target = { x, y };
      this.state = "roaming";
    }
    this.dwellTimer = this.config.perchDwellMs + Math.random() * 2000;
  }

  dock(x = window.innerWidth - 60, y = window.innerHeight - 60): void {
    this.state = "docked";
    this.target = { x, y };
    for (let i = 0; i < this.segments.length; i++) {
      const curl = i * 0.35;
      this.segments[i].x = x - Math.cos(curl) * (i * 5);
      this.segments[i].y = y - Math.sin(curl) * (i * 5);
      this.segments[i].angle = curl + Math.PI;
    }
  }

  feed(): void {
    this.flareTimer = 60;
    this.state = "feeding";
    if (this.segments.length < this.config.maxSegments) {
      const last = this.segments[this.segments.length - 1];
      this.segments.push({ x: last.x, y: last.y, angle: last.angle, size: 2 });
      storeSegments(this.segments.length);
    }
    this.spawnBurst(this.segments[0].x, this.segments[0].y, 16, WISH_PINK);
    this.spawnRing(this.segments[0].x, this.segments[0].y, WISH_PINK);
    this.spawnWhisper("Hunger satisfied... for a moment.");
  }

  interact(): void {
    if (this.segments.length === 0) return;
    const head = this.segments[0];
    this.spawnBurst(head.x, head.y, 12, TAKEN_TEAL);
    this.spawnRing(head.x, head.y, RIVEN_VIOLET);

    const pool = whispers();
    const quote = pool.length > 0 ? pick(pool).q : "O bearer mine...";
    this.spawnWhisper(quote);
    if (this.state === "perched") this.dwellTimer = 2000;
  }

  spawnBurst(x: number, y: number, count: number, color: string): void {
    for (let i = 0; i < count; i++) {
      const angle = (i / count) * Math.PI * 2 + Math.random() * 0.5;
      const spd = 1.2 + Math.random() * 2.5;
      this.particles.push({
        x, y,
        vx: Math.cos(angle) * spd,
        vy: Math.sin(angle) * spd,
        life: 25 + Math.random() * 15,
        maxLife: 40,
        color: Math.random() < 0.4 ? BONE : color,
        size: Math.random() < 0.5 ? 2 : 3,
      });
    }
  }

  spawnRing(x: number, y: number, color: string): void {
    this.rings.push({ x, y, radius: 4, maxRadius: 36, life: 28, maxLife: 28, color });
  }

  spawnWhisper(text: string): void {
    if (this.segments.length === 0) return;
    const head = this.segments[0];
    this.whispers.push({
      text: `“${text}”`,
      x: head.x,
      y: head.y - 18,
      life: 140,
      maxLife: 140,
      vy: -0.35,
    });
  }

  update(dt: number, pointer: Point | null, isReducedMotion: boolean): boolean {
    if (isReducedMotion) {
      if (this.state !== "docked") this.dock();
      return false;
    }

    this.waveTimer += dt;
    if (this.flareTimer > 0) this.flareTimer--;

    const head = this.segments[0];
    this.gazeAngle = calculateGaze(head, pointer);

    const distToTarget = distance(head, this.target);
    const isSwimming = distToTarget > 6;

    if (this.state === "seeking_perch" && distToTarget <= 10) {
      this.state = "perched";
    }

    if (this.state === "perched" || this.state === "feeding") {
      this.dwellTimer -= dt;
      if (this.dwellTimer <= 0) this.pickNextTarget();
    }

    solveKinematics(this.segments, this.target, this.config.segmentLength, this.waveTimer, isSwimming);

    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.x += p.vx; p.y += p.vy;
      p.vx *= 0.94; p.vy *= 0.94;
      p.life--;
      if (p.life <= 0) this.particles.splice(i, 1);
    }

    for (let i = this.rings.length - 1; i >= 0; i--) {
      const r = this.rings[i];
      r.life--;
      if (r.life <= 0) this.rings.splice(i, 1);
    }

    for (let i = this.whispers.length - 1; i >= 0; i--) {
      const w = this.whispers[i];
      w.y += w.vy;
      w.life--;
      if (w.life <= 0) this.whispers.splice(i, 1);
    }

    const hasFx = this.particles.length > 0 || this.rings.length > 0 ||
                  this.whispers.length > 0 || this.flareTimer > 0;
    const isMoving = isSwimming || Math.abs(this.gazeAngle) > 0.05;
    return hasFx || isMoving;
  }
}

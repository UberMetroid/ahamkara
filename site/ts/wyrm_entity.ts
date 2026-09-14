/**
 * wyrm_entity.ts — State machine, wish-awakening, feeding growth, and 2D kinematics.
 */

import {
  DEFAULT_WYRM_CONFIG,
  HaloRing,
  Particle,
  Point,
  Segment,
  WhisperFloat,
  WHISPERS_AWAKEN,
  WHISPERS_FEED,
  WHISPERS_PET,
  WyrmConfig,
  WyrmDirection,
  WyrmState,
} from "./wyrm_types.js";
import { distance, solveKinematics } from "./wyrm_math.js";
import { pick } from "./env.js";

export class WyrmEntity {
  segments: Segment[] = [];
  state: WyrmState = "unsummoned";
  direction: WyrmDirection = "right";
  particles: Particle[] = [];
  rings: HaloRing[] = [];
  whispers: WhisperFloat[] = [];
  target: Point = { x: 200, y: 200 };
  dwellTimer = 0;
  waveTimer = 0;
  feedTimer = 0;
  animTime = 0;
  config: WyrmConfig;

  constructor(cfg: WyrmConfig = DEFAULT_WYRM_CONFIG) {
    this.config = cfg;
    this.state = "unsummoned";
    this.segments = [];
  }

  get isSummoned(): boolean {
    return this.state !== "unsummoned";
  }

  private spawnAt(x: number, y: number, count: number): void {
    this.segments = [];
    for (let i = 0; i < count; i++) {
      this.segments.push({
        x: x - i * this.config.segmentLength,
        y,
        angle: 0,
        size: Math.max(2, 8 - i * 0.25),
      });
    }
    this.target = { x, y };
  }

  awaken(originX: number, originY: number): void {
    const count = this.config.baseSegments;
    this.spawnAt(originX, originY, count);
    this.state = "hunting";
    this.direction = "right";
    this.spawnHalo(originX, originY, "#ff6ea0");
    this.spawnBurst(originX, originY, 36);
    this.say(pick(WHISPERS_AWAKEN), originX, originY - 30);
    this.pickNextTarget();
  }

  feed(originX: number, originY: number): void {
    if (!this.isSummoned) {
      this.awaken(originX, originY);
      return;
    }
    this.state = "feeding";
    this.feedTimer = 2200;
    this.target = { x: originX, y: originY - 24 };
    this.direction = originX < this.segments[0].x ? "left" : "right";
    this.addSegment();
    this.spawnHalo(originX, originY, "#8fe3d0");
    this.spawnBurst(originX, originY, 28);
    this.say(pick(WHISPERS_FEED), originX, originY - 36);
  }

  addSegment(): void {
    if (this.segments.length >= this.config.maxSegments) return;
    const last = this.segments[this.segments.length - 1];
    this.segments.push({
      x: last.x,
      y: last.y,
      angle: last.angle,
      size: Math.max(2, last.size - 0.2),
    });
  }

  say(text: string, x?: number, y?: number): void {
    const head = this.segments[0] || { x: 200, y: 200 };
    this.whispers.push({
      text,
      x: x ?? head.x,
      y: y ?? head.y - 30,
      life: 3200,
      maxLife: 3200,
      vy: -0.22,
    });
  }

  interact(): void {
    if (!this.isSummoned) return;
    const head = this.segments[0];
    this.spawnHalo(head.x, head.y, "#c77dff");
    this.spawnBurst(head.x, head.y, 22);
    this.say(pick(WHISPERS_PET));
    this.pickNextTarget();
  }

  dock(): void {
    if (!this.isSummoned) return;
    this.state = "docked";
    const x = window.innerWidth - 80;
    const y = window.innerHeight - 80;
    this.target = { x, y };
    for (let i = 0; i < this.segments.length; i++) {
      this.segments[i].x = x - i * 4;
      this.segments[i].y = y;
    }
  }

  private pickHuntingTarget(): Point {
    const candidates: Point[] = [];
    // Priority 1: Bargain box ("hunting for more wishes")
    const wishBox = document.querySelector(".bargain-box");
    if (wishBox) {
      const r = wishBox.getBoundingClientRect();
      if (r.width > 0 && r.height > 0) {
        candidates.push({ x: r.left + r.width * 0.5, y: Math.max(60, r.top - 36) });
        candidates.push({ x: r.left + r.width * 0.2, y: Math.max(60, r.top - 18) });
        candidates.push({ x: r.left + r.width * 0.8, y: Math.max(60, r.top - 18) });
      }
    }
    // Priority 2: Page headings and hero quote
    const landmarks = document.querySelectorAll(".hero-title, .featured blockquote, h2");
    landmarks.forEach((el) => {
      const r = el.getBoundingClientRect();
      if (r.width > 0 && r.height > 0 && r.top >= 0 && r.bottom <= window.innerHeight) {
        candidates.push({ x: r.left + r.width * 0.5, y: Math.max(50, r.top - 24) });
      }
    });

    if (candidates.length > 0 && Math.random() < 0.6) {
      return candidates[Math.floor(Math.random() * candidates.length)];
    }

    const w = window.innerWidth;
    const h = window.innerHeight;
    const pad = 70;
    return {
      x: Math.random() * (w - pad * 2) + pad,
      y: Math.random() * (h - pad * 2) + pad,
    };
  }

  pickNextTarget(): void {
    this.target = this.pickHuntingTarget();
    this.dwellTimer = 2500 + Math.random() * 3000;
  }

  spawnBurst(x: number, y: number, n = 20): void {
    const colors = ["#8fe3d0", "#c77dff", "#ece5d3", "#ff6ea0"];
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2;
      const sp = 0.5 + Math.random() * 2.8;
      this.particles.push({
        x,
        y,
        vx: Math.cos(a) * sp,
        vy: Math.sin(a) * sp - 0.4,
        life: 50 + Math.random() * 40,
        maxLife: 90,
        color: pick(colors),
        size: Math.random() < 0.5 ? 2 : 3,
      });
    }
  }

  spawnHalo(x: number, y: number, color = "#8fe3d0"): void {
    this.rings.push({ x, y, radius: 4, maxRadius: 36, life: 40, maxLife: 40, color });
  }

  update(dt: number, pointer: Point | null, reduced: boolean): boolean {
    if (!this.isSummoned) return false;
    this.animTime += dt * 0.001;
    if (reduced) {
      this.dock();
      return false;
    }

    this.waveTimer += dt;
    if (this.feedTimer > 0) {
      this.feedTimer -= dt;
      if (this.feedTimer <= 0 && this.state === "feeding") {
        this.state = "hunting";
        this.pickNextTarget();
      }
    }

    const head = this.segments[0];
    if (distance(head, this.target) < 32) {
      this.dwellTimer -= dt;
      if (this.dwellTimer <= 0 && this.state !== "feeding") {
        this.pickNextTarget();
      }
    }

    if (Math.abs(this.target.x - head.x) > 4) {
      this.direction = this.target.x > head.x ? "right" : "left";
    }

    solveKinematics(this.segments, this.target, this.config.segmentLength, this.waveTimer, true);

    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.x += p.vx;
      p.y += p.vy;
      p.vx *= 0.98;
      p.vy *= 0.98;
      if (--p.life <= 0) this.particles.splice(i, 1);
    }
    for (let i = this.rings.length - 1; i >= 0; i--) {
      if (--this.rings[i].life <= 0) this.rings.splice(i, 1);
    }
    for (let i = this.whispers.length - 1; i >= 0; i--) {
      const w = this.whispers[i];
      w.y += w.vy;
      w.life -= dt;
      if (w.life <= 0) this.whispers.splice(i, 1);
    }
    return true;
  }
}

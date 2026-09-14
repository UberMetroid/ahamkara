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
import { calculateGaze, distance, pickHuntingTarget, solveKinematics } from "./wyrm_math.js";
import { pick } from "./env.js";

const SESSION_KEY = "ahamkara_dragon_summoned_v2";
const SEGMENTS_KEY = "ahamkara_dragon_segments_v2";

export class WyrmEntity {
  segments: Segment[] = [];
  state: WyrmState = "unsummoned";
  direction: WyrmDirection = "right";
  gazeAngle = 0;
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
    const wasSummoned =
      typeof sessionStorage !== "undefined" &&
      sessionStorage.getItem(SESSION_KEY) === "true";

    if (wasSummoned) {
      const count =
        parseInt(sessionStorage.getItem(SEGMENTS_KEY) || "", 10) ||
        cfg.baseSegments;
      this.spawnAt(window.innerWidth - 120, 160, count);
      this.state = "hunting";
      this.pickNextTarget();
    } else {
      this.state = "unsummoned";
      this.segments = [];
    }
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
    try {
      sessionStorage.setItem(SESSION_KEY, "true");
      sessionStorage.setItem(SEGMENTS_KEY, String(count));
    } catch { /* sandboxed */ }
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
    try {
      sessionStorage.setItem(SEGMENTS_KEY, String(this.segments.length));
    } catch { /* sandboxed */ }
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

  pickNextTarget(): void {
    this.target = pickHuntingTarget();
    this.dwellTimer = this.config.perchDwellMs;
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
    const distToTarget = distance(head, this.target);
    if (distToTarget < 32) {
      this.dwellTimer -= dt;
      if (this.dwellTimer <= 0 && this.state !== "feeding") {
        this.pickNextTarget();
      }
    }

    if (pointer) {
      this.gazeAngle = calculateGaze(head, pointer);
      const distToPointer = distance(head, pointer);
      if (distToPointer < 260 && Math.abs(pointer.x - head.x) > 10) {
        this.direction = pointer.x > head.x ? "right" : "left";
      }
    } else {
      this.gazeAngle = 0;
      if (Math.abs(this.target.x - head.x) > 4) {
        this.direction = this.target.x > head.x ? "right" : "left";
      }
    }

    solveKinematics(
      this.segments,
      this.target,
      this.config.segmentLength,
      this.waveTimer,
      true,
      this.config.roamSpeed
    );

    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.x += p.vx; p.y += p.vy; p.vx *= 0.98; p.vy *= 0.98;
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

    const hasEffects = this.particles.length > 0 || this.rings.length > 0 || this.whispers.length > 0;
    const isProwling = this.state === "hunting" || this.state === "feeding";
    const isInteracting = pointer !== null && distance(head, pointer) < 260;
    return hasEffects || isProwling || isInteracting;
  }
}

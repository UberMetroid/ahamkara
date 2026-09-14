/**
 * wyrm_entity.ts — Inquisitive Hatchling Platform Walker State Machine & Kinematics.
 */

import {
  DEFAULT_WYRM_CONFIG,
  HaloRing,
  Particle,
  Platform,
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
import { calculateGaze, getPlatforms, solveQuadrupedSpine } from "./wyrm_math.js";
import { pick } from "./env.js";

const SESSION_KEY = "ahamkara_dragon_summoned_v2";
const SEGMENTS_KEY = "ahamkara_dragon_segments_v2";

export class WyrmEntity {
  segments: Segment[] = [];
  state: WyrmState = "unsummoned";
  direction: WyrmDirection = "right";
  x = 200; y = 400; vx = 0; vy = 0;
  isGrounded = true;
  currentPlatform: Platform | null = null;
  gazeAngle = 0;
  isBlinking = false;
  blinkTimer = 2200;
  headTilt = 0;
  curiousTimer = 0;
  isCurious = false;
  particles: Particle[] = [];
  rings: HaloRing[] = [];
  whispers: WhisperFloat[] = [];
  feedTimer = 0; animTime = 0; paceTimer = 0;
  config: WyrmConfig;

  constructor(cfg: WyrmConfig = DEFAULT_WYRM_CONFIG) {
    this.config = cfg;
    this.state = "unsummoned";
    this.segments = [];
    try { sessionStorage.removeItem(SESSION_KEY); sessionStorage.removeItem(SEGMENTS_KEY); } catch { /* sandboxed */ }
  }

  get isSummoned(): boolean {
    return this.state !== "unsummoned";
  }

  private initSegments(count: number): void {
    this.segments = [];
    for (let i = 0; i < count; i++) {
      this.segments.push({ x: this.x - i * this.config.segmentLength, y: this.y, angle: 0, size: 6 });
    }
  }

  awaken(originX: number, originY: number): void {
    const plats = getPlatforms();
    this.currentPlatform = plats.find((p) => p.isWishBox) || plats[0];
    this.x = originX; this.y = this.currentPlatform.y;
    this.initSegments(this.config.baseSegments);
    this.state = "pacing"; this.direction = "right";
    this.spawnHalo(this.x, this.y, "#ff6ea0");
    this.spawnBurst(this.x, this.y, 32);
    this.say(pick(WHISPERS_AWAKEN), this.x, this.y - 26);
  }

  onScroll(): void {
    if (!this.currentPlatform?.isWishBox) return;
    const box = document.querySelector(".bargain-box");
    if (!box) return;
    const r = box.getBoundingClientRect();
    this.currentPlatform.y = Math.round(r.top);
    this.currentPlatform.left = Math.max(10, r.left);
    this.currentPlatform.right = Math.min(window.innerWidth - 10, r.right);
    if (this.state === "pacing") this.y = this.currentPlatform.y;
  }

  feed(originX: number, originY: number): void {
    if (!this.isSummoned) { this.awaken(originX, originY); return; }
    this.state = "feeding"; this.feedTimer = 2000;
    this.direction = originX < this.x ? "left" : "right";
    this.addSegment();
    this.spawnHalo(originX, originY, "#8fe3d0");
    this.spawnBurst(originX, originY, 26);
    this.say(pick(WHISPERS_FEED), originX, originY - 30);
  }

  addSegment(): void {
    if (this.segments.length >= this.config.maxSegments) return;
    const last = this.segments[this.segments.length - 1] || { x: this.x, y: this.y, angle: 0, size: 4 };
    this.segments.push({ x: last.x, y: last.y, angle: last.angle, size: Math.max(2, last.size - 0.2) });
    try { sessionStorage.setItem(SEGMENTS_KEY, String(this.segments.length)); } catch { /* sandboxed */ }
  }

  say(text: string, x?: number, y?: number): void {
    const h = this.segments[0] || { x: this.x, y: this.y };
    this.whispers.push({ text, x: x ?? h.x, y: y ?? h.y - 28, life: 3000, maxLife: 3000, vy: -0.22 });
  }

  interact(): void {
    if (!this.isSummoned) return;
    const h = this.segments[0];
    this.spawnHalo(h.x, h.y, "#c77dff");
    this.spawnBurst(h.x, h.y, 20);
    this.say(pick(WHISPERS_PET));
    this.leapRandom();
  }

  dock(): void {
    if (!this.isSummoned) return;
    this.state = "docked";
    this.x = window.innerWidth - 80;
    this.y = window.innerHeight - 36;
    this.vx = 0; this.vy = 0;
  }

  private leapTo(plat: Platform): void {
    this.currentPlatform = plat;
    this.state = "leaping"; this.isGrounded = false;
    const targetX = (plat.left + plat.right) / 2;
    this.direction = targetX > this.x ? "right" : "left";
    const dy = plat.y - this.y;
    this.vy = dy < 0 ? -this.config.jumpPower * 1.12 : -this.config.jumpPower * 0.72;
    const frames = Math.max(20, Math.abs(this.vy) * 4);
    this.vx = (targetX - this.x) / frames;
    this.headTilt = -0.2;
  }

  private leapRandom(): void {
    const plats = getPlatforms().filter((p) => p !== this.currentPlatform);
    if (plats.length > 0) this.leapTo(pick(plats));
  }

  spawnBurst(x: number, y: number, n = 20): void {
    const colors = ["#8fe3d0", "#c77dff", "#ece5d3", "#ff6ea0"];
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2, sp = 0.5 + Math.random() * 2.8;
      this.particles.push({
        x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 0.4,
        life: 45 + Math.random() * 35, maxLife: 80, color: pick(colors),
        size: Math.random() < 0.5 ? 2 : 3,
      });
    }
  }

  spawnHalo(x: number, y: number, color = "#8fe3d0"): void {
    this.rings.push({ x, y, radius: 4, maxRadius: 32, life: 36, maxLife: 36, color });
  }

  private updateFX(dt: number): void {
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
      w.y += w.vy; w.life -= dt;
      if (w.life <= 0) this.whispers.splice(i, 1);
    }
  }

  update(dt: number, pointer: Point | null, reduced: boolean): boolean {
    if (!this.isSummoned) return false;
    if (reduced) { this.dock(); return false; }

    if (this.feedTimer > 0 && (this.feedTimer -= dt) <= 0 && this.state === "feeding") {
      this.state = "pacing";
    }

    this.blinkTimer -= dt;
    if (this.blinkTimer <= 0 && !this.isBlinking) {
      this.isBlinking = true;
    } else if (this.blinkTimer <= -180 && this.isBlinking) {
      this.isBlinking = false;
      this.blinkTimer = 2400 + Math.random() * 3200;
    }

    if (this.state === "leaping") {
      this.x += this.vx; this.y += this.vy;
      this.vy += this.config.gravity;
      this.animTime += dt * 0.003;

      for (const p of getPlatforms()) {
        if (this.vy > 0 && this.y >= p.y && this.y - this.vy <= p.y + 16 &&
            this.x >= p.left - 15 && this.x <= p.right + 15) {
          this.y = p.y; this.vy = 0; this.vx = 0;
          this.currentPlatform = p; this.isGrounded = true;
          this.state = "pacing"; this.paceTimer = 2200 + Math.random() * 3000;
          this.headTilt = 0; break;
        }
      }
      const floorY = window.innerHeight - 36;
      if (this.y >= floorY) {
        this.y = floorY; this.vy = 0; this.vx = 0;
        this.isGrounded = true; this.state = "pacing";
        this.headTilt = 0;
      }
    } else if (this.state === "pacing") {
      if (!this.currentPlatform) this.currentPlatform = getPlatforms()[0];
      const plat = this.currentPlatform;
      this.y = plat.y;

      if (this.isCurious) {
        this.curiousTimer -= dt;
        if (this.curiousTimer <= 0) {
          this.isCurious = false;
          this.headTilt = 0;
        }
      } else {
        this.x += (this.direction === "right" ? 1 : -1) * this.config.walkSpeed;
        this.animTime += dt * 0.007;
        this.paceTimer -= dt;

        if (this.paceTimer > 0 && Math.random() < 0.003) {
          this.isCurious = true;
          this.curiousTimer = 900 + Math.random() * 1200;
          this.headTilt = Math.random() < 0.5 ? 0.2 : -0.2;
        }

        const atRight = this.x >= plat.right - 22;
        const atLeft = this.x <= plat.left + 22;
        if (atRight || atLeft) {
          if (this.paceTimer <= 0 && Math.random() < 0.7) {
            this.leapRandom();
          } else {
            this.direction = atRight ? "left" : "right";
          }
        }
      }
    }

    const head = this.segments[0] || { x: this.x, y: this.y - 14, angle: 0, size: 6 };
    this.gazeAngle = pointer ? calculateGaze(head, pointer) : 0;
    solveQuadrupedSpine(this.segments, this.x, this.y, this.direction, this.animTime, this.config.segmentLength);
    this.updateFX(dt);
    return true;
  }
}

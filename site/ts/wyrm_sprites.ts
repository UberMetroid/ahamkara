/**
 * wyrm_sprites.ts — Handcrafted 2D pixel-art sprite matrices for the Inquisitive Hatchling.
 * Authentic discrete pixel grids rendered with integer block scaling.
 */

export const PALETTE: Record<string, string> = {
  B: "#ece5d3", // Bone
  S: "#d4cca8", // Ivory bone midtone
  D: "#5a526b", // Shaded bone / void shadow
  T: "#8fe3d0", // Taken Teal
  V: "#c77dff", // Riven Violet
  P: "#ff6ea0", // Wish Pink
  K: "#0b0a10", // Void Black
  W: "#ffffff", // Pure White glint / highlight
};

// 18x12 Inquisitive Hatchling Skull (Facing Right)
export const SPRITE_HATCHLING_HEAD: string[] = [
  "   D              ",
  "  DB   D          ",
  "  DBB DBB  DDDDD  ",
  "  DBBBBBBBBBBBBD  ",
  "  DBBBBB T T WBD  ",
  "  DBBBBB V V WBD  ",
  "  DBBBBBBBBBBBBD  ",
  "  DBBK W K W KBD  ",
  "   DBBBBBBBBBBD   ",
  "    DDDDDDDDDD    ",
  "                  ",
  "                  ",
];

// 18x12 Inquisitive Hatchling Blinking Skull
export const SPRITE_HATCHLING_BLINK: string[] = [
  "   D              ",
  "  DB   D          ",
  "  DBB DBB  DDDDD  ",
  "  DBBBBBBBBBBBBD  ",
  "  DBBBBBBBBBBBBD  ",
  "  DBBBBB D D D D  ",
  "  DBBBBBBBBBBBBD  ",
  "  DBBK W K W KBD  ",
  "   DBBBBBBBBBBD   ",
  "    DDDDDDDDDD    ",
  "                  ",
  "                  ",
];

// 18x12 Inquisitive Hatchling Open Feeding Maw
export const SPRITE_HATCHLING_FEED: string[] = [
  "   D              ",
  "  DB   D          ",
  "  DBB DBB  DDDDD  ",
  "  DBBBBBBBBBBBBD  ",
  "  DBBBBB T T WBD  ",
  "  DBBBBB V V WBD  ",
  "  DBBBKKKKKKKKBD  ",
  "   DBKK P P W P   ",
  "   DBKK  P P V    ",
  "    DBBBBW W WBD  ",
  "     DBBBBBBBBBD  ",
  "      DDDDDDDDD   ",
];

// 6x6 Compact Dorsal Segment
export const SPRITE_HATCHLING_BODY: string[] = [
  "  DB  ",
  " DBBD ",
  "DBTVBD",
  "DBVTBD",
  " DBBD ",
  "  DD  ",
];

// 4x4 Tapering Tail Vertebra
export const SPRITE_HATCHLING_TAIL: string[] = [
  " DB ",
  "DBBD",
  "DBTD",
  " DD ",
];

// 5x6 Articulated Scamper Leg Frames (0: forward plant, 1: stance, 2: push, 3: lift)
export const SPRITE_HATCHLING_LEG_FRAMES: string[][] = [
  [
    " DB  ",
    " DBB ",
    "  DB ",
    "  DB ",
    " DBWW",
    "     ",
  ],
  [
    " DB  ",
    " DBBD",
    "  DBB",
    "  DBB",
    " DBWW",
    "     ",
  ],
  [
    "  DB ",
    " DBB ",
    "DB   ",
    "DB   ",
    "WWD  ",
    "     ",
  ],
  [
    " DB  ",
    " DBBD",
    "  DBB",
    "  DBW",
    "     ",
    "     ",
  ],
];

// 6x8 Bouncy Tail Flame Wisps (3 frames)
export const SPRITE_HATCHLING_FLAME: string[][] = [
  [
    "  T   ",
    " TWT  ",
    " TVT  ",
    "TTVTT ",
    "TVPVT ",
    " TVT  ",
    "  T   ",
    "      ",
  ],
  [
    "   T  ",
    "  TWT ",
    " TPVT ",
    "TPPVT ",
    "TVVT  ",
    " TVT  ",
    "  T   ",
    "      ",
  ],
  [
    "  T   ",
    " TWT  ",
    " TVVT ",
    "TVPVT ",
    " TPVT ",
    "  TVT ",
    "   T  ",
    "      ",
  ],
];

/**
 * wyrm_sprites.ts — Handcrafted 2D pixel-art sprite matrices for the Ahamkara Dragon.
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
  W: "#ffffff", // Pure White glint / fang tip
};

// 22x14 Ahamkara Dragon Head (Facing Right)
// Antler horns, dual glowing eyes (Teal & Violet), bared fangs, chin spur
export const SPRITE_HEAD_RIGHT: string[] = [
  "   D                  ",
  "  DB   D              ",
  " D B  DBB             ",
  "DB B DB B             ",
  " D BDB  B  DDDDD      ",
  "  DBBBBBBBBB T WDDD   ",
  "   DBBBBB B V W B BBD ",
  "   DBBBBBBBBBBBBBBBBBD",
  "   DBBBK W K W K W K W",
  "    DBBK W K W KBBBBBD",
  "    DBBBBBBBBBBBBBBD  ",
  "     DBB B   DDD      ",
  "      D  D            ",
  "                      ",
];

// 22x14 Ahamkara Dragon Head Open Maw (Devouring a Wish)
export const SPRITE_HEAD_FEED: string[] = [
  "   D                  ",
  "  DB   D              ",
  " D B  DBB             ",
  "DB B DB B             ",
  " D BDB  B  DDDDD      ",
  "  DBBBBBBBBB T WDDD   ",
  "   DBBBBB B V W B BBD ",
  "   DBBBBBBBBBBBBBBBBBD",
  "   DBBBK W K W K W K W",
  "    DBKK  P P W P P   ",
  "    DBKK P P W W P P  ",
  "     DBKK  V V T T    ",
  "      DBBBBW W WBBBD  ",
  "       DBBBBBBBBBD    ",
];

// 16x12 Skeletal Dragon Wing (Frame 0: Upstroke)
export const SPRITE_WING_UP: string[] = [
  "      DBDD      ",
  "    DBBBBBBD    ",
  "   DBBTTTTVBBD  ",
  "  DBTTTVVVTVBBD ",
  " DBTTTVVVVVTTVBD",
  "DBTTVVVVVVVVTVBD",
  " BTVVVVVVVVTBD  ",
  "  BTVVVVVVTBD   ",
  "   BTVVVVTBD    ",
  "    BTVVTBD     ",
  "     BTBD       ",
  "      BD        ",
];

// 16x12 Skeletal Dragon Wing (Frame 1: Glide)
export const SPRITE_WING_MID: string[] = [
  "                ",
  "                ",
  "DBBBBBBBBBBBBD  ",
  " DBTTTTTTTTVBBD ",
  "  BTTTVVVVVTVTB ",
  "   BTVVVVVVVVTB ",
  "    BVVVVVVVVB  ",
  "     BTTTTVTB   ",
  "      BTTTVB    ",
  "       BTB      ",
  "        B       ",
  "                ",
];

// 16x12 Skeletal Dragon Wing (Frame 2: Downstroke)
export const SPRITE_WING_DOWN: string[] = [
  "      BD        ",
  "     BTBD       ",
  "    BTVVTBD     ",
  "   BTVVVVTBD    ",
  "  BTVVVVVVTBD   ",
  " BTVVVVVVVVTBD  ",
  "DBTTVVVVVVVVTVBD",
  " DBTTTVVVVVTTVBD",
  "  DBTTTVVVTVBBD ",
  "   DBBTTTTVBBD  ",
  "    DBBBBBBD    ",
  "      DBDD      ",
];

// 8x8 Dorsal Crest Vertebra
export const SPRITE_BODY_SEGMENT: string[] = [
  "   DB   ",
  "  DBBD  ",
  " DBBBBD ",
  "DBTVVTBD",
  "DBVTTVBD",
  " DBBBBD ",
  "  DBBD  ",
  "   DD   ",
];

// 6x6 Tapering Tail Vertebra
export const SPRITE_TAIL_SEGMENT: string[] = [
  "  DB  ",
  " DBBD ",
  "DBTVBD",
  "DBVTBD",
  " DBBD ",
  "  DD  ",
];

// 8x10 Animated Tail Flame Wisps (3 frames)
export const SPRITE_TAIL_FLAME: string[][] = [
  [
    "   T    ",
    "  TWT   ",
    "  TVT   ",
    " TTVTT  ",
    "TVPVVTT ",
    "TVPPPVT ",
    " TVPVT  ",
    "  TVT   ",
    "   T    ",
    "        ",
  ],
  [
    "    T   ",
    "   TWT  ",
    "  TVVT  ",
    "  TPPVT ",
    " TPPPVT ",
    "TVPVVT  ",
    " TVVT   ",
    "  TVT   ",
    "   T    ",
    "        ",
  ],
  [
    "   T    ",
    "  TWT   ",
    " TVVT   ",
    "TVPPVT  ",
    " TVPPVT ",
    "  TVPVT ",
    "   TVT  ",
    "    T   ",
    "        ",
    "        ",
  ],
];

/**
 * main.ts — client bootstrap. Everything here is progressive enhancement;
 * the site reads fully without it.
 */

import { initFx, initTrip } from "./fx.js";
import { initSigils } from "./sigils.js";
import { initFeatured, initWhispers } from "./whispers.js";
import { initFilters } from "./archive.js";
import { initCopy } from "./copy.js";
import { initBargain } from "./bargain.js";

initFx();
initTrip();
initSigils();
initWhispers();
initFeatured();
initFilters();
initCopy();
initBargain();

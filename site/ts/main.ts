/**
 * main.ts — client bootstrap. Everything here is progressive enhancement;
 * the site reads fully without it.
 */

import { initFx } from "./fx.js";
import { initTrip } from "./trip.js";
import { initSigils } from "./sigils.js";
import { initFeatured, initWhispers } from "./whispers.js";
import { initFilters } from "./archive.js";
import { initCopy } from "./copy.js";
import { initBargain } from "./bargain.js";
import { initSmoke } from "./smoke.js";

initFx();
initSmoke();
initTrip();
initSigils();
initWhispers();
initFeatured();
initFilters();
initCopy();
initBargain();

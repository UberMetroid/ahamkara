//! ahamkara-fx — the site's client runtime, compiled to WASM.
//! Everything here is progressive enhancement; the site reads fully
//! without it. One module per former ts/*.ts file.

mod archive;
mod bargain;
mod copy;
mod env;
mod flash;
mod fx;
mod fx_frame;
mod scroll;
mod sigils;
mod sigils_wall;
mod smoke;
mod smoke_engine;
mod trip;
mod whispers;

use wasm_bindgen::prelude::*;

#[wasm_bindgen(start)]
pub fn init() {
    scroll::init();
    fx::init();
    smoke::init();
    trip::init();
    sigils_wall::init();
    whispers::init_whispers();
    whispers::init_featured();
    archive::init();
    copy::init();
    bargain::init();
}

//! trip — chromatic aberration pulses on headings.
//! Gated behind prefers-reduced-motion.

use crate::env::{document, rand_range, reduced_motion, set_timeout};

fn pulse() {
    if !document().hidden() {
        let list = document().body().unwrap().class_list();
        let _ = list.add_1("tripping");
        set_timeout(2600 + rand_range(0.0, 2400.0) as i32, move || {
            let _ = list.remove_1("tripping");
        });
    }
    set_timeout(22000 + rand_range(0.0, 28000.0) as i32, pulse);
}

pub fn init() {
    if !reduced_motion() {
        set_timeout(12000, pulse);
    }
}

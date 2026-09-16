//! flash — radial burst overlay flash when a wish is granted.
//! Gated behind prefers-reduced-motion.

use crate::env::{document, reduced_motion, set_timeout, window};

pub fn grant_flash(x: f64, y: f64) {
    if reduced_motion() {
        return;
    }
    let Some(el) = document().get_element_by_id("grant-flash") else {
        return;
    };
    let w = window();
    let gx = x / w.inner_width().ok().and_then(|v| v.as_f64()).unwrap_or(1.0) * 100.0;
    let gy = y / w.inner_height().ok().and_then(|v| v.as_f64()).unwrap_or(1.0) * 100.0;
    let he: web_sys::HtmlElement = el.unchecked_into();
    let _ = he.style().set_property("--gx", &format!("{gx}%"));
    let _ = he.style().set_property("--gy", &format!("{gy}%"));
    let list = he.class_list();
    let _ = list.add_1("on");
    set_timeout(750, move || {
        let _ = list.remove_1("on");
    });
}

use wasm_bindgen::JsCast;

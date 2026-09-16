//! scroll — fixed-chrome metrics and scroll cues.
//! Measures .trap-head/.site-foot into --head-h/--foot-h so content
//! clears the bars, toggles can-up/can-down on <body>, and gives the
//! cue buttons a smooth page scroll.

use crate::env::{document, window};
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;

fn measure() {
    let Some(root) = document().document_element() else { return };
    let root: web_sys::HtmlElement = root.unchecked_into();
    for (sel, var) in [(".trap-head", "--head-h"), (".site-foot", "--foot-h")] {
        if let Ok(Some(el)) = document().query_selector(sel) {
            let h = el.get_bounding_client_rect().height();
            let _ = root.style().set_property(var, &format!("{h:.0}px"));
        }
    }
}

fn cues() {
    let (Some(body), Some(el)) = (document().body(), document().document_element()) else {
        return;
    };
    let vh = window()
        .inner_height()
        .ok()
        .and_then(|v| v.as_f64())
        .unwrap_or(0.0);
    let y = window().scroll_y().unwrap_or(0.0);
    let max = (el.scroll_height() as f64 - vh).max(0.0);
    let list = body.class_list();
    let _ = if y > 8.0 { list.add_1("can-up") } else { list.remove_1("can-up") };
    let _ = if y < max - 8.0 { list.add_1("can-down") } else { list.remove_1("can-down") };
}

fn page_scroll(dir: f64) {
    let vh = window()
        .inner_height()
        .ok()
        .and_then(|v| v.as_f64())
        .unwrap_or(600.0);
    let o = web_sys::ScrollToOptions::new();
    o.set_top(dir * vh * 0.82);
    o.set_behavior(web_sys::ScrollBehavior::Smooth);
    window().scroll_by_with_scroll_to_options(&o);
}

pub fn init() {
    measure();
    cues();

    // Re-measure on resize and when the brief's <details> toggles.
    let cb = Closure::<dyn FnMut(js_sys::Array)>::new(move |_: js_sys::Array| measure());
    let ro = web_sys::ResizeObserver::new(cb.as_ref().unchecked_ref()).unwrap();
    for sel in [".trap-head", ".site-foot"] {
        if let Ok(Some(el)) = document().query_selector(sel) {
            ro.observe(&el);
        }
    }
    cb.forget();
    std::mem::forget(ro);

    if let Ok(Some(brief)) = document().query_selector(".agent-brief") {
        let cb = Closure::<dyn FnMut()>::new(measure);
        let _ = brief.add_event_listener_with_callback("toggle", cb.as_ref().unchecked_ref());
        cb.forget();
    }

    let cb = Closure::<dyn FnMut()>::new(|| {
        measure();
        cues();
    });
    let w = window();
    let _ = w.add_event_listener_with_callback("resize", cb.as_ref().unchecked_ref());
    cb.forget();

    let cb = Closure::<dyn FnMut()>::new(cues);
    let _ = w.add_event_listener_with_callback("scroll", cb.as_ref().unchecked_ref());
    cb.forget();

    for (sel, dir) in [(".scroll-cue.up", -1.0), (".scroll-cue.down", 1.0)] {
        if let Ok(Some(b)) = document().query_selector(sel) {
            let cb = Closure::<dyn FnMut()>::new(move || page_scroll(dir));
            let _ = b.add_event_listener_with_callback("click", cb.as_ref().unchecked_ref());
            cb.forget();
        }
    }
}

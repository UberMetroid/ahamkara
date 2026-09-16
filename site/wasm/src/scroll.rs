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

/// The snap-aligned blocks cues step between — page heads, sections,
/// the entries list, and the index's fine-grained stops: the welcome
/// quote, title, description, the wish box, the nav grid, the colophon.
const SNAP_SEL: &str = "main > .page-head, main > section, main > .entries, .colophon, \
    .hero-viewport, .hero-title, .hero-desc, .bargain-box, .tiles";

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
    for (sel, off) in [(".scroll-cue.up", y <= 8.0), (".scroll-cue.down", y >= max - 8.0)] {
        if let Ok(Some(b)) = document().query_selector(sel) {
            let _ = b.class_list().toggle_with_force("off", off);
        }
    }
}

/// The scroll-padding top as px — where a snapped section rests.
fn snap_pad() -> f64 {
    let Some(el) = document().document_element() else { return 0.0 };
    window()
        .get_computed_style(&el)
        .ok()
        .flatten()
        .and_then(|s| s.get_property_value("scroll-padding-top").ok())
        .and_then(|v| v.trim_end_matches("px").parse().ok())
        .unwrap_or(0.0)
}

/// Step to the next/previous snap edge — like openooda's panel nav.
/// dir > 0: first block whose top edge sits below the snap line.
/// dir < 0: last block whose top edge sits above it (or scrolled into).
fn edge_scroll(dir: f64) {
    let Ok(nodes) = document().query_selector_all(SNAP_SEL) else { return };
    let pad = snap_pad();
    let mut pick: Option<web_sys::Element> = None;
    for i in 0..nodes.length() {
        let Some(n) = nodes.item(i) else { continue };
        let el: web_sys::Element = n.unchecked_into();
        let top = el.get_bounding_client_rect().top();
        if dir > 0.0 {
            if top > pad + 8.0 {
                pick = Some(el);
                break;
            }
        } else if top < pad - 8.0 {
            pick = Some(el);
        }
    }
    if let Some(el) = pick {
        let o = web_sys::ScrollIntoViewOptions::new();
        o.set_behavior(web_sys::ScrollBehavior::Smooth);
        o.set_block(web_sys::ScrollLogicalPosition::Start);
        el.scroll_into_view_with_scroll_into_view_options(&o);
    } else {
        let o = web_sys::ScrollToOptions::new();
        o.set_top(if dir > 0.0 { f64::MAX } else { 0.0 });
        o.set_behavior(web_sys::ScrollBehavior::Smooth);
        window().scroll_to_with_scroll_to_options(&o);
    }
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
            let cb = Closure::<dyn FnMut()>::new(move || edge_scroll(dir));
            let _ = b.add_event_listener_with_callback("click", cb.as_ref().unchecked_ref());
            cb.forget();
        }
    }
}

//! smoke — dream smoke canvas controller and lifecycle.
//! High-DPI scaling, rAF scheduling, IntersectionObserver,
//! visibility throttling, prefers-reduced-motion gating.

use crate::env::{document, reduced_motion, window};
use crate::smoke_engine::{create_puffs, render_static, update_and_render, WispPuff};
use std::cell::RefCell;
use std::rc::Rc;
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;

struct Smoke {
    canvas: web_sys::HtmlCanvasElement,
    ctx: web_sys::CanvasRenderingContext2d,
    puffs: Vec<WispPuff>,
    width: f64,
    height: f64,
    reduced: bool,
    doc_visible: bool,
    intersecting: bool,
    raf_id: Option<i32>,
    time_sec: f64,
    last_time: f64,
    frame: Option<Closure<dyn FnMut(f64)>>,
}

type Shared = Rc<RefCell<Smoke>>;

fn resize(s: &Shared) {
    let mut g = s.borrow_mut();
    let rect = g.canvas.get_bounding_client_rect();
    g.width = rect.width().round().max(1.0);
    g.height = rect.height().round().max(1.0);
    let dpr = window().device_pixel_ratio().min(2.0);
    g.canvas.set_width((g.width * dpr).round() as u32);
    g.canvas.set_height((g.height * dpr).round() as u32);
    let _ = g.ctx.set_transform(dpr, 0.0, 0.0, dpr, 0.0, 0.0);
    if g.reduced {
        render_static(&g.ctx, g.width, g.height);
    }
}

fn tick(s: &Shared, now: f64) {
    let mut g = s.borrow_mut();
    if !g.intersecting || !g.doc_visible || g.reduced {
        g.raf_id = None;
        return;
    }
    if g.last_time == 0.0 {
        g.last_time = now;
    }
    let dt = ((now - g.last_time) / 1000.0).min(0.064);
    g.last_time = now;
    g.time_sec += dt;
    let g2 = &mut *g;
    if g2.width > 0.0 && g2.height > 0.0 {
        update_and_render(&g2.ctx, &mut g2.puffs, g2.width, g2.height, g2.time_sec, dt, true);
    }
    let f: js_sys::Function = g
        .frame
        .as_ref()
        .unwrap()
        .as_ref()
        .unchecked_ref::<js_sys::Function>()
        .clone();
    g.raf_id = window().request_animation_frame(&f).ok();
}

fn evaluate(s: &Shared) {
    let mut g = s.borrow_mut();
    if g.reduced {
        if let Some(id) = g.raf_id.take() {
            let _ = window().cancel_animation_frame(id);
        }
        if g.width > 0.0 && g.height > 0.0 {
            render_static(&g.ctx, g.width, g.height);
        }
    } else if g.intersecting && g.doc_visible && g.raf_id.is_none() {
        g.last_time = 0.0;
        let f: js_sys::Function = g
            .frame
            .as_ref()
            .unwrap()
            .as_ref()
            .unchecked_ref::<js_sys::Function>()
            .clone();
        g.raf_id = window().request_animation_frame(&f).ok();
    } else if let Some(id) = g.raf_id.take() {
        let _ = window().cancel_animation_frame(id);
    }
}

pub fn init() {
    let Some(el) = document().get_element_by_id("hero-smoke") else { return };
    let canvas: web_sys::HtmlCanvasElement = el.unchecked_into();
    let Some(ctx) = canvas
        .get_context("2d")
        .ok()
        .flatten()
        .and_then(|c| c.dyn_into::<web_sys::CanvasRenderingContext2d>().ok())
    else { return };

    let s: Shared = Rc::new(RefCell::new(Smoke {
        canvas,
        ctx,
        puffs: create_puffs(22),
        width: 0.0,
        height: 0.0,
        reduced: reduced_motion(),
        doc_visible: !document().hidden(),
        intersecting: true,
        raf_id: None,
        time_sec: 0.0,
        last_time: 0.0,
        frame: None,
    }));

    // Self-re-arming frame callback, owned by the state.
    {
        let mut g = s.borrow_mut();
        let h = s.clone();
        g.frame = Some(Closure::new(move |now: f64| tick(&h, now)));
    }

    resize(&s);

    let h = s.clone();
    let cb = Closure::<dyn FnMut(js_sys::Array)>::new(move |_: js_sys::Array| resize(&h));
    let ro = web_sys::ResizeObserver::new(cb.as_ref().unchecked_ref()).unwrap();
    ro.observe(&s.borrow().canvas);
    cb.forget();
    std::mem::forget(ro);

    let h = s.clone();
    let cb = Closure::<dyn FnMut(js_sys::Array, web_sys::IntersectionObserver)>::new(
        move |entries: js_sys::Array, _obs| {
            let mut g = h.borrow_mut();
            for e in entries.iter() {
                let e: web_sys::IntersectionObserverEntry = e.unchecked_into();
                g.intersecting = e.is_intersecting();
            }
            drop(g);
            evaluate(&h);
        },
    );
    let opts = web_sys::IntersectionObserverInit::new();
    opts.set_threshold(&JsValue::from(0.01));
    let io = web_sys::IntersectionObserver::new_with_options(
        cb.as_ref().unchecked_ref(),
        &opts,
    )
    .unwrap();
    io.observe(&s.borrow().canvas);
    cb.forget();
    std::mem::forget(io);

    let h = s.clone();
    let cb = Closure::<dyn FnMut()>::new(move || {
        h.borrow_mut().doc_visible = !document().hidden();
        evaluate(&h);
    });
    let _ = document()
        .add_event_listener_with_callback("visibilitychange", cb.as_ref().unchecked_ref());
    cb.forget();

    let h = s.clone();
    let cb = Closure::<dyn FnMut(web_sys::MediaQueryListEvent)>::new(move |e: web_sys::MediaQueryListEvent| {
        h.borrow_mut().reduced = e.matches();
        evaluate(&h);
    });
    if let Ok(Some(mq)) = window().match_media("(prefers-reduced-motion: reduce)") {
        let _ = mq.add_event_listener_with_callback("change", cb.as_ref().unchecked_ref());
    }
    cb.forget();

    evaluate(&s);
}

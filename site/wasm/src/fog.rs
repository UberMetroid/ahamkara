//! fog — rolling dream-fog on the #fx canvas. Replaces the old
//! bursts/rings/tears: a dozen slow Lissajous puffs at half
//! resolution, screen-blended, always drifting. Pure atmosphere —
//! no interaction, gated by prefers-reduced-motion and visibility.

use crate::env::{document, reduced_motion, window};
use crate::smoke_engine::{create_fog_puffs, update_and_render, WispPuff};
use std::cell::RefCell;
use std::rc::Rc;
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;

/// Fog is diffuse by nature — half-res backing store is free softness
/// and keeps the per-frame fill cost down.
const SCALE: f64 = 0.5;
const PUFFS: usize = 13;

struct Fog {
    canvas: web_sys::HtmlCanvasElement,
    ctx: web_sys::CanvasRenderingContext2d,
    puffs: Vec<WispPuff>,
    width: f64,
    height: f64,
    time_sec: f64,
    last_time: f64,
    running: bool,
    raf_id: Option<i32>,
    frame: Option<Closure<dyn FnMut(f64)>>,
}

type Shared = Rc<RefCell<Fog>>;

fn resize(s: &Shared) {
    let mut g = s.borrow_mut();
    let w = window();
    let iw = w.inner_width().ok().and_then(|v| v.as_f64()).unwrap_or(0.0);
    let ih = w.inner_height().ok().and_then(|v| v.as_f64()).unwrap_or(0.0);
    g.width = iw;
    g.height = ih;
    g.canvas
        .set_width((iw * SCALE).round().max(1.0) as u32);
    g.canvas
        .set_height((ih * SCALE).round().max(1.0) as u32);
    let _ = g.ctx.set_transform(SCALE, 0.0, 0.0, SCALE, 0.0, 0.0);
}

fn tick(s: &Shared, now: f64) {
    let mut g = s.borrow_mut();
    if !g.running {
        g.raf_id = None;
        return;
    }
    if g.last_time == 0.0 {
        g.last_time = now;
    }
    let dt = ((now - g.last_time) / 1000.0).min(0.064);
    g.last_time = now;
    g.time_sec += dt;
    if g.width > 0.0 && g.height > 0.0 {
        let ctx = g.ctx.clone();
        let (w, h, t) = (g.width, g.height, g.time_sec);
        update_and_render(&ctx, &mut g.puffs, w, h, t, dt, false);
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
    if g.running && g.raf_id.is_none() {
        g.last_time = 0.0;
        let f: js_sys::Function = g
            .frame
            .as_ref()
            .unwrap()
            .as_ref()
            .unchecked_ref::<js_sys::Function>()
            .clone();
        g.raf_id = window().request_animation_frame(&f).ok();
    } else if !g.running {
        if let Some(id) = g.raf_id.take() {
            let _ = window().cancel_animation_frame(id);
        }
    }
}

pub fn init() {
    if reduced_motion() {
        return;
    }
    let Some(el) = document().get_element_by_id("fx") else {
        return;
    };
    let canvas: web_sys::HtmlCanvasElement = el.unchecked_into();
    let Some(ctx) = canvas
        .get_context("2d")
        .ok()
        .flatten()
        .and_then(|c| c.dyn_into::<web_sys::CanvasRenderingContext2d>().ok())
    else {
        return;
    };

    let s: Shared = Rc::new(RefCell::new(Fog {
        canvas,
        ctx,
        puffs: create_fog_puffs(PUFFS),
        width: 0.0,
        height: 0.0,
        time_sec: 0.0,
        last_time: 0.0,
        running: !document().hidden(),
        raf_id: None,
        frame: None,
    }));

    {
        let mut g = s.borrow_mut();
        let h = s.clone();
        g.frame = Some(Closure::new(move |now: f64| tick(&h, now)));
    }

    resize(&s);
    let h = s.clone();
    let cb = Closure::<dyn FnMut()>::new(move || resize(&h));
    let _ = window().add_event_listener_with_callback("resize", cb.as_ref().unchecked_ref());
    cb.forget();

    let h = s.clone();
    let cb = Closure::<dyn FnMut()>::new(move || {
        h.borrow_mut().running = !document().hidden();
        evaluate(&h);
    });
    let _ = document()
        .add_event_listener_with_callback("visibilitychange", cb.as_ref().unchecked_ref());
    cb.forget();

    evaluate(&s);
}

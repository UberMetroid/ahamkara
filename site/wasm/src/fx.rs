//! fx — wish magic: pixel bursts, halo rings, cursor embers, reality
//! tears. All motion is gated behind prefers-reduced-motion.
//! burst()/ring() are shared hooks other modules call; no-ops until
//! init() wires the canvas.

use crate::env::{document, rand, rand_range, reduced_motion, set_timeout, window};
use std::cell::RefCell;
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;

const PALETTE: [(u8, u8, u8); 4] = [
    (143, 227, 208), // taken-teal
    (199, 125, 255), // riven-violet
    (236, 229, 211), // bone
    (255, 110, 160), // wish-pink
];

const MAXP: usize = 384;
const MAXR: usize = 10;
const MAXT: usize = 2;

pub(crate) struct Particle {
    pub(crate) x: f64, pub(crate) y: f64, pub(crate) vx: f64, pub(crate) vy: f64,
    pub(crate) life: f64, pub(crate) max: f64, pub(crate) size: f64, pub(crate) c: (u8, u8, u8),
}
pub(crate) struct Ring { pub(crate) x: f64, pub(crate) y: f64, pub(crate) r: f64, pub(crate) life: f64, pub(crate) max: f64 }
pub(crate) struct Tear { pub(crate) pts: Vec<(f64, f64)>, pub(crate) life: f64, pub(crate) max: f64 }

pub(crate) struct Fx {
    pub(crate) ctx: web_sys::CanvasRenderingContext2d,
    pub(crate) particles: Vec<Particle>,
    pub(crate) rings: Vec<Ring>,
    pub(crate) tears: Vec<Tear>,
    pub(crate) running: bool,
    pub(crate) animating: bool,
}

thread_local! {
    pub(crate) static FX: RefCell<Option<Fx>> = const { RefCell::new(None) };
}

fn pick_color() -> (u8, u8, u8) {
    PALETTE[(rand() * PALETTE.len() as f64) as usize % PALETTE.len()]
}

pub fn burst(x: f64, y: f64, n: u32) {
    FX.with(|s| {
        if let Some(f) = &mut *s.borrow_mut() {
            for _ in 0..n {
                if f.particles.len() >= MAXP {
                    f.particles.remove(0);
                }
                let a = rand() * std::f64::consts::TAU;
                let sp = 0.6 + rand() * 3.6;
                f.particles.push(Particle {
                    x, y,
                    vx: a.cos() * sp,
                    vy: a.sin() * sp - 1.3, // reality drifts upward
                    life: 0.0,
                    max: 55.0 + rand() * 65.0,
                    size: 1.5 + rand() * 4.5,
                    c: pick_color(),
                });
            }
            wake(f);
        }
    });
}

pub fn ring(x: f64, y: f64) {
    FX.with(|s| {
        if let Some(f) = &mut *s.borrow_mut() {
            if f.rings.len() >= MAXR {
                f.rings.remove(0);
            }
            f.rings.push(Ring { x, y, r: 5.0, life: 0.0, max: 50.0 + rand() * 24.0 });
            wake(f);
        }
    });
}

fn wake(f: &mut Fx) {
    if !f.animating && f.running {
        f.animating = true;
        let _ = window().request_animation_frame(crate::fx_frame::frame_fn());
    }
}

fn spontaneous() {
    if !document().hidden() {
        let w = window();
        let ww = w.inner_width().ok().and_then(|v| v.as_f64()).unwrap_or(0.0);
        let wh = w.inner_height().ok().and_then(|v| v.as_f64()).unwrap_or(0.0);
        let x = ww * (0.12 + rand() * 0.76);
        let y = wh * (0.15 + rand() * 0.7);
        burst(x, y, 18 + (rand() * 14.0) as u32);
        ring(x, y);
    }
    set_timeout(9000 + rand_range(0.0, 10000.0) as i32, spontaneous);
}

fn tear() {
    FX.with(|s| {
        if let Some(f) = &mut *s.borrow_mut() {
            if !document().hidden() && f.tears.len() < MAXT {
                let w = window();
                let ww = w.inner_width().ok().and_then(|v| v.as_f64()).unwrap_or(0.0);
                let wh = w.inner_height().ok().and_then(|v| v.as_f64()).unwrap_or(0.0);
                let mut x = ww * (0.1 + rand() * 0.8);
                let mut y = wh * (0.1 + rand() * 0.6);
                let drift = (rand() - 0.5) * 1.4;
                let n = 8 + (rand() * 10.0) as usize;
                let mut pts = Vec::with_capacity(n);
                for _ in 0..n {
                    pts.push((x, y));
                    x += (rand() - 0.5 + drift) * 60.0;
                    y += 18.0 + rand() * 34.0;
                }
                f.tears.push(Tear { pts, life: 0.0, max: 60.0 + rand() * 40.0 });
                wake(f);
            }
        }
    });
    set_timeout(15000 + rand_range(0.0, 20000.0) as i32, tear);
}

pub fn init() {
    if reduced_motion() {
        return;
    }
    let Some(canvas) = document().get_element_by_id("fx") else { return };
    let canvas: web_sys::HtmlCanvasElement = canvas.unchecked_into();
    let Some(ctx) = canvas
        .get_context("2d")
        .ok()
        .flatten()
        .and_then(|c| c.dyn_into::<web_sys::CanvasRenderingContext2d>().ok())
    else { return };

    let fit = {
        let canvas = canvas.clone();
        let ctx = ctx.clone();
        move || {
            let w = window();
            let dpr = w.device_pixel_ratio().min(2.0);
            let iw = w.inner_width().ok().and_then(|v| v.as_f64()).unwrap_or(0.0);
            let ih = w.inner_height().ok().and_then(|v| v.as_f64()).unwrap_or(0.0);
            canvas.set_width((iw * dpr) as u32);
            canvas.set_height((ih * dpr) as u32);
            let _ = ctx.set_transform(dpr, 0.0, 0.0, dpr, 0.0, 0.0);
        }
    };
    fit();
    let cb = Closure::<dyn FnMut()>::new(fit);
    let _ = window().add_event_listener_with_callback("resize", cb.as_ref().unchecked_ref());
    cb.forget();

    FX.with(|s| {
        *s.borrow_mut() = Some(Fx {
            ctx,
            particles: Vec::new(),
            rings: Vec::new(),
            tears: Vec::new(),
            running: true,
            animating: false,
        });
    });

    // The bargain responds to touch.
    let cb = Closure::<dyn FnMut(web_sys::PointerEvent)>::new(|e: web_sys::PointerEvent| {
        burst(e.client_x() as f64, e.client_y() as f64, 30);
        ring(e.client_x() as f64, e.client_y() as f64);
    });
    let _ = document()
        .add_event_listener_with_callback("pointerdown", cb.as_ref().unchecked_ref());
    cb.forget();

    // Cursor embers — the dragon's attention follows you.
    let last = std::cell::Cell::new(0.0);
    let cb = Closure::<dyn FnMut(web_sys::PointerEvent)>::new(move |e: web_sys::PointerEvent| {
        let t = window().performance().map(|p| p.now()).unwrap_or(0.0);
        let full = FX.with(|s| s.borrow().as_ref().map(|f| f.particles.len() >= MAXP).unwrap_or(true));
        if t - last.get() < 55.0 || full {
            return;
        }
        last.set(t);
        FX.with(|s| {
            if let Some(f) = &mut *s.borrow_mut() {
                f.particles.push(Particle {
                    x: e.client_x() as f64, y: e.client_y() as f64,
                    vx: (rand() - 0.5) * 0.4,
                    vy: -0.3 - rand() * 0.4,
                    life: 0.0, max: 34.0 + rand() * 20.0,
                    size: 1.2 + rand() * 1.8,
                    c: pick_color(),
                });
                wake(f);
            }
        });
    });
    let _ = document()
        .add_event_listener_with_callback("pointermove", cb.as_ref().unchecked_ref());
    cb.forget();

    set_timeout(6000, spontaneous);
    set_timeout(10000, tear);

    // Park the loop while the tab is hidden; wake on return.
    let cb = Closure::<dyn FnMut()>::new(|| {
        let hidden = document().hidden();
        FX.with(|s| {
            if let Some(f) = &mut *s.borrow_mut() {
                f.running = !hidden;
                if f.running
                    && (!f.particles.is_empty() || !f.rings.is_empty() || !f.tears.is_empty())
                {
                    wake(f);
                }
            }
        });
    });
    let _ = document()
        .add_event_listener_with_callback("visibilitychange", cb.as_ref().unchecked_ref());
    cb.forget();
}


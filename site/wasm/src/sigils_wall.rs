//! sigils_wall — lifecycle and input for the Wall of Wishes:
//! canvas fitting, pointer/keyboard triggers, the stir timer, rAF loop.

use crate::env::{document, rand, reduced_motion, set_timeout, window};
use crate::sigils::{accent_probe, draw_plate, trigger, Wall, CELLS};
use std::cell::RefCell;
use std::rc::Rc;
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;

pub fn init() {
    let Some(canvas) = document().query_selector("canvas.wish-wall").ok().flatten() else {
        return;
    };
    let canvas: web_sys::HtmlCanvasElement = canvas.unchecked_into();
    let Some(ctx) = canvas
        .get_context("2d")
        .ok()
        .flatten()
        .and_then(|c| c.dyn_into::<web_sys::CanvasRenderingContext2d>().ok())
    else { return };

    accent_probe();
    let w: Rc<RefCell<Wall>> = Rc::new(RefCell::new(Wall {
        canvas: canvas.clone(),
        ctx,
        flare: [0.0; CELLS],
        w: 0.0,
        h: 0.0,
        focus: 0,
    }));

    let fit = {
        let w = w.clone();
        move || {
            let mut g = w.borrow_mut();
            let dpr = window().device_pixel_ratio().min(2.0);
            let r = g.canvas.get_bounding_client_rect();
            g.w = r.width();
            g.h = r.height();
            g.canvas.set_width((g.w * dpr).max(1.0) as u32);
            g.canvas.set_height((g.h * dpr).max(1.0) as u32);
            let _ = g.ctx.set_transform(dpr, 0.0, 0.0, dpr, 0.0, 0.0);
        }
    };
    fit();
    let cb = Closure::<dyn FnMut()>::new(fit);
    let _ = window().add_event_listener_with_callback("resize", cb.as_ref().unchecked_ref());
    cb.forget();

    let h = w.clone();
    let cb = Closure::<dyn FnMut(web_sys::PointerEvent)>::new(move |e: web_sys::PointerEvent| {
        e.stop_propagation();
        let mut g = h.borrow_mut();
        let r = g.canvas.get_bounding_client_rect();
        let i = (((e.client_y() as f64 - r.top()) / (r.height() / 4.0)) as i32) * 4
            + ((e.client_x() as f64 - r.left()) / (r.width() / 4.0)) as i32;
        if i >= 0 && (i as usize) < CELLS {
            trigger(&mut g, i as usize, e.client_x() as f64, e.client_y() as f64);
        }
    });
    let _ = canvas.add_event_listener_with_callback("pointerdown", cb.as_ref().unchecked_ref());
    cb.forget();

    let h = w.clone();
    let cb = Closure::<dyn FnMut(web_sys::KeyboardEvent)>::new(move |e: web_sys::KeyboardEvent| {
        let mut g = h.borrow_mut();
        match e.key().as_str() {
            "Enter" | " " => {
                e.prevent_default();
                let r = g.canvas.get_bounding_client_rect();
                let (cw, ch) = (r.width() / 4.0, r.height() / 4.0);
                let fi = g.focus;
                let (col, row) = (fi % 4, fi / 4);
                trigger(
                    &mut g,
                    fi,
                    r.left() + col as f64 * cw + cw / 2.0,
                    r.top() + row as f64 * ch + ch / 2.0,
                );
                g.focus = (fi + 1) % CELLS;
            }
            "ArrowRight" => {
                e.prevent_default();
                g.focus = (g.focus + 1) % CELLS;
            }
            "ArrowLeft" => {
                e.prevent_default();
                g.focus = (g.focus + CELLS - 1) % CELLS;
            }
            "ArrowDown" => {
                e.prevent_default();
                g.focus = (g.focus + 4) % CELLS;
            }
            "ArrowUp" => {
                e.prevent_default();
                g.focus = (g.focus + CELLS - 4) % CELLS;
            }
            _ => {}
        }
    });
    let _ = canvas.add_event_listener_with_callback("keydown", cb.as_ref().unchecked_ref());
    cb.forget();

    let draw = {
        let w = w.clone();
        move |t: f64| {
            let g = w.borrow();
            g.ctx.clear_rect(0.0, 0.0, g.w, g.h);
            let (cw, ch) = (g.w / 4.0, g.h / 4.0);
            for i in 0..CELLS {
                draw_plate(&g, i, cw, ch, t);
            }
        }
    };

    if reduced_motion() {
        draw(0.0);
        return;
    }

    // A plate stirs every few seconds.
    fn stir(w: Rc<RefCell<Wall>>) {
        if !document().hidden() {
            let now = window().performance().map(|p| p.now()).unwrap_or(0.0) / 1000.0;
            w.borrow_mut().flare[(rand() * CELLS as f64) as usize % CELLS] = now + 2.2;
        }
        let h = w.clone();
        set_timeout(2600 + (rand() * 3800.0) as i32, move || stir(h));
    }
    stir(w.clone());

    crate::env::raf_loop(move |now| draw(now / 1000.0));
}

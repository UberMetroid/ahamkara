//! sigils — the Wall of Wishes, drawn live.
//! A 4x4 grid of procedurally generated wish plates on
//! `canvas.wish-wall`; plates flare on a timer and detonate on click.
//! Each sigil is seeded per cell — the wall never rearranges.

use crate::env::{document, set_interval, window};
use crate::fx;
use std::cell::RefCell;
use std::f64::consts::{PI, TAU};
use wasm_bindgen::JsCast;

pub(crate) const CELLS: usize = 16;

/// Deterministic per-cell RNG so the wall is stable between frames.
fn seeded(seed: u32) -> impl FnMut() -> f64 {
    let mut s = if seed == 0 { 1 } else { seed };
    move || {
        s ^= s << 13;
        s ^= s >> 17;
        s ^= s << 5;
        s as f64 / 4294967296.0
    }
}

type Prim = fn(&web_sys::CanvasRenderingContext2d, f64, &mut dyn FnMut() -> f64);

const PRIMS: [Prim; 8] = [
    |c, u, _| {
        c.begin_path();
        let _ = c.arc(0.0, 0.0, 8.0 * u, 0.0, TAU);
        c.stroke();
    },
    |c, u, _| {
        c.begin_path();
        let _ = c.arc(0.0, 0.0, 2.4 * u, 0.0, TAU);
        c.fill();
    },
    |c, u, _| {
        c.begin_path();
        c.move_to(-9.0 * u, 9.0 * u);
        c.line_to(0.0, -9.0 * u);
        c.line_to(9.0 * u, 9.0 * u);
        c.stroke();
    },
    |c, u, r| {
        let a = r() * PI;
        c.begin_path();
        let _ = c.arc(0.0, 0.0, 9.0 * u, a, a + PI);
        c.stroke();
    },
    |c, u, _| {
        c.begin_path();
        c.move_to(-9.0 * u, 0.0);
        c.line_to(9.0 * u, 0.0);
        c.move_to(0.0, -9.0 * u);
        c.line_to(0.0, 9.0 * u);
        c.stroke();
    },
    |c, u, _| {
        c.begin_path();
        c.move_to(-8.0 * u, -4.0 * u);
        c.quadratic_curve_to(0.0, 6.0 * u, 8.0 * u, -4.0 * u);
        c.move_to(0.0, -8.0 * u);
        c.line_to(0.0, 4.0 * u);
        c.stroke();
    },
    |c, u, _| {
        c.begin_path();
        c.move_to(-9.0 * u, 0.0);
        c.quadratic_curve_to(0.0, -11.0 * u, 9.0 * u, 0.0);
        c.quadratic_curve_to(0.0, 11.0 * u, -9.0 * u, 0.0);
        c.stroke();
    },
    |c, u, _| {
        for i in 0..3 {
            c.begin_path();
            let _ = c.arc((i as f64 - 1.0) * 7.0 * u, 0.0, 2.0 * u, 0.0, TAU);
            c.stroke();
        }
    },
];

thread_local! {
    static ACCENTS: RefCell<[String; 2]> = RefCell::new([
        "rgb(143,227,208)".into(),
        "rgb(199,125,255)".into(),
    ]);
}

/// Read the live accent palette (it hue-drifts) via a probe element.
pub(crate) fn accent_probe() {
    let Ok(probe) = document().create_element("span") else { return };
    probe.set_attribute(
        "style",
        "position:absolute;visibility:hidden;pointer-events:none",
    )
    .ok();
    let _ = document().body().unwrap().append_child(&probe);
    let sample = move || {
        let mut a: Vec<String> = Vec::new();
        for v in ["--accent", "--accent-2"] {
            let he: web_sys::HtmlElement = probe.clone().unchecked_into();
            let _ = he.style().set_property("color", &format!("var({v})"));
            if let Ok(cs) = window().get_computed_style(&he) {
                if let Some(cs) = cs {
                    if let Ok(c) = cs.get_property_value("color") {
                        if !c.is_empty() {
                            a.push(c);
                        }
                    }
                }
            }
        }
        if a.len() == 2 {
            ACCENTS.with(|ac| *ac.borrow_mut() = [a[0].clone(), a[1].clone()]);
        }
    };
    sample();
    set_interval(2500, sample);
}

pub(crate) struct Wall {
    pub(crate) canvas: web_sys::HtmlCanvasElement,
    pub(crate) ctx: web_sys::CanvasRenderingContext2d,
    pub(crate) flare: [f64; CELLS],
    pub(crate) w: f64,
    pub(crate) h: f64,
    pub(crate) focus: usize,
}

pub(crate) fn draw_plate(w: &Wall, i: usize, cw: f64, ch: f64, t: f64) {
    let ctx = &w.ctx;
    let (col, row) = (i % 4, i / 4);
    let (cx, cy) = (col as f64 * cw + cw / 2.0, row as f64 * ch + ch / 2.0);
    let mut rnd = seeded(0x9e3779u32.wrapping_add(i as u32 * 7919));
    let u = cw.min(ch) / 34.0;
    let f = (w.flare[i] - t).max(0.0);
    let ac = ACCENTS.with(|a| a.borrow().clone());

    ctx.save();
    let _ = ctx.translate(cx, cy);
    ctx.set_global_alpha(0.16 + f * 0.7);
    ctx.set_stroke_style_str(&ac[0]);
    ctx.set_line_width(u * (0.9 + f * 0.6));
    ctx.stroke_rect(-cw / 2.0 + 2.0 * u, -ch / 2.0 + 2.0 * u, cw - 4.0 * u, ch - 4.0 * u);

    ctx.set_global_alpha(0.5 + f * 0.5);
    ctx.set_stroke_style_str(if f > 0.35 { &ac[1] } else { &ac[0] });
    ctx.set_fill_style_str(&ac[1]);
    ctx.set_line_width(u * (1.0 + f));
    for _ in 0..3 {
        ctx.save();
        let _ = ctx.rotate(rnd() * TAU);
        let _ = ctx.scale(0.5 + rnd() * 0.5, 0.5 + rnd() * 0.5);
        PRIMS[(rnd() * PRIMS.len() as f64) as usize % PRIMS.len()](ctx, u, &mut rnd);
        ctx.restore();
    }
    ctx.restore();
}

pub(crate) fn trigger(w: &mut Wall, i: usize, cx: f64, cy: f64) {
    let now = window().performance().map(|p| p.now()).unwrap_or(0.0) / 1000.0;
    w.flare[i] = now + 1.6;
    fx::burst(cx, cy, 24);
    fx::ring(cx, cy);
}

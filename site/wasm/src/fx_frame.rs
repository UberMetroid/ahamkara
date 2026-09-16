//! fx_frame — the rAF renderer for the fx canvas: particles, halo
//! rings, reality tears. Owns the self-re-arming frame callback.

use crate::env::window;
use crate::fx::FX;
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;

// The frame callback, kept alive for the page's lifetime.
pub(crate) fn frame_fn() -> &'static js_sys::Function {
    use std::sync::OnceLock;
    static F: OnceLock<js_sys::Function> = OnceLock::new();
    F.get_or_init(|| {
        Closure::<dyn FnMut(f64)>::new(|_: f64| frame())
            .into_js_value()
            .unchecked_into()
    })
}

fn frame() {
    FX.with(|s| {
        let mut guard = s.borrow_mut();
        let Some(f) = &mut *guard else { return };
        if !f.running {
            f.animating = false;
            return;
        }
        let w = window();
        let ww = w.inner_width().ok().and_then(|v| v.as_f64()).unwrap_or(0.0);
        let wh = w.inner_height().ok().and_then(|v| v.as_f64()).unwrap_or(0.0);
        let ctx = f.ctx.clone();

        if f.particles.is_empty() && f.rings.is_empty() && f.tears.is_empty() {
            ctx.clear_rect(0.0, 0.0, ww, wh);
            f.animating = false;
            return;
        }
        ctx.clear_rect(0.0, 0.0, ww, wh);

        f.particles.retain_mut(|p| {
            p.life += 1.0;
            p.x += p.vx;
            p.y += p.vy;
            p.vx *= 0.985;
            p.vy = p.vy * 0.985 - 0.012; // anti-gravity: wishes rise
            let t = 1.0 - p.life / p.max;
            if t <= 0.0 { return false; }
            ctx.set_global_alpha((t * 1.5).min(1.0));
            ctx.set_fill_style_str(&format!("rgb({},{},{})", p.c.0, p.c.1, p.c.2));
            ctx.fill_rect(p.x - p.size / 2.0, p.y - p.size / 2.0, p.size, p.size);
            true
        });

        f.rings.retain_mut(|r| {
            r.life += 1.0;
            r.r += 2.6 + r.life * 0.05;
            let t = 1.0 - r.life / r.max;
            if t <= 0.0 { return false; }
            ctx.set_global_alpha(t * 0.65);
            ctx.set_line_width(2.0);
            ctx.set_stroke_style_str("rgb(143,227,208)");
            ctx.begin_path();
            let _ = ctx.arc(r.x, r.y, r.r, 0.0, std::f64::consts::TAU);
            ctx.stroke();
            ctx.set_global_alpha(t * 0.5);
            ctx.set_line_width(1.0);
            ctx.set_stroke_style_str("rgb(199,125,255)");
            ctx.begin_path();
            let _ = ctx.arc(r.x, r.y, r.r * 0.8, 0.0, std::f64::consts::TAU);
            ctx.stroke();
            true
        });

        f.tears.retain_mut(|tr| {
            tr.life += 1.0;
            let t = 1.0 - tr.life / tr.max;
            if t <= 0.0 { return false; }
            let shown = (tr.pts.len() as f64 * (tr.life / 12.0).min(1.0)) as usize;
            ctx.set_global_alpha((t * 2.0).min(0.85));
            ctx.set_line_width(1.4);
            ctx.set_stroke_style_str("rgb(236,229,211)");
            ctx.begin_path();
            ctx.move_to(tr.pts[0].0, tr.pts[0].1);
            for pt in tr.pts.iter().take(shown).skip(1) {
                ctx.line_to(pt.0, pt.1);
            }
            ctx.stroke();
            ctx.set_global_alpha(t * 0.3);
            ctx.set_line_width(4.0);
            ctx.set_stroke_style_str("rgb(199,125,255)");
            ctx.stroke();
            true
        });

        ctx.set_global_alpha(1.0);
        let _ = w.request_animation_frame(frame_fn());
    });
}

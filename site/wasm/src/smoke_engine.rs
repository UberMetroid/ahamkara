//! smoke_engine — mathematical model and rendering engine for dream
//! smoke. Multi-frequency Lissajous harmonic drift with non-linear
//! radial gradient puffs.

use crate::env::{rand, rand_range};
use std::f64::consts::TAU;
use web_sys::CanvasRenderingContext2d;

pub struct WispPuff {
    base_x: f64,
    base_y: f64,
    radius_base: f64,
    vx: f64,
    vy: f64,
    amp_x: f64,
    amp_y: f64,
    freq_x: f64,
    freq_y: f64,
    phase_x: f64,
    phase_y: f64,
    amp_r: f64,
    freq_r: f64,
    phase_r: f64,
    r: u8,
    g: u8,
    b: u8,
    alpha: f64,
}

struct PaletteColor {
    r: u8,
    g: u8,
    b: u8,
    min_a: f64,
    max_a: f64,
}

const PALETTE: [PaletteColor; 4] = [
    PaletteColor { r: 199, g: 125, b: 255, min_a: 0.045, max_a: 0.085 }, // amethyst
    PaletteColor { r: 157, g: 78, b: 221, min_a: 0.050, max_a: 0.090 },  // deep amethyst
    PaletteColor { r: 143, g: 227, b: 208, min_a: 0.035, max_a: 0.070 }, // taken-mist
    PaletteColor { r: 236, g: 229, b: 211, min_a: 0.015, max_a: 0.030 }, // bone
];

pub fn create_puffs(count: usize) -> Vec<WispPuff> {
    let mut puffs = Vec::with_capacity(count);
    for _ in 0..count {
        let roll = rand();
        let c = if roll < 0.38 {
            &PALETTE[0]
        } else if roll < 0.68 {
            &PALETTE[1]
        } else if roll < 0.90 {
            &PALETTE[2]
        } else {
            &PALETTE[3]
        };
        puffs.push(WispPuff {
            base_x: rand(),
            base_y: rand(),
            radius_base: rand_range(160.0, 290.0),
            vx: rand_range(-0.005, 0.005),
            vy: rand_range(0.009, 0.022),
            amp_x: rand_range(0.04, 0.12),
            amp_y: rand_range(0.03, 0.09),
            freq_x: rand_range(0.14, 0.38),
            freq_y: rand_range(0.18, 0.44),
            phase_x: rand() * TAU,
            phase_y: rand() * TAU,
            amp_r: rand_range(0.08, 0.18),
            freq_r: rand_range(0.20, 0.50),
            phase_r: rand() * TAU,
            r: c.r,
            g: c.g,
            b: c.b,
            alpha: rand_range(c.min_a, c.max_a),
        });
    }
    puffs
}

pub fn update_and_render(
    ctx: &CanvasRenderingContext2d,
    puffs: &mut [WispPuff],
    width: f64,
    height: f64,
    time_sec: f64,
    dt: f64,
) {
    ctx.set_fill_style_str("#07060b");
    ctx.fill_rect(0.0, 0.0, width, height);
    ctx.set_global_composite_operation("screen").ok();

    let scale_ref = width.min(height) / 800.0;
    let edge_x = width * 0.15;
    let edge_y = height * 0.15;

    for p in puffs.iter_mut() {
        p.base_y -= p.vy * dt;
        p.base_x += p.vx * dt;
        if p.base_y < -0.25 {
            p.base_y += 1.5;
        } else if p.base_y > 1.25 {
            p.base_y -= 1.5;
        }
        if p.base_x < -0.25 {
            p.base_x += 1.5;
        } else if p.base_x > 1.25 {
            p.base_x -= 1.5;
        }

        let ox = p.amp_x * (p.freq_x * time_sec + p.phase_x).sin();
        let oy = p.amp_y * (p.freq_y * time_sec + p.phase_y).cos();
        let px = (p.base_x + ox) * width;
        let py = (p.base_y + oy) * height;

        let pulse = 1.0 + p.amp_r * (p.freq_r * time_sec + p.phase_r).sin();
        let rad = (p.radius_base * scale_ref.max(0.65) * pulse).max(50.0);

        let fade_x = (px / edge_x).min(1.0).max(0.0).min(((width - px) / edge_x).max(0.0));
        let fade_y = (py / edge_y).min(1.0).max(0.0).min(((height - py) / edge_y).max(0.0));
        let edge_fade = fade_x * fade_y;
        if edge_fade <= 0.002 {
            continue;
        }

        let a = p.alpha * edge_fade;
        let Ok(grad) = ctx.create_radial_gradient(px, py, 0.0, px, py, rad) else {
            continue;
        };
        let c = format!("{},{},{}", p.r, p.g, p.b);
        grad.add_color_stop(0.0, &format!("rgba({c},{a:.4})")).ok();
        grad.add_color_stop(0.45, &format!("rgba({c},{:.4})", a * 0.55)).ok();
        grad.add_color_stop(0.75, &format!("rgba({c},{:.4})", a * 0.18)).ok();
        grad.add_color_stop(1.0, &format!("rgba({c},0)")).ok();

        ctx.set_fill_style_canvas_gradient(&grad);
        ctx.begin_path();
        let _ = ctx.arc(px, py, rad, 0.0, TAU);
        ctx.fill();
    }
    ctx.set_global_composite_operation("source-over").ok();
}

/// Static dream-smoke still for prefers-reduced-motion.
pub fn render_static(ctx: &CanvasRenderingContext2d, width: f64, height: f64) {
    ctx.set_fill_style_str("#07060b");
    ctx.fill_rect(0.0, 0.0, width, height);
    ctx.set_global_composite_operation("screen").ok();

    let diag = width.max(height);
    let spots: [(f64, f64, f64, &str, &str); 3] = [
        (0.48, 0.42, 0.48, "rgba(199,125,255,0.085)", "rgba(157,78,221,0.035)"),
        (0.68, 0.60, 0.42, "rgba(143,227,208,0.065)", "rgba(143,227,208,0.020)"),
        (0.32, 0.55, 0.35, "rgba(236,229,211,0.025)", "rgba(236,229,211,0.006)"),
    ];
    for (fx, fy, fr, c0, c1) in spots {
        let cx = width * fx;
        let cy = height * fy;
        if let Ok(g) = ctx.create_radial_gradient(cx, cy, 0.0, cx, cy, diag * fr) {
            g.add_color_stop(0.0, c0).ok();
            g.add_color_stop(0.5, c1).ok();
            g.add_color_stop(1.0, "rgba(7,6,11,0)").ok();
            ctx.set_fill_style_canvas_gradient(&g);
            ctx.fill_rect(0.0, 0.0, width, height);
        }
    }
    ctx.set_global_composite_operation("source-over").ok();
}

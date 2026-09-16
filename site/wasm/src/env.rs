//! env — shared environment: whisper pool, motion gating, utilities.
//! The pool parses by hand — it arrives as `[{"q":"…","s":"…"}]` from
//! our own sitegen, and serde_json is not worth its weight here.

use wasm_bindgen::prelude::*;

#[derive(Clone)]
pub struct Whisper {
    pub q: String,
    pub s: String,
}

pub fn window() -> web_sys::Window {
    web_sys::window().unwrap()
}

pub fn document() -> web_sys::Document {
    window().document().unwrap()
}

/// Minimal parser for `[{"q":"…","s":"…"}, …]` — JSON strings with
/// escapes. Unknown keys are skipped; malformed input yields [].
fn parse_pool(text: &str) -> Vec<Whisper> {
    fn string(b: &[u8], i: &mut usize) -> Option<String> {
        if b.get(*i) != Some(&b'"') {
            return None;
        }
        *i += 1;
        let mut s = String::new();
        loop {
            match *b.get(*i)? {
                b'"' => {
                    *i += 1;
                    return Some(s);
                }
                b'\\' => {
                    *i += 1;
                    let e = *b.get(*i)?;
                    *i += 1;
                    s.push(match e {
                        b'n' => '\n',
                        b't' => '\t',
                        b'r' => '\r',
                        b'u' => {
                            let hex = std::str::from_utf8(b.get(*i..*i + 4)?).ok()?;
                            let cp = u32::from_str_radix(hex, 16).ok()?;
                            *i += 4;
                            char::from_u32(cp)?
                        }
                        c => c as char,
                    });
                }
                _ => {
                    // copy one UTF-8 encoded char
                    let rest = &b[*i..];
                    let s2 = std::str::from_utf8(rest).ok()?;
                    let c = s2.chars().next()?;
                    s.push(c);
                    *i += c.len_utf8();
                }
            }
        }
    }
    fn ws(b: &[u8], i: &mut usize) {
        while matches!(b.get(*i), Some(b' ' | b'\t' | b'\n' | b'\r')) {
            *i += 1;
        }
    }
    let b = text.as_bytes();
    let mut i = 0;
    let mut out = Vec::new();
    ws(b, &mut i);
    if b.get(i) != Some(&b'[') {
        return out;
    }
    i += 1;
    loop {
        ws(b, &mut i);
        match b.get(i) {
            None | Some(b']') => break,
            Some(b'{') => {
                i += 1;
                let (mut q, mut s) = (String::new(), String::new());
                loop {
                    ws(b, &mut i);
                    match b.get(i) {
                        Some(b'}') => {
                            i += 1;
                            break;
                        }
                        Some(b'"') => {
                            let k = string(b, &mut i).unwrap_or_default();
                            ws(b, &mut i);
                            if b.get(i) == Some(&b':') {
                                i += 1;
                            }
                            ws(b, &mut i);
                            let v = string(b, &mut i).unwrap_or_default();
                            match k.as_str() {
                                "q" => q = v,
                                "s" => s = v,
                                _ => {}
                            }
                        }
                        _ => {
                            i += 1;
                        }
                    }
                    ws(b, &mut i);
                    if b.get(i) == Some(&b',') {
                        i += 1;
                    }
                }
                out.push(Whisper { q, s });
            }
            _ => {
                i += 1;
            }
        }
        ws(b, &mut i);
        if b.get(i) == Some(&b',') {
            i += 1;
        }
    }
    out
}

pub fn whispers() -> Vec<Whisper> {
    let Some(el) = document().get_element_by_id("whisper-data") else {
        return Vec::new();
    };
    let Some(text) = el.text_content() else {
        return Vec::new();
    };
    parse_pool(&text)
}

pub fn reduced_motion() -> bool {
    window()
        .match_media("(prefers-reduced-motion: reduce)")
        .ok()
        .flatten()
        .map(|m| m.matches())
        .unwrap_or(false)
}

pub fn rand() -> f64 {
    js_sys::Math::random()
}

pub fn rand_range(min: f64, max: f64) -> f64 {
    min + rand() * (max - min)
}

pub fn pick_idx(len: usize) -> usize {
    (rand() * len as f64) as usize % len
}

/// setTimeout backed by a leaked closure — fires once, so the
/// callback may consume its captures (FnOnce, not FnMut).
pub fn set_timeout<F: FnOnce() + 'static>(ms: i32, f: F) {
    let f = std::cell::RefCell::new(Some(f));
    let cb = Closure::<dyn FnMut()>::new(move || {
        if let Some(f) = f.borrow_mut().take() {
            f();
        }
    });
    let _ = window()
        .set_timeout_with_callback_and_timeout_and_arguments_0(
            cb.as_ref().unchecked_ref(),
            ms,
        );
    cb.forget();
}

/// setInterval backed by a leaked closure.
pub fn set_interval<F: FnMut() + 'static>(ms: i32, f: F) {
    let cb = Closure::new(f);
    let _ = window()
        .set_interval_with_callback_and_timeout_and_arguments_0(
            cb.as_ref().unchecked_ref(),
            ms,
        );
    cb.forget();
}

/// rAF loop: `f(now_ms)` each frame while `keep()` is true.
/// Re-arms itself; the closure owns itself via the Rc cycle.
pub fn raf_loop<F: FnMut(f64) + 'static>(mut f: F) {
    use std::cell::RefCell;
    use std::rc::Rc;
    let hold: Rc<RefCell<Option<Closure<dyn FnMut(f64)>>>> = Rc::new(RefCell::new(None));
    let g = hold.clone();
    *g.borrow_mut() = Some(Closure::new(move |ts: f64| {
        f(ts);
        let _ = window().request_animation_frame(
            hold.borrow().as_ref().unwrap().as_ref().unchecked_ref(),
        );
    }));
    let _ = window()
        .request_animation_frame(g.borrow().as_ref().unwrap().as_ref().unchecked_ref());
    // hold/g cycle keeps the closure alive forever.
}

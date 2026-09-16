//! whispers — ambient whisper spawner (bounded pool, fades in/out)
//! and the featured-quote cycler on the index.

use crate::env::{document, pick_idx, rand, reduced_motion, set_timeout, whispers, Whisper};

use std::cell::{Cell, RefCell};
use std::rc::Rc;
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;

pub fn init_whispers() {
    if reduced_motion() {
        return;
    }
    let pool = whispers();
    if pool.is_empty() {
        return;
    }
    let active = Rc::new(Cell::new(0u32));
    let pool = Rc::new(pool);

    fn spawn(pool: &Rc<Vec<Whisper>>, active: &Rc<Cell<u32>>) {
        if document().hidden() || active.get() >= 3 {
            return;
        }
        let w = &pool[pick_idx(pool.len())];
        let Ok(el) = document().create_element("div") else { return };
        el.set_attribute("class", "whisper-bit").ok();
        el.set_attribute("aria-hidden", "true").ok();
        el.set_text_content(Some(&format!("\u{201C}{}\u{201D}", w.q)));
        let he: web_sys::HtmlElement = el.clone().unchecked_into();
        let _ = he.style().set_property("left", &format!("{}%", 8.0 + rand() * 62.0));
        let _ = he.style().set_property("top", &format!("{}%", 15.0 + rand() * 60.0));
        let _ = document().body().unwrap().append_child(&el);
        active.set(active.get() + 1);

        // Next frame: fade the whisper in.
        let el2 = el.clone();
        let cb = Closure::<dyn FnMut(f64)>::new(move |_| {
            let _ = el2.class_list().add_1("show");
        });
        let _ = crate::env::window().request_animation_frame(cb.as_ref().unchecked_ref());
        cb.forget();

        let h = active.clone();
        set_timeout(5000 + (rand() * 4000.0) as i32, move || {
            let _ = el.class_list().remove_1("show");
            set_timeout(2600, move || {
                el.remove();
                h.set(h.get() - 1);
            });
        });
    }

    fn schedule(pool: Rc<Vec<Whisper>>, active: Rc<Cell<u32>>) {
        spawn(&pool, &active);
        set_timeout(9000 + (rand() * 6000.0) as i32, move || schedule(pool, active));
    }
    set_timeout(2500, move || schedule(pool, active));
}

/* Featured quote cycler (index). */

struct Featured {
    p: web_sys::Element,
    s: web_sys::Element,
    cap: web_sys::HtmlElement,
    pool: Vec<Whisper>,
    i: usize,
}

type Feat = Rc<RefCell<Featured>>;

fn erase(f: &Feat, text: String, done: Rc<dyn Fn()>) {
    let chars: Vec<char> = text.chars().collect();
    let n = Rc::new(Cell::new(chars.len()));
    let g = f.clone();
    fn step(g: Feat, chars: Rc<Vec<char>>, n: Rc<Cell<usize>>, done: Rc<dyn Fn()>) {
        let k = n.get().saturating_sub(1);
        n.set(k);
        let s: String = chars.iter().take(k).collect();
        g.borrow().p.set_text_content(Some(&s));
        if k == 0 {
            done();
        } else {
            set_timeout(16, move || step(g, chars, n, done));
        }
    }
    step(g, Rc::new(chars), n, done);
}

fn type_quote(f: &Feat, w: Whisper, done: Rc<dyn Fn()>) {
    let chars: Rc<Vec<char>> = Rc::new(format!("\u{201C}{}\u{201D}", w.q).chars().collect());
    let n = Rc::new(Cell::new(0usize));
    let g = f.clone();
    fn step(g: Feat, chars: Rc<Vec<char>>, n: Rc<Cell<usize>>, w: Whisper, done: Rc<dyn Fn()>) {
        let k = n.get() + 1;
        n.set(k);
        let s: String = chars.iter().take(k).collect();
        g.borrow().p.set_text_content(Some(&s));
        if k >= chars.len() {
            g.borrow().s.set_text_content(Some(&w.s));
            let _ = g.borrow().cap.style().set_property("opacity", "1");
            done();
        } else {
            set_timeout(38, move || step(g, chars, n, w, done));
        }
    }
    step(g, chars, n, w, done);
}

pub fn init_featured() {
    let Some(q) = document().get_element_by_id("featured-quote") else { return };
    let Some(s) = document().get_element_by_id("featured-speaker") else { return };
    let Some(p) = q.query_selector("p").ok().flatten() else { return };
    let Some(cap) = s.parent_element() else { return };
    let cap: web_sys::HtmlElement = cap.unchecked_into();
    if reduced_motion() {
        return;
    }
    let pool = whispers();
    if pool.len() < 2 {
        return;
    }

    const HOLD: i32 = 3400;
    let i = pool
        .iter()
        .position(|w| p.text_content().unwrap_or_default().contains(&w.q))
        .unwrap_or(0);
    let f: Feat = Rc::new(RefCell::new(Featured { p, s, cap, pool, i }));

    fn cycle(f: Feat) {
        let w = {
            let mut g = f.borrow_mut();
            g.i = (g.i + 1) % g.pool.len();
            g.pool[g.i].clone()
        };
        let text = format!("\u{201C}{}\u{201D}", w.q);
        let h = f.clone();
        type_quote(&f, w, Rc::new(move || {
            let h2 = h.clone();
            let text2 = text.clone();
            set_timeout(HOLD, move || {
                let g = h2.borrow();
                let _ = g.cap.style().set_property("opacity", "0");
                drop(g);
                let h3 = h2.clone();
                erase(&h2, text2, Rc::new(move || {
                    let h4 = h3.clone();
                    set_timeout(700, move || cycle(h4));
                }));
            });
        }));
    }

    set_timeout(HOLD, move || {
        let g = f.borrow();
        let _ = g.cap.style().set_property("opacity", "0");
        let text = g.p.text_content().unwrap_or_default();
        drop(g);
        let h = f.clone();
        erase(&f, text, Rc::new(move || cycle(h.clone())));
    });
}

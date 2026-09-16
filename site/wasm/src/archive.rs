//! archive — lore page: search, entity/era/source filters, deep links.

use crate::env::{document, window};
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;

fn get(id: &str) -> Option<web_sys::Element> {
    document().get_element_by_id(id)
}

pub fn init() {
    let Some(form) = get("filters") else { return };
    let (Some(q), Some(f_entity), Some(f_era), Some(f_kind)) = (
        get("f-q"),
        get("f-entity"),
        get("f-era"),
        get("f-kind"),
    ) else { return };
    let (Some(count), Some(clear), Some(empty)) =
        (get("f-count"), get("f-clear"), get("f-empty"))
    else { return };
    let q: web_sys::HtmlInputElement = q.unchecked_into();
    let f_entity: web_sys::HtmlSelectElement = f_entity.unchecked_into();
    let f_era: web_sys::HtmlSelectElement = f_era.unchecked_into();
    let f_kind: web_sys::HtmlSelectElement = f_kind.unchecked_into();
    let clear: web_sys::HtmlElement = clear.unchecked_into();
    let empty: web_sys::HtmlElement = empty.unchecked_into();
    let count = count;

    let entries: Vec<web_sys::Element> = document()
        .query_selector_all(".entry")
        .map(|n| {
            (0..n.length())
                .filter_map(|i| n.item(i))
                .map(|n| n.unchecked_into::<web_sys::Element>())
                .collect()
        })
        .unwrap_or_default();
    let entries = std::rc::Rc::new(entries);

    let apply = {
        let (q, f_entity, f_era, f_kind) =
            (q.clone(), f_entity.clone(), f_era.clone(), f_kind.clone());
        let (count, clear, empty) = (count.clone(), clear.clone(), empty.clone());
        let entries = entries.clone();
        move || {
            let needle = q.value().trim().to_lowercase();
            let ent = f_entity.value();
            let era = f_era.value();
            let kind = f_kind.value();
            let filtering = !(needle.is_empty() && ent.is_empty() && era.is_empty() && kind.is_empty());
            let mut shown = 0u32;
            for e in entries.iter() {
                let he: &web_sys::HtmlElement = e.unchecked_ref();
                let ds = he.dataset();
                let search = ds.get("search").unwrap_or_default();
                let ok = (needle.is_empty()
                    || search.contains(&needle)
                    || e.text_content().unwrap_or_default().to_lowercase().contains(&needle))
                    && (ent.is_empty()
                        || ds.get("entities").unwrap_or_default()
                            .split(", ")
                            .any(|x| x == ent.as_str()))
                    && (era.is_empty() || ds.get("era").as_deref() == Some(era.as_str()))
                    && (kind.is_empty()
                        || ds.get("kind").unwrap_or_default().replace('_', " ") == kind);
                he.set_hidden(!ok);
                if ok {
                    shown += 1;
                    if filtering {
                        if let Ok(d) = e.clone().dyn_into::<web_sys::HtmlDetailsElement>() {
                            d.set_open(true);
                        }
                    }
                } else if let Ok(d) = e.clone().dyn_into::<web_sys::HtmlDetailsElement>() {
                    d.set_open(false);
                }
            }
            count.set_text_content(Some(&shown.to_string()));
            empty.set_hidden(shown != 0);
            clear.set_hidden(!filtering);
        }
    };

    let cb = Closure::<dyn FnMut(web_sys::Event)>::new(|e: web_sys::Event| e.prevent_default());
    let _ = form.add_event_listener_with_callback("submit", cb.as_ref().unchecked_ref());
    cb.forget();

    let inputs: [&web_sys::EventTarget; 4] = [
        q.unchecked_ref(),
        f_entity.unchecked_ref(),
        f_era.unchecked_ref(),
        f_kind.unchecked_ref(),
    ];
    for el in inputs {
        for ev in ["input", "change"] {
            let cb = Closure::<dyn FnMut()>::new(apply.clone());
            let _ = el.add_event_listener_with_callback(ev, cb.as_ref().unchecked_ref());
            cb.forget();
        }
    }

    let h = (q.clone(), f_entity.clone(), f_era.clone(), f_kind.clone(), entries.clone());
    let apply2 = apply.clone();
    let cb = Closure::<dyn FnMut()>::new(move || {
        let (q, fe, fr, fk, entries) = &h;
        q.set_value("");
        fe.set_value("");
        fr.set_value("");
        fk.set_value("");
        for e in entries.iter() {
            if let Ok(d) = e.clone().dyn_into::<web_sys::HtmlDetailsElement>() {
                d.set_open(false);
            }
        }
        apply2();
        let _ = q.focus();
    });
    let _ = clear.add_event_listener_with_callback("click", cb.as_ref().unchecked_ref());
    cb.forget();

    // Deep links: open the <details> that matches the URL fragment.
    fn open_hash() {
        let hash = window().location().hash().unwrap_or_default();
        if hash.len() > 1 {
            if let Some(t) = document().get_element_by_id(&hash[1..]) {
                if let Ok(d) = t.clone().dyn_into::<web_sys::HtmlDetailsElement>() {
                    d.set_open(true);
                    let o = web_sys::ScrollIntoViewOptions::new();
                    o.set_block(web_sys::ScrollLogicalPosition::Start);
                    d.scroll_into_view_with_scroll_into_view_options(&o);
                }
            }
        }
    }
    open_hash();
    let cb = Closure::<dyn FnMut()>::new(open_hash);
    let _ = window().add_event_listener_with_callback("hashchange", cb.as_ref().unchecked_ref());
    cb.forget();
}

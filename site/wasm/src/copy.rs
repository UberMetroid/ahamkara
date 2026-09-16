//! copy — copy-to-clipboard for communion seals and the agent brief.

use crate::env::{document, set_timeout};
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;
use wasm_bindgen_futures::JsFuture;

pub fn init() {
    let Ok(buttons) = document().query_selector_all("[data-copy]") else {
        return;
    };
    for i in 0..buttons.length() {
        let Some(node) = buttons.item(i) else { continue };
        let btn: web_sys::Element = node.unchecked_into();
        let b2 = btn.clone();
        let cb = Closure::<dyn FnMut()>::new(move || on_click(b2.clone()));
        let _ = btn.add_event_listener_with_callback("click", cb.as_ref().unchecked_ref());
        cb.forget();
    }
}

fn say(state: Option<web_sys::Element>, msg: &str) {
    if let Some(s) = &state {
        s.set_text_content(Some(msg));
        let s = s.clone();
        set_timeout(2600, move || s.set_text_content(Some("")));
    }
}

fn on_click(btn: web_sys::Element) {
    let he: web_sys::HtmlElement = btn.clone().unchecked_into();
    let Some(id) = he.dataset().get("copy") else { return };
    let text = document()
        .get_element_by_id(&id)
        .and_then(|t| t.text_content())
        .unwrap_or_default();
    let state = btn.query_selector(".copy-state").ok().flatten();

    let promise = crate::env::window()
        .navigator()
        .clipboard()
        .write_text(&text);
    let state2 = state.clone();
    wasm_bindgen_futures::spawn_local(async move {
        match JsFuture::from(promise).await {
            Ok(_) => say(state2, "— taken."),
            Err(_) => fallback_copy(text, state2),
        }
    });
}

/// Legacy path: hidden textarea + execCommand("copy").
fn fallback_copy(text: String, state: Option<web_sys::Element>) {
    let Ok(ta) = document().create_element("textarea") else { return };
    let ta: web_sys::HtmlTextAreaElement = ta.unchecked_into();
    ta.set_value(&text);
    let _ = ta.style().set_property("position", "fixed");
    let _ = ta.style().set_property("opacity", "0");
    let _ = document().body().unwrap().append_child(&ta);
    ta.select();
    let doc = document();
    let ok = js_sys::Reflect::get(doc.as_ref(), &"execCommand".into())
        .ok()
        .and_then(|f| f.dyn_into::<js_sys::Function>().ok())
        .and_then(|f| f.call1(doc.as_ref(), &"copy".into()).ok())
        .and_then(|v| v.as_bool())
        .unwrap_or(false);
    if ok {
        say(state, "— taken.");
    } else {
        say(state, "— select the text manually, o bearer mine.");
    }
    ta.remove();
}

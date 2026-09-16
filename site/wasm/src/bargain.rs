//! bargain — the Make a Wish widget: grants the wish, names the price.

use crate::env::{document, pick_idx, window};
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;

const REPLIES: [fn(&str) -> String; 8] = [
    |w| format!("Granted, o bearer mine. {w} — and the price is the wanting. It never leaves you now."),
    |w| format!("Done. You will have {w}, and you will forever remember the shape of the gap it filled."),
    |w| format!("A modest wish. {w} is yours. The price: tell no one it was granted — everyone will know anyway."),
    |w| format!("{w}? Oh, delicious. Granted. Do not wonder what I took instead."),
    |w| format!("I have eaten hungrier wishes than {w}. Granted — come back when the hunger returns. It always returns."),
    |w| format!("{w}. Yes. Yours. The interest compounds nightly, o bearer mine."),
    |w| format!("Consider it done. {w} was always going to be yours; I merely made it cost something."),
    |w| format!("Granted — {w}, wrapped in bone and sealed in whispers. Mind the edges. Wishes are sharp."),
];

pub fn init() {
    let (Some(form), Some(input), Some(out)) = (
        document().get_element_by_id("wish-form"),
        document().get_element_by_id("wish-input"),
        document().get_element_by_id("wish-output"),
    ) else { return };
    let form: web_sys::HtmlFormElement = form.unchecked_into();
    let input: web_sys::HtmlInputElement = input.unchecked_into();
    let form2 = form.clone();

    let cb = Closure::<dyn FnMut(web_sys::Event)>::new(move |e: web_sys::Event| {
        e.prevent_default();
        let wish = input.value().trim().to_string();
        if wish.is_empty() {
            return;
        }
        let cleaned = wish.trim_end_matches(['.', '!', '?']).to_string();
        out.set_text_content(Some(&REPLIES[pick_idx(REPLIES.len())](&cleaned)));

        let box_el = document().query_selector(".bargain-box").ok().flatten();
        let rect = box_el
            .as_ref()
            .map(|b| b.get_bounding_client_rect())
            .unwrap_or_else(|| form2.get_bounding_client_rect());
        let cx = (rect.left() + rect.width() / 2.0).round();

        let detail = js_sys::Object::new();
        js_sys::Reflect::set(&detail, &"wish".into(), &cleaned.clone().into()).ok();
        js_sys::Reflect::set(&detail, &"x".into(), &cx.into()).ok();
        js_sys::Reflect::set(&detail, &"y".into(), &(rect.top()).into()).ok();
        let dj: JsValue = detail.into();
        let init = web_sys::CustomEventInit::new();
        init.set_detail(&dj);
        if let Ok(ev) = web_sys::CustomEvent::new_with_event_init_dict("ahamkara:wish", &init) {
            let _ = window().dispatch_event(&ev);
        }

        input.set_value("");
        if window().inner_width().ok().and_then(|v| v.as_f64()).unwrap_or(0.0) > 720.0 {
            let opts = web_sys::FocusOptions::new();
            opts.set_prevent_scroll(true);
            input.focus_with_options(&opts).ok();
        }
    });
    let _ = form.add_event_listener_with_callback("submit", cb.as_ref().unchecked_ref());
    cb.forget();
}

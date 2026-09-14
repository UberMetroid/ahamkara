//! wishes.html — the Wall of Wishes

use crate::chrome::layout;
use crate::corpus::{esc, Record};
use crate::pick_whisper;

/// Documented in-raid effects, keyed by wish number. Effects are player-documented
/// game mechanics; the corpus records the wishes themselves.
const WISH_EFFECTS: &[(&str, &str)] = &[
    ("wish-wall-first-wish", "grants an Ethereal Key for bonus raid chests"),
    ("wish-wall-second-wish", "spawns a hidden chest between Shuro Chi and Morgeth"),
    ("wish-wall-third-wish", "grants the Numbers of Power emblem"),
    ("wish-wall-fourth-wish", "warp — the Shuro Chi checkpoint"),
    ("wish-wall-fifth-wish", "warp — the Morgeth checkpoint"),
    ("wish-wall-sixth-wish", "warp — the Vault checkpoint"),
    ("wish-wall-seventh-wish", "warp — the Riven checkpoint"),
    ("wish-wall-eighth-wish", "plays Hope for the Future through the raid"),
    ("wish-wall-ninth-wish", "Failsafe narrates your progress"),
    ("wish-wall-tenth-wish", "the Drifter narrates your progress"),
    ("wish-wall-eleventh-wish", "precision kills detonate the target"),
    ("wish-wall-twelfth-wish", "opens a hidden passage — the fine print is still argued over"),
    ("wish-wall-thirteenth-wish", "begins Petra's Run — the flawless, timed challenge"),
    ("wish-wall-fourteenth-wish", "scatters Corrupted Eggs through the raid"),
    ("wish-wall-fifteenth-wish", "undecoded for years — the community's white whale"),
];

pub fn page_wishes(records: &[Record], whispers: &[(&str, &str)]) -> String {
    let mut items = String::new();
    for (i, r) in records.iter().filter(|r| r.source.kind == "wall_of_wishes").enumerate() {
        let effect = WISH_EFFECTS
            .iter()
            .find(|(id, _)| *id == r.id)
            .map(|(_, e)| *e)
            .unwrap_or("effect unrecorded");
        items.push_str(&format!(
            r##"<li class="wish" id="{id}">
<span class="wish-num" aria-hidden="true"><span>{num}</span></span>
<div>
<h2 class="wish-title">{title}</h2>
<p class="wish-say">{say}</p>
<p class="wish-effect">Documented effect: {effect}.</p>
{link}
</div>
</li>
"##,
            id = esc(&r.id),
            num = i + 1,
            title = esc(&r.title),
            say = esc(&r.transcript),
            effect = esc(effect),
            link = r.source.ishtar_url.as_deref().map(|u| format!(
                r#"<a class="ext" href="{}" target="_blank" rel="noopener noreferrer">Ishtar Collective &nearr;</a>"#,
                esc(u)
            )).unwrap_or_default(),
        ));
    }

    let body = format!(
        r##"
<header class="page-head">
  <p class="kicker">coded desire</p>
  <h1>The Wall of Wishes</h1>
  <p class="lede">In the Last Wish raid there is a wall of sixteen plates, and a pattern of them is a sentence, and a sentence is a wish. Fifteen were found. The dragons count differently than we do.</p>
  <p class="fine">Effects below are documented by player scholars as in-raid mechanics. The corpus preserves the wishes; the wall keeps the syntax.</p>
</header>
<ol class="wishlist">{items}</ol>
"##
    );

    layout(
        "wishes",
        "The Wall of Wishes",
        "The fifteen coded wishes of the Last Wish raid — what they say and what they do.",
        &body,
        pick_whisper(whispers, 4),
    )
}


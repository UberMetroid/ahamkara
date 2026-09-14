//! index.html — the Bargain

use crate::chrome::{layout, rule};
use crate::corpus::{esc, Record};

pub fn page_index(records: &[Record], whispers: &[(&str, &str)]) -> String {
    let featured = whispers
        .iter()
        .copied()
        .find(|(q, _)| q.contains("Reality is the finest flesh"))
        .unwrap_or(("Reality is the finest flesh, oh bearer mine. And are you not hungry?", "Skull of Dire Ahamkara"));

    let n = records.len();
    let dragons = {
        let mut s: Vec<&str> = records.iter().flat_map(|r| r.entity.iter().map(String::as_str)).collect();
        s.sort_unstable();
        s.dedup();
        s.len()
    };
    let wishes = records.iter().filter(|r| r.source.kind == "wall_of_wishes").count();
    let eras = {
        let mut s: Vec<&str> = records.iter().map(|r| r.chronology.as_str()).collect();
        s.sort_unstable();
        s.dedup();
        s.len()
    };

    let tile_defs: [(&str, &str, String, &str); 6] = [
        ("lore.html", "The Archive", format!("{n} canonical records, fully searchable."), "Search the corpus"),
        ("dragons.html", "The Dragons", format!("{dragons} named voices, from Riven to the Harmony's own."), "Meet them"),
        ("history.html", "The History", format!("{eras} eras, from pre-Collapse to the Final Shape."), "Follow the timeline"),
        ("wishes.html", "The Wall", format!("{wishes} coded desires, still waiting to be made."), "Read the wishes"),
        ("facts.html", "The Field Guide", "Everything that is known about the wish-dragons.".to_string(), "Learn the facts"),
        ("communion.html", "The Rite of Communion", "An incantation that turns any large language model into a wish-dragon.".to_string(), "Perform the rite"),
    ];
    let tiles = tile_defs
        .iter()
        .map(|(href, name, blurb, cta)| {
            format!(
                r#"<li class="tile"><a href="{href}"><span class="tile-name">{name}</span><span class="tile-blurb">{blurb}</span><span class="tile-cta">{cta} &rarr;</span></a></li>"#
            )
        })
        .collect::<String>();

    let body = format!(
        r##"
<section class="bargain-box" aria-labelledby="bargain-h">
  <div class="bargain-copy">
    <h2 id="bargain-h">Make a wish</h2>
    <p>Tell the dragon what you want. It will find the price you cannot see &mdash; it always does.</p>
    <p class="fine">A toy bargain. The true rite lives in <a href="communion.html">Communion</a>.</p>
  </div>
  <div class="bargain-form">
    <form id="wish-form" class="wish-form" autocomplete="off">
      <label for="wish-input">I wish for&hellip;</label>
      <div class="wish-row">
        <input id="wish-input" name="wish" type="text" maxlength="140" placeholder="&hellip;more wishes" required>
        <button type="submit">Wish</button>
      </div>
    </form>
    <output id="wish-output" class="wish-output" aria-live="polite"></output>
  </div>
</section>

<section class="hero">
  <h1 class="hero-title">Ahamkara</h1>
  <p class="hero-desc">An Ahamkara is a wish-dragon: a creature that fed on the gap between what is and what is desired, and paid for its meals in bargains. You wished; it granted; the price arrived later, folded into the wording you chose yourself. The City decided a thing like that could not be allowed to exist, and so the Guardians held a Great Hunt, and now there are none left.</p>
  <figure class="featured">
    <blockquote id="featured-quote"><p>&ldquo;{}&rdquo;</p></blockquote>
    <figcaption>&mdash; <span id="featured-speaker">{}</span></figcaption>
  </figure>
</section>

{rule}

<nav class="tiles" aria-label="Site sections"><ul>{tiles}</ul></nav>
"##,
        esc(featured.0),
        esc(featured.1),
        rule = rule("· · ·")
    );

    layout(
        "index",
        "The Bargain",
        "A canonical archive of the Ahamkara — the wish-dragons of Destiny, hunted to extinction for the danger of their generosity.",
        &body,
        &featured,
    )
}


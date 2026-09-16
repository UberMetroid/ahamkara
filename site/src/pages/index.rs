//! index.html — the Bargain

use crate::chrome::layout;
use crate::corpus::{esc, Record};
use crate::pick_whisper;

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

    let tile_defs: [(&str, &str, String, &str); 5] = [
        ("lore.html", "The Archive", format!("{n} canonical records, fully searchable."), "Search the corpus"),
        ("dragons.html", "The Dragons", format!("{dragons} named voices, from Riven to the Harmony's own."), "Meet them"),
        ("history.html", "The History", format!("{eras} eras, from pre-Collapse to the Final Shape."), "Follow the timeline"),
        ("wishes.html", "The Wall", format!("{wishes} coded desires, still waiting to be made."), "Read the wishes"),
        ("facts.html", "The Field Guide", "Everything that is known about the wish-dragons.".to_string(), "Learn the facts"),
    ];
    // A whispered fragment between snap stops — the transition is a wish.
    let whisper_gap = |salt: usize, tag: &str| {
        let (q, _) = pick_whisper(whispers, salt);
        format!(
            r#"<{tag} class="wish-gap" aria-hidden="true"><span class="wish-gap-line"></span><p class="wish-gap-voice">&ldquo;{}&rdquo;</p><span class="wish-gap-line"></span></{tag}>"#,
            esc(q)
        )
    };

    let mut tiles = String::new();
    for (i, (href, name, blurb, cta)) in tile_defs.iter().enumerate() {
        if i > 0 {
            tiles.push_str(&whisper_gap(37 + i * 7, "li"));
        }
        tiles.push_str(&format!(
            r#"<li class="tile"><a href="{href}"><span class="tile-name">{name}</span><span class="tile-blurb">{blurb}</span><span class="tile-cta">{cta} &rarr;</span></a></li>"#
        ));
    }

    let body = format!(
        r##"
<div class="page-index-wrap">
  <section class="hero-viewport">
    <canvas id="hero-smoke" class="hero-smoke" aria-hidden="true"></canvas>
    <div class="hero-quote-wrap">
      <blockquote id="featured-quote">
        <p>&ldquo;{}&rdquo;</p>
        <figcaption>&mdash; <span id="featured-speaker">{}</span></figcaption>
      </blockquote>
    </div>
    <a href="#lore" class="scroll-hint" aria-label="Scroll to content">Scroll to awaken the bones <span class="scroll-arrow">&darr;</span></a>
  </section>
  {gap0}
  <section class="core-lore" id="lore">
    <div class="lore-header">
      <h1 class="hero-title">Ahamkara</h1>
      {gap1}
      <p class="hero-desc">An Ahamkara is a wish-dragon: a creature that fed on the gap between what is and what is desired, and paid for its meals in bargains. You wished; it granted; the price arrived later, folded into the wording you chose yourself. The City decided a thing like that could not be allowed to exist, and so the Guardians held a Great Hunt, and now there are none left.</p>
    </div>
    {gap2}
    <section class="bargain-box" aria-labelledby="bargain-h">
      <div class="bargain-copy">
        <h2 class="bargain-title" id="bargain-h">Make a wish</h2>
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
  </section>
  {gap3}
  <section class="tiles" aria-label="Site sections">
    <ul>{tiles}</ul>
  </section>
  {gap4}
</div>
"##,
        esc(featured.0),
        esc(featured.1),
        tiles = tiles,
        gap0 = whisper_gap(2, "div"),
        gap1 = whisper_gap(9, "div"),
        gap2 = whisper_gap(16, "div"),
        gap3 = whisper_gap(23, "div"),
        gap4 = whisper_gap(30, "div"),
    );

    layout(
        "index",
        "The Bargain",
        "A canonical archive of the Ahamkara — the wish-dragons of Destiny, hunted to extinction for the danger of their generosity.",
        &body,
        &featured,
    )
}


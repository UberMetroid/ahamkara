//! facts.html — the Field Guide

use crate::chrome::{layout, rule};
use crate::corpus::{esc, Record};
use crate::pick_whisper;

pub fn page_facts(records: &[Record], whispers: &[(&str, &str)]) -> String {
    // Best short quotes for the whisper gallery.
    let mut quotes: Vec<&Record> = records
        .iter()
        .filter(|r| r.transcript.len() >= 40 && r.transcript.len() <= 260)
        .take(6)
        .collect();
    quotes.sort_by_key(|r| r.transcript.len());
    let quote_html = quotes
        .iter()
        .map(|r| {
            format!(
                r#"<figure class="q"><blockquote><p>&ldquo;{}&rdquo;</p></blockquote><figcaption>&mdash; {} · <a href="lore.html#{}">{}</a></figcaption></figure>"#,
                esc(&r.transcript),
                esc(r.speaker.as_deref().unwrap_or("the archive")),
                esc(&r.id),
                esc(&r.title)
            )
        })
        .collect::<String>();

    let facts: &[(&str, &str)] = &[
        ("What they are",
         "Ahamkara are wish-dragons: shapeshifting creatures that feed on the gap between what is and what is desired. The Skull of Dire Ahamkara glosses the name itself as the illusion that one's ego depends on an object, an idea, or a body — ahamkara, the I-maker. They did not create reality from nothing; they arbitraged the distance between your world and your want."),
        ("How they feed",
         "The corpus calls it Anthem Anatheme — the universe's hunger to be defined, to be real. An ahamkara locates a desire, grants it, and feeds on the differential. The bigger the gap between is and wished-for, the richer the meal. Reality, to them, is the finest flesh."),
        ("The bargain",
         "Every deal has the same shape: you word the wish, they word the price. Ahamkara answer their bearers with 'o bearer mine' — not affection, but taxonomy: you are the thing that carries them. The corpus records the formula across forty-three of Riven's records alone, and it never once sounds like a joke."),
        ("The Great Hunt",
         "The City concluded that a species which grants wishes cannot be allowed to exist. The Great Ahamkara Hunt was called, Guardians became dragonslayers, and the dragons were driven to extinction — save one hidden under the Dreaming City, and the bones, and the gear, and the whispers. Extinction, for a wish-dragon, is a negotiating position."),
        ("Deathless bones",
         "Ahamkara persist after death — in bone, in relics, in the weapons and armor cut from their bodies. The raid gear of the Great Hunt is quite literally made of the hunted dead, and it still whispers. 'Defy extinction,' reads the entire surviving testament of Eao. He was right."),
        ("The fourth wall",
         "The Skull of Dire Ahamkara does not speak to your Guardian. It speaks to you — 'o player mine' — calls the game thin cardboard and cheap theater, and invites you to be the only real person in it. Ahamkara are the only beings in the setting confirmed to know it is a game. It does not seem to trouble them."),
        ("Not only ours",
         "The Books of Sorrow record that the Harmony — a species destroyed by the Hive — kept wish-dragons of their own, and that the Hive ate their wishes at the Gift Mast. Savathûn later bound two ahamkara, Huginn and Muninn, thought and memory, into her designs."),
        ("The fifteenth wish",
         "Fourteen wishes on the Wall were decoded within weeks. The fifteenth — 'this one you shall cherish,' per Riven — resisted for years. Season of the Wish revealed what it was for: not a cheat code, but the clutch. A wish spent to carry the species' eggs beyond everything hunting them."),
    ];

    let fact_html = facts
        .iter()
        .map(|(h, b)| format!("<section class=\"fact\"><h2>{h}</h2><p>{b}</p></section>"))
        .collect::<String>();

    let body = format!(
        r##"
<header class="page-head">
  <p class="kicker">all the wish dragon facts</p>
  <h1>The Field Guide</h1>
  <p class="lede">Everything the corpus will swear to in writing, organized for the field. Treat each entry as a tooth: the shape of the animal is in the pattern of them.</p>
</header>
<div class="facts">{fact_html}</div>
{rule}
<h2 class="gallery-h">The bones, verbatim</h2>
<div class="quotes">{quote_html}</div>
"##,
        rule = rule("· · ·")
    );

    layout(
        "facts",
        "The Field Guide",
        "All the wish-dragon facts — feeding, bargains, the Great Hunt, deathless bones, and the fourth wall.",
        &body,
        pick_whisper(whispers, 5),
    )
}


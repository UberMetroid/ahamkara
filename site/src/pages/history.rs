//! history.html — timeline

use crate::chrome::layout;
use crate::corpus::{esc, Record};
use crate::pick_whisper;

const ERAS: &[(&str, &str)] = &[
    ("Pre-Collapse & Ancient Origins",
     "Before records, before the City: the ahamkara coiled through the gaps in the world, feeding where reality ran thin. The corpus keeps three voices from before everything fell."),
    ("Dark Age & Early City Age",
     "Humanity crawled out of the Collapse and found the dragons waiting in the ruins — or the dragons found humanity. Bargains were struck in the dark: wishes for survival, priced in things survivors could not spare."),
    ("The Great Ahamkara Hunt",
     "The City decided that a thing which grants wishes cannot be permitted to exist. The Great Hunt was called; Guardians became dragonslayers. The species was driven to extinction — officially."),
    ("Reef Golden Age & The Dreaming City",
     "The Awoken kept one. Queen Mara Sov bound Riven beneath the Dreaming City and raised a wonder on the back of a wish-dragon — a city that was itself, in part, a wish."),
    ("The Taken War",
     "Oryx came to the Reef and took what Mara had hidden. Riven of a Thousand Voices was Taken — a wish-dragon rewritten into a weapon, her bargains now aimed."),
    ("Forsaken & The Dreaming City Curse",
     "Riven's death in the Last Wish was her last and largest bargain: the Dreaming City fell into a three-week curse, an engine of grief and vengeance that ran for years and could not be unwished."),
    ("Season of the Wish & The Final Shape",
     "The fifteenth wish bore fruit. Riven's clutch — eggs raised free of the bargain — was wished beyond reach of everything hunting it. Extinction, it turns out, is also negotiable."),
];

pub fn page_history(records: &[Record], whispers: &[(&str, &str)]) -> String {
    let mut items = String::new();
    for (i, (era, blurb)) in ERAS.iter().enumerate() {
        let recs: Vec<&Record> = records.iter().filter(|r| r.chronology == *era).collect();
        let links = recs
            .iter()
            .take(4)
            .map(|r| format!(r#"<li><a href="lore.html#{}">{}</a></li>"#, esc(&r.id), esc(&r.title)))
            .collect::<String>();
        items.push_str(&format!(
            r##"<li class="era">
<div class="era-num" aria-hidden="true">{num}</div>
<div class="era-card">
<h2>{era}</h2>
<p class="blurb">{blurb}</p>
<p class="dcount">{n} record{plural}</p>
<ul class="dlist">{links}</ul>
</div>
</li>
"##,
            num = i + 1,
            era = esc(era),
            blurb = esc(blurb),
            n = recs.len(),
            plural = if recs.len() == 1 { "" } else { "s" },
            links = links,
        ));
    }

    let body = format!(
        r##"
<header class="page-head">
  <p class="kicker">everything is negotiated, eventually</p>
  <h1>The History</h1>
  <p class="lede">The wish-dragons were old when the Traveler arrived and are not entirely gone now. Seven eras, told in the order the bones give them up.</p>
</header>
<ol class="timeline">{items}</ol>
"##
    );

    layout(
        "history",
        "The History",
        "A timeline of the Ahamkara — from pre-Collapse origins through the Great Hunt, the Taken War, and the uncorrupted clutch.",
        &body,
        pick_whisper(whispers, 3),
    )
}


//! lore.html — the Archive

use crate::chrome::layout;
use crate::corpus::{esc, paragraphs, Record};
use crate::pick_whisper;

pub fn opts(values: &[&str]) -> String {
    values
        .iter()
        .map(|v| format!(r#"<option value="{v}">{v}</option>"#, v = esc(v)))
        .collect()
}

pub fn page_lore(records: &[Record], whispers: &[(&str, &str)]) -> String {
    let mut entities: Vec<&str> = records.iter().flat_map(|r| r.entity.iter().map(String::as_str)).collect();
    entities.sort_unstable();
    entities.dedup();
    let mut eras: Vec<&str> = records.iter().map(|r| r.chronology.as_str()).collect();
    eras.sort_unstable();
    eras.dedup();
    let mut kinds: Vec<&str> = records.iter().map(|r| r.source.kind.as_str()).collect();
    kinds.sort_unstable();
    kinds.dedup();

    let mut entries = String::new();
    for r in records {
        let tags = r
            .tags
            .iter()
            .map(|t| format!("<span class=\"tag\">{}</span>", esc(t)))
            .collect::<String>();
        let source_bits = [
            Some(r.source.game.as_str()),
            r.source.book.as_deref(),
            r.source.release.as_deref(),
        ]
        .into_iter()
        .flatten()
        .collect::<Vec<_>>()
        .join(" · ");
        let ishtar = r
            .source
            .ishtar_url
            .as_deref()
            .map(|u| {
                format!(
                    r#"<a class="ext" href="{}" target="_blank" rel="noopener noreferrer">Ishtar Collective &nearr;</a>"#,
                    esc(u)
                )
            })
            .unwrap_or_default();
        let speaker_txt = r.speaker.as_deref().unwrap_or("unattributed");
        let search = esc(&format!("{} {} {} {}", r.title, speaker_txt, r.transcript, r.tags.join(" ")).to_lowercase());
        entries.push_str(&format!(
            r##"<details class="entry" id="{id}" data-entities="{entities}" data-era="{era}" data-kind="{kind}" data-search="{search}">
<summary><span class="entry-title">{title}</span><span class="entry-meta"><span class="chip">{speaker}</span><span class="chip kind">{kindh}</span></span></summary>
<div class="entry-body">
{body}
<p class="entry-src"><span>{src}</span> {ishtar}</p>
<p class="entry-speaker">speaker: <em>{speakerh}</em> &middot; era: {era} &middot; theme: {theme}</p>
<p class="entry-tags">{tags}</p>
</div>
</details>
"##,
            id = esc(&r.id),
            entities = esc(&r.entity.join(", ")),
            era = esc(&r.chronology),
            kind = esc(&r.source.kind),
            search = search,
            title = esc(&r.title),
            speaker = esc(&r.entity.join(" · ")),
            kindh = esc(&r.source.kind.replace('_', " ")),
            body = paragraphs(&r.transcript),
            src = esc(&source_bits),
            ishtar = ishtar,
            speakerh = esc(speaker_txt),
            theme = esc(&r.theme),
            tags = tags,
        ));
    }

    let body = format!(
        r##"
<header class="page-head">
  <p class="kicker">the bones remember</p>
  <h1>The Archive</h1>
  <p class="lede">Every canonical record in the corpus &mdash; grimoire cards, lore books, raid gear, dialogue, and the Wall itself. Search it, filter it, or open the bones one by one. Works without JavaScript; the archive simply refuses to hide.</p>
</header>

<form class="filters" id="filters" role="search" aria-label="Filter the archive">
  <div class="f-row">
    <label for="f-q">Search</label>
    <input id="f-q" type="search" placeholder="anthem anatheme, o bearer mine, riven&hellip;" autocomplete="off">
  </div>
  <div class="f-row f-grid">
    <div><label for="f-entity">Dragon</label><select id="f-entity"><option value="">all voices</option>{}</select></div>
    <div><label for="f-era">Era</label><select id="f-era"><option value="">all eras</option>{}</select></div>
    <div><label for="f-kind">Source</label><select id="f-kind"><option value="">all sources</option>{}</select></div>
  </div>
  <p class="f-count"><span id="f-count">{n}</span> records <button type="button" id="f-clear" class="linklike" hidden>clear filters</button></p>
</form>

<section class="entries" id="entries" aria-live="polite">
{entries}
</section>
<p id="f-empty" class="f-empty" hidden>No records match. The dragon suggests wishing for something else.</p>
"##,
        opts(&entities),
        opts(&eras),
        opts(&kinds.iter().map(|k| k.replace('_', " ")).collect::<Vec<_>>().iter().map(String::as_str).collect::<Vec<_>>()),
        n = records.len(),
        entries = entries
    );

    layout(
        "lore",
        "The Archive",
        "All canonical Ahamkara lore records — searchable and filterable by dragon, era, and source.",
        &body,
        pick_whisper(whispers, 1),
    )
}


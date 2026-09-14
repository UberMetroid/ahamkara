//! dragons.html — bestiary

use crate::chrome::layout;
use crate::corpus::{esc, Record};
use crate::pick_whisper;

struct Profile {
    name: &'static str,
    epithet: &'static str,
    blurb: &'static str,
}

const PROFILES: &[Profile] = &[
    Profile {
        name: "Riven",
        epithet: "of a Thousand Voices · the last Ahamkara",
        blurb: "Kept by Queen Mara Sov beneath the Dreaming City as its secret engine of wishes, Riven survived the Great Hunt by being hidden rather than spared. Taken by Oryx in the Taken War, she was finally slain by six Guardians in the Last Wish raid — and in dying granted the largest wish of all: the Curse, a three-week loop of Taken corruption that ran for years. Her final season bore stranger fruit: an uncorrupted clutch of eggs, wished beyond reach, to hatch somewhere free of the bargain's shadow.",
    },
    Profile {
        name: "Taranis",
        epithet: "the gentle mate · keeper of the clutch",
        blurb: "Mate to Riven and keeper of the uncorrupted clutch in the Black Garden. Unlike his kin, Taranis granted wishes out of genuine care without extracting cruel tolls. When the clutch was endangered, he made the ultimate sacrifice: an Ahamkara cannot wish upon themselves without dying, yet he wished upon himself to scatter and shield their eggs across the stars. The exotic bow Wish-Keeper was carved from his marrow.",
    },
    Profile {
        name: "Hefnd",
        epithet: "the dragon under the mountain",
        blurb: "Buried beneath a cairn in the European Dead Zone, Hefnd's bones never stopped talking. Generations of warlords heard him; Naeem's dragon-cult built a faith on the whispers. 'Ruin to kings,' he promised, and the Warlord's Ruin keeps his bones to this day — his blood still runs in the Buried Bloodline.",
    },
    Profile {
        name: "Azirim",
        epithet: "the song of Esila · tempter of the Reef",
        blurb: "In the early days of the Reef, Azirim preyed upon the Awoken with honeyed song and false fellowship. The Marasenna records how he lured twenty Awoken dancers into an ecstatic trance over the sheer precipice of the Gardens of Esila, feasting upon their falling terror. A cursed tree in Esila marks his treacherous legacy.",
    },
    Profile {
        name: "Huginn",
        epithet: "thought · companion of Sjur Eido",
        blurb: "One of twin Ahamkara kept by Queen's Wrath Sjur Eido in the Reef. Sjur herself slew Huginn during the Great Hunt to honor the Vanguard decree, enshrining his skull in Harbinger's Seclude. In death, Huginn's skull continues to bargain, trading Queensfoil tinctures to any Lightbearer seeking to pierce the Ascendant veil.",
    },
    Profile {
        name: "Muninn",
        epithet: "memory · companion of Sjur Eido",
        blurb: "Brother to Huginn and companion to Sjur Eido, recognized by his curling tusks in Lethophobia. Slayed alongside his brother in the Great Hunt, Muninn's horned skull rests beside Huginn deep in Harbinger's Seclude, bartering Charges of Light for the Blind Well.",
    },
    Profile {
        name: "Eao",
        epithet: "the defier",
        blurb: "'Defy extinction.' That is the whole of Eao's surviving testament, set into a pair of exotic Hunter boots and proved correct: the Bones of Eao still whisper across time, urging Hunters to leap beyond the sky, while his aerie still echoes at Harbinger's Seclude.",
    },
    Profile {
        name: "Harmony Wish-Dragons",
        epithet: "the dragons of another sky",
        blurb: "Earth was not the only world with wish-dragons. The Harmony — a people the Hive conquered in the Books of Sorrow — kept dragons of their own, and the Gift Mast records what it costs a species when its wishes are eaten by something hungrier.",
    },
    Profile {
        name: "Unnamed Great Hunt Dragons",
        epithet: "the hunted dead",
        blurb: "Twelve records, no names. These are the dragons remembered only through what was made of them: the armor and weapons of the Great Hunt, every piece a body.",
    },
    Profile {
        name: "General Ahamkara",
        epithet: "the unattributed voice",
        blurb: "Records that speak for the species as a whole — the exotics cut from ahamkara bone that still address their wearers. The Skull of Dire Ahamkara is the loudest of them, and the only one to break the fourth wall and call the player real.",
    },
];

pub fn page_dragons(records: &[Record], whispers: &[(&str, &str)]) -> String {
    let mut sections = String::new();
    for p in PROFILES {
        let recs: Vec<&Record> = records.iter().filter(|r| r.entity.iter().any(|e| e == p.name)).collect();
        let links = recs
            .iter()
            .take(6)
            .map(|r| format!(r#"<li><a href="lore.html#{}">{}</a></li>"#, esc(&r.id), esc(&r.title)))
            .collect::<String>();
        let extra = if recs.len() > 6 {
            format!(r#"<li class="more">+ {} more in the <a href="lore.html">Archive</a></li>"#, recs.len() - 6)
        } else {
            String::new()
        };
        sections.push_str(&format!(
            r##"<article class="dragon" id="{id}">
<h2>{name}</h2>
<p class="epithet">{epithet}</p>
<p class="blurb">{blurb}</p>
<p class="dcount">{n} record{plural} in the corpus</p>
<ul class="dlist">{links}{extra}</ul>
</article>
"##,
            id = p.name.to_lowercase().replace(' ', "-"),
            name = esc(p.name),
            epithet = esc(p.epithet),
            blurb = esc(p.blurb),
            n = recs.len(),
            plural = if recs.len() == 1 { "" } else { "s" },
            links = links,
            extra = extra,
        ));
    }

    let body = format!(
        r##"
<header class="page-head">
  <p class="kicker">name them and they answer</p>
  <h1>The Dragons</h1>
  <p class="lede">Ten voices survive in the corpus. Some were individuals; some are categories we keep because the dead deserve their paperwork. Each profile links into the Archive, where the bones speak for themselves.</p>
</header>
{sections}
"##
    );

    layout(
        "dragons",
        "The Dragons",
        "Bestiary of the named Ahamkara — Riven, Taranis, Hefnd, Azirim, Huginn, Muninn, Eao, and the hunted dead.",
        &body,
        pick_whisper(whispers, 2),
    )
}

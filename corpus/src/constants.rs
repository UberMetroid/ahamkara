//! Canonical constants — allowed enums and the canonical checklist.
//! Ported from scripts/validate/constants.py.

pub const VALID_CHRONOLOGIES: &[&str] = &[
    "Pre-Collapse & Ancient Origins",
    "Dark Age & Early City Age",
    "The Great Ahamkara Hunt",
    "Reef Golden Age & The Dreaming City",
    "The Taken War",
    "Forsaken & The Dreaming City Curse",
    "Season of the Wish & The Final Shape",
];

pub const VALID_THEMES: &[&str] = &[
    "Anthem Anatheme & Wish-Bargains",
    "The Great Hunt & Extinction",
    "Fourth-Wall Transcendence (\"O [Reader] Mine\")",
    "The Wall of Wishes & Coded Desire",
    "Parentage & The Uncorrupted Clutch",
    "Deathless Bones & Parasitic Whispers",
    "Vengeance & Twisted Desires",
];

pub const VALID_SOURCE_TYPES: &[&str] = &[
    "exotic_armor",
    "exotic_weapon",
    "raid_armor",
    "raid_weapon",
    "lore_book",
    "grimoire_card",
    "dialogue_transcript",
    "quest_lore",
    "wall_of_wishes",
];

pub const VALID_GAMES: &[&str] = &["Destiny 1", "Destiny 2"];

pub const VALID_ENTITIES: &[&str] = &[
    "Riven",
    "Taranis",
    "Hefnd",
    "Huginn",
    "Muninn",
    "Azirim",
    "Eao",
    "Unnamed Great Hunt Dragons",
    "Harmony Wish-Dragons",
    "General Ahamkara",
];

pub const REQUIRED_CANONICAL_ENTITIES: &[&str] =
    &["Riven", "Taranis", "Hefnd", "Huginn", "Muninn", "Azirim", "Eao"];

/// The canonical checklist — grouped expected record ids.
pub const CANONICAL_CHECKLIST: &[(&str, &[&str])] = &[
    ("Exotic Armor (5)", &[
        "exotic-skull-of-dire-ahamkara",
        "exotic-young-ahamkaras-spine",
        "exotic-claws-of-ahamkara",
        "exotic-sealed-ahamkara-grasps",
        "exotic-bones-of-eao",
    ]),
    ("Exotic Weapons (4)", &[
        "weapon-one-thousand-voices",
        "weapon-wish-keeper",
        "weapon-wish-ender",
        "weapon-buried-bloodline",
    ]),
    ("Last Wish Raid Weapons (8)", &[
        "raid-weapon-apex-predator",
        "raid-weapon-age-old-bond",
        "raid-weapon-transfiguration",
        "raid-weapon-nation-of-beasts",
        "raid-weapon-techeun-force",
        "raid-weapon-chattering-bone",
        "raid-weapon-tyranny-of-heaven",
        "raid-weapon-the-supremacy",
    ]),
    ("Great Hunt Raid Armor (15)", &[
        "great-hunt-helm", "great-hunt-gauntlets", "great-hunt-plate",
        "great-hunt-greaves", "great-hunt-mark", "great-hunt-mask",
        "great-hunt-grips", "great-hunt-vest", "great-hunt-strides",
        "great-hunt-cloak", "great-hunt-hood", "great-hunt-gloves",
        "great-hunt-robes", "great-hunt-boots", "great-hunt-bond",
    ]),
    ("Warlord's Ruin Gear & Records (5)", &[
        "warlord-vengeful-whisper",
        "warlord-dragoncult-sickle",
        "warlord-naeems-lance",
        "warlord-ziras-shell",
        "warlord-shadow-mountain-8",
    ]),
    ("Lore Books & Chapters (15)", &[
        "book-marasenna-katabasis", "book-marasenna-azirim",
        "book-marasenna-fideicide-i", "book-marasenna-fideicide-ii",
        "book-marasenna-fideicide-iii", "book-marasenna-imponent-i",
        "book-marasenna-imponent-iv", "book-awoken-reef-telic-i",
        "book-awoken-reef-telic-ii", "book-gifts-first-gift",
        "book-gifts-second-gift", "book-gifts-third-gift",
        "book-gifts-last-bargain", "lore-lethophobia", "lore-oathkeeper",
    ]),
    ("Wall of Wishes (15)", &[
        "wish-wall-first-wish", "wish-wall-second-wish",
        "wish-wall-third-wish", "wish-wall-fourth-wish",
        "wish-wall-fifth-wish", "wish-wall-sixth-wish",
        "wish-wall-seventh-wish", "wish-wall-eighth-wish",
        "wish-wall-ninth-wish", "wish-wall-tenth-wish",
        "wish-wall-eleventh-wish", "wish-wall-twelfth-wish",
        "wish-wall-thirteenth-wish", "wish-wall-fourteenth-wish",
        "wish-wall-fifteenth-wish",
    ]),
    ("Destiny 1 Grimoire Cards (9)", &[
        "grimoire-ghost-fragment-legends-3", "grimoire-ghost-fragment-warlock",
        "grimoire-ghost-fragment-hunter", "grimoire-ghost-fragment-titan",
        "grimoire-ghost-fragment-the-city-age", "grimoire-lord-gheleon",
        "grimoire-osiris", "grimoire-sorrow-viii-leviathan",
        "grimoire-sorrow-xlvi-gift-mast",
    ]),
    ("Dialogue & Transcripts (7)", &[
        "transcript-last-wish-introduction", "transcript-last-wish-cinematic",
        "transcript-pilgrimage-eaos-nest", "transcript-pilgrimage-tree-esila",
        "transcript-tales-osiris-crow", "transcript-tales-shaxx-mara",
        "transcript-final-wish-conjure-riven",
    ]),
];

#!/usr/bin/env python3
"""
scripts/ingest_lore.py — Automated Ahamkara Lore Ingestion Pipeline

Ingests 65+ canonical Ahamkara lore records from the Ishtar Collective API
(https://api.ishtar-collective.net/) and normalizes them into structured JSON,
JSONL, and categorized partition archives.

Features:
- IPv4 enforcement: Overrides socket getaddrinfo to bypass Cloudflare IPv6 TLS handshake hangs.
- Polite rate-limiting: Default 100ms throttle between API calls to respect Ishtar Collective resources.
- Tolerant error handling: Catches HTTP 500 on non-existent slugs as NotFound.
- Offline Fallback Cache: Supports --offline mode and fallback to local cache when API is unreachable.
- 9-Field Schema: id, title, source, entity, speaker, transcript, tags, chronology, theme.
- Multi-Format Export: data/ahamkara_corpus.json, data/ahamkara_corpus.jsonl, data/categories/*.json.
"""

import argparse
import html
import json
import os
import re
import socket
import sys
import time
import urllib.error
import urllib.request

# ==============================================================================
# 1. Network Layer & IPv4 Enforcement
# ==============================================================================

# Force IPv4 socket resolution globally to prevent Cloudflare IPv6 TLS hangs
_orig_getaddrinfo = socket.getaddrinfo

def _getaddrinfo_ipv4(host, port, family=0, type=0, proto=0, flags=0):
    return _orig_getaddrinfo(host, port, socket.AF_INET, type, proto, flags)

socket.getaddrinfo = _getaddrinfo_ipv4

try:
    import urllib3.util.connection
    urllib3.util.connection.allowed_gai_family = lambda: socket.AF_INET
except ImportError:
    pass


class IshtarClient:
    """HTTP client for the Ishtar Collective API with IPv4 enforcement and rate limiting."""

    BASE_URL = "https://api.ishtar-collective.net"
    USER_AGENT = "AhamkaraPreservationBot/1.0 (+https://github.com/UberMetroid/ahamkara)"

    def __init__(self, rate_limit: float = 0.1, timeout: float = 10.0, max_retries: int = 3):
        self.rate_limit = rate_limit
        self.timeout = timeout
        self.max_retries = max_retries
        self._last_call = 0.0

    def _throttle(self):
        elapsed = time.time() - self._last_call
        if elapsed < self.rate_limit:
            time.sleep(self.rate_limit - elapsed)
        self._last_call = time.time()

    def fetch(self, path: str):
        """Fetch a resource path from Ishtar API with throttling and retry logic."""
        url = f"{self.BASE_URL}{path}"
        req = urllib.request.Request(url, headers={"User-Agent": self.USER_AGENT})

        for attempt in range(1, self.max_retries + 1):
            self._throttle()
            try:
                with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                    if resp.status == 200:
                        raw = resp.read().decode("utf-8")
                        return json.loads(raw)
                    return None
            except urllib.error.HTTPError as e:
                if e.code == 500:
                    return None
                elif e.code in (429, 502, 503, 504) and attempt < self.max_retries:
                    time.sleep(0.5 * attempt)
                    continue
                else:
                    return None
            except (urllib.error.URLError, socket.timeout, ConnectionResetError):
                if attempt < self.max_retries:
                    time.sleep(0.5 * attempt)
                    continue
                return None
            except Exception:
                return None
        return None


# ==============================================================================
# 2. Canonical Catalog Specification (84 Records)
# ==============================================================================

CANONICAL_CATALOG = [
    # 1. Exotic Armor (5 entries)
    {
        "id": "exotic-skull-of-dire-ahamkara",
        "api_path": "/entries/skull-of-dire-ahamkara",
        "doc_type": "entry",
        "title": "Skull of Dire Ahamkara",
        "source": {
            "type": "exotic_armor",
            "game": "Destiny 2",
            "book": None,
            "release": "Warmind",
            "bungie_ref": 2523259394,
            "ishtar_url": "https://www.ishtar-collective.net/entries/skull-of-dire-ahamkara"
        },
        "entity": ["General Ahamkara"],
        "speaker": "Skull of Dire Ahamkara",
        "tags": ["exotic", "armor", "warlock", "helmet", "fourth-wall", "o [reader] mine", "o-reader-mine", "o bearer mine", "whispers", "anthem-anatheme", "dragon", "wish-dragon"],
        "chronology": "Dark Age & Early City Age",
        "theme": "Fourth-Wall Transcendence (\"O [Reader] Mine\")"
    },
    {
        "id": "exotic-young-ahamkaras-spine",
        "api_path": "/entries/young-ahamkaras-spine",
        "doc_type": "entry",
        "title": "Young Ahamkara's Spine",
        "source": {
            "type": "exotic_armor",
            "game": "Destiny 2",
            "book": None,
            "release": "Warmind",
            "bungie_ref": 475514659,
            "ishtar_url": "https://www.ishtar-collective.net/entries/young-ahamkaras-spine"
        },
        "entity": ["General Ahamkara"],
        "speaker": "Ahamkara Spine",
        "tags": ["exotic", "armor", "hunter", "gauntlets", "bones", "whispers", "dragon", "wish-dragon"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "Deathless Bones & Parasitic Whispers"
    },
    {
        "id": "exotic-claws-of-ahamkara",
        "api_path": "/entries/claws-of-ahamkara",
        "doc_type": "entry",
        "title": "Claws of Ahamkara",
        "source": {
            "type": "exotic_armor",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 1949095147,
            "ishtar_url": "https://www.ishtar-collective.net/entries/claws-of-ahamkara"
        },
        "entity": ["General Ahamkara"],
        "speaker": "Claws of Ahamkara",
        "tags": ["exotic", "armor", "warlock", "gauntlets", "feathers", "whispers", "dragon", "wish-dragon"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "Deathless Bones & Parasitic Whispers"
    },
    {
        "id": "exotic-sealed-ahamkara-grasps",
        "api_path": "/entries/sealed-ahamkara-grasps",
        "doc_type": "entry",
        "title": "Sealed Ahamkara Grasps",
        "source": {
            "type": "exotic_armor",
            "game": "Destiny 2",
            "book": None,
            "release": "Warmind",
            "bungie_ref": 709971037,
            "ishtar_url": "https://www.ishtar-collective.net/entries/sealed-ahamkara-grasps"
        },
        "entity": ["General Ahamkara"],
        "speaker": "Sealed Ahamkara Grasps",
        "tags": ["exotic", "armor", "hunter", "gauntlets", "silver", "prophecy", "dragon", "wish-dragon"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "Deathless Bones & Parasitic Whispers"
    },
    {
        "id": "exotic-bones-of-eao",
        "api_path": "/items/bones-of-eao",
        "doc_type": "item",
        "title": "Bones of Eao",
        "source": {
            "type": "exotic_armor",
            "game": "Destiny 1",
            "book": None,
            "release": "House of Wolves",
            "bungie_ref": 1865771870,
            "ishtar_url": "https://www.ishtar-collective.net/items/bones-of-eao"
        },
        "entity": ["Eao"],
        "speaker": None,
        "tags": ["exotic", "armor", "hunter", "boots", "eao", "extinction", "dragon", "wish-dragon"],
        "chronology": "Dark Age & Early City Age",
        "theme": "Anthem Anatheme & Wish-Bargains"
    },

    # 2. Exotic Weapons (4 entries)
    {
        "id": "weapon-one-thousand-voices",
        "api_path": "/entries/one-thousand-voices",
        "doc_type": "entry",
        "title": "One Thousand Voices",
        "source": {
            "type": "exotic_weapon",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 2069224039,
            "ishtar_url": "https://www.ishtar-collective.net/entries/one-thousand-voices"
        },
        "entity": ["Riven"],
        "speaker": "Riven of a Thousand Voices",
        "tags": ["exotic", "weapon", "fusion-rifle", "riven", "last-wish", "whispers"],
        "chronology": "Forsaken & The Dreaming City Curse",
        "theme": "Anthem Anatheme & Wish-Bargains"
    },
    {
        "id": "weapon-wish-keeper",
        "api_path": "/entries/wish-keeper",
        "doc_type": "entry",
        "title": "Wish-Keeper",
        "source": {
            "type": "exotic_weapon",
            "game": "Destiny 2",
            "book": None,
            "release": "Season of the Wish",
            "bungie_ref": 3617300746,
            "ishtar_url": "https://www.ishtar-collective.net/entries/wish-keeper"
        },
        "entity": ["Taranis", "Riven"],
        "speaker": "Taranis",
        "tags": ["exotic", "weapon", "bow", "strand", "taranis", "riven", "clutch"],
        "chronology": "Season of the Wish & The Final Shape",
        "theme": "Parentage & The Uncorrupted Clutch"
    },
    {
        "id": "weapon-wish-ender",
        "api_path": "/entries/wish-ender",
        "doc_type": "entry",
        "title": "Wish-Ender",
        "source": {
            "type": "exotic_weapon",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 814875373,
            "ishtar_url": "https://www.ishtar-collective.net/entries/wish-ender"
        },
        "entity": ["General Ahamkara"],
        "speaker": None,
        "tags": ["exotic", "weapon", "bow", "sjur-eido", "shattered-throne", "great-hunt"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "weapon-buried-bloodline",
        "api_path": "/entries/buried-bloodline",
        "doc_type": "entry",
        "title": "Buried Bloodline",
        "source": {
            "type": "exotic_weapon",
            "game": "Destiny 2",
            "book": None,
            "release": "Season of the Wish",
            "bungie_ref": 322639148,
            "ishtar_url": "https://www.ishtar-collective.net/entries/buried-bloodline"
        },
        "entity": ["Hefnd"],
        "speaker": "Hefnd",
        "tags": ["exotic", "weapon", "sidearm", "void", "hefnd", "warlords-ruin", "scorn"],
        "chronology": "Dark Age & Early City Age",
        "theme": "Vengeance & Twisted Desires"
    },

    # 3. Last Wish Raid Weapons (8 entries)
    {
        "id": "raid-weapon-apex-predator",
        "api_path": "/entries/apex-predator",
        "doc_type": "entry",
        "title": "Apex Predator",
        "source": {
            "type": "raid_weapon",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 1851777734,
            "ishtar_url": "https://www.ishtar-collective.net/entries/apex-predator"
        },
        "entity": ["Unnamed Great Hunt Dragons"],
        "speaker": "Lord Saladin",
        "tags": ["raid", "weapon", "rocket-launcher", "last-wish", "great-hunt", "saladin"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "raid-weapon-age-old-bond",
        "api_path": "/entries/age-old-bond",
        "doc_type": "entry",
        "title": "Age-Old Bond",
        "source": {
            "type": "raid_weapon",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 1851777735,
            "ishtar_url": "https://www.ishtar-collective.net/entries/age-old-bond"
        },
        "entity": ["Unnamed Great Hunt Dragons"],
        "speaker": "Liu Feng",
        "tags": ["raid", "weapon", "auto-rifle", "last-wish", "great-hunt", "liu-feng", "ouros"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "raid-weapon-transfiguration",
        "api_path": "/entries/transfiguration",
        "doc_type": "entry",
        "title": "Transfiguration",
        "source": {
            "type": "raid_weapon",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 1851777736,
            "ishtar_url": "https://www.ishtar-collective.net/entries/transfiguration"
        },
        "entity": ["Unnamed Great Hunt Dragons"],
        "speaker": "Taeko-3",
        "tags": ["raid", "weapon", "scout-rifle", "last-wish", "great-hunt", "taeko-3", "vex"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "raid-weapon-nation-of-beasts",
        "api_path": "/entries/nation-of-beasts",
        "doc_type": "entry",
        "title": "Nation of Beasts",
        "source": {
            "type": "raid_weapon",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 1851777737,
            "ishtar_url": "https://www.ishtar-collective.net/entries/nation-of-beasts"
        },
        "entity": ["Unnamed Great Hunt Dragons"],
        "speaker": "Pahanin",
        "tags": ["raid", "weapon", "hand-cannon", "last-wish", "great-hunt", "pahanin", "kabr", "praedyth"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "raid-weapon-techeun-force",
        "api_path": "/entries/techeun-force",
        "doc_type": "entry",
        "title": "Techeun Force",
        "source": {
            "type": "raid_weapon",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 1851777738,
            "ishtar_url": "https://www.ishtar-collective.net/entries/techeun-force"
        },
        "entity": ["Riven"],
        "speaker": "Kalli",
        "tags": ["raid", "weapon", "fusion-rifle", "last-wish", "techeun", "kalli", "sedia", "shuro-chi"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "Anthem Anatheme & Wish-Bargains"
    },
    {
        "id": "raid-weapon-chattering-bone",
        "api_path": "/entries/chattering-bone",
        "doc_type": "entry",
        "title": "Chattering Bone",
        "source": {
            "type": "raid_weapon",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 1851777739,
            "ishtar_url": "https://www.ishtar-collective.net/entries/chattering-bone"
        },
        "entity": ["Unnamed Great Hunt Dragons"],
        "speaker": "Tallulah Fairwind",
        "tags": ["raid", "weapon", "pulse-rifle", "last-wish", "great-hunt", "tallulah-fairwind", "cards"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "raid-weapon-tyranny-of-heaven",
        "api_path": "/entries/tyranny-of-heaven",
        "doc_type": "entry",
        "title": "Tyranny of Heaven",
        "source": {
            "type": "raid_weapon",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 1851777740,
            "ishtar_url": "https://www.ishtar-collective.net/entries/tyranny-of-heaven"
        },
        "entity": ["Unnamed Great Hunt Dragons"],
        "speaker": "Nadiya",
        "tags": ["raid", "weapon", "bow", "last-wish", "great-hunt", "nadiya", "shinobu"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "raid-weapon-the-supremacy",
        "api_path": "/entries/the-supremacy",
        "doc_type": "entry",
        "title": "The Supremacy",
        "source": {
            "type": "raid_weapon",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 1851777741,
            "ishtar_url": "https://www.ishtar-collective.net/entries/the-supremacy"
        },
        "entity": ["Unnamed Great Hunt Dragons"],
        "speaker": "Lady Efrideet",
        "tags": ["raid", "weapon", "sniper-rifle", "last-wish", "great-hunt", "efrideet"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "The Great Hunt & Extinction"
    },

    # 4. Great Hunt Raid Armor (15 entries)
    {
        "id": "great-hunt-helm",
        "api_path": "/entries/helm-of-the-great-hunt",
        "doc_type": "entry",
        "title": "Helm of the Great Hunt",
        "source": {
            "type": "raid_armor",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 3489117621,
            "ishtar_url": "https://www.ishtar-collective.net/entries/helm-of-the-great-hunt"
        },
        "entity": ["Riven"],
        "speaker": "Lord Shaxx",
        "tags": ["raid", "armor", "titan", "helmet", "shaxx", "mara-sov", "wall-of-wishes"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "great-hunt-gauntlets",
        "api_path": "/entries/gauntlets-of-the-great-hunt",
        "doc_type": "entry",
        "title": "Gauntlets of the Great Hunt",
        "source": {
            "type": "raid_armor",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 3489117622,
            "ishtar_url": "https://www.ishtar-collective.net/entries/gauntlets-of-the-great-hunt"
        },
        "entity": ["Riven"],
        "speaker": "Lord Shaxx",
        "tags": ["raid", "armor", "titan", "gauntlets", "shaxx", "mara-sov", "wall-of-wishes"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "great-hunt-plate",
        "api_path": "/entries/plate-of-the-great-hunt",
        "doc_type": "entry",
        "title": "Plate of the Great Hunt",
        "source": {
            "type": "raid_armor",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 3489117623,
            "ishtar_url": "https://www.ishtar-collective.net/entries/plate-of-the-great-hunt"
        },
        "entity": ["Riven"],
        "speaker": "Lord Shaxx",
        "tags": ["raid", "armor", "titan", "chest", "shaxx", "mara-sov", "tempest"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "great-hunt-greaves",
        "api_path": "/entries/greaves-of-the-great-hunt",
        "doc_type": "entry",
        "title": "Greaves of the Great Hunt",
        "source": {
            "type": "raid_armor",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 3489117624,
            "ishtar_url": "https://www.ishtar-collective.net/entries/greaves-of-the-great-hunt"
        },
        "entity": ["Riven"],
        "speaker": "Lord Shaxx",
        "tags": ["raid", "armor", "titan", "legs", "shaxx", "mara-sov"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "great-hunt-mark",
        "api_path": "/entries/mark-of-the-great-hunt",
        "doc_type": "entry",
        "title": "Mark of the Great Hunt",
        "source": {
            "type": "raid_armor",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 3489117625,
            "ishtar_url": "https://www.ishtar-collective.net/entries/mark-of-the-great-hunt"
        },
        "entity": ["Riven"],
        "speaker": "Lord Shaxx",
        "tags": ["raid", "armor", "titan", "mark", "shaxx", "mara-sov", "book"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "great-hunt-mask",
        "api_path": "/entries/mask-of-the-great-hunt",
        "doc_type": "entry",
        "title": "Mask of the Great Hunt",
        "source": {
            "type": "raid_armor",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 3489117626,
            "ishtar_url": "https://www.ishtar-collective.net/entries/mask-of-the-great-hunt"
        },
        "entity": ["Unnamed Great Hunt Dragons"],
        "speaker": "Wei Ning",
        "tags": ["raid", "armor", "hunter", "helmet", "wei-ning", "eriana-3", "great-hunt"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "great-hunt-grips",
        "api_path": "/entries/grips-of-the-great-hunt",
        "doc_type": "entry",
        "title": "Grips of the Great Hunt",
        "source": {
            "type": "raid_armor",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 3489117627,
            "ishtar_url": "https://www.ishtar-collective.net/entries/grips-of-the-great-hunt"
        },
        "entity": ["Unnamed Great Hunt Dragons"],
        "speaker": "Eriana-3",
        "tags": ["raid", "armor", "hunter", "gauntlets", "wei-ning", "eriana-3", "great-hunt"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "great-hunt-vest",
        "api_path": "/entries/vest-of-the-great-hunt",
        "doc_type": "entry",
        "title": "Vest of the Great Hunt",
        "source": {
            "type": "raid_armor",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 3489117628,
            "ishtar_url": "https://www.ishtar-collective.net/entries/vest-of-the-great-hunt"
        },
        "entity": ["Unnamed Great Hunt Dragons"],
        "speaker": "Eriana-3",
        "tags": ["raid", "armor", "hunter", "chest", "wei-ning", "eriana-3", "moon"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "great-hunt-strides",
        "api_path": "/entries/strides-of-the-great-hunt",
        "doc_type": "entry",
        "title": "Strides of the Great Hunt",
        "source": {
            "type": "raid_armor",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 3489117629,
            "ishtar_url": "https://www.ishtar-collective.net/entries/strides-of-the-great-hunt"
        },
        "entity": ["Unnamed Great Hunt Dragons"],
        "speaker": "Eriana-3",
        "tags": ["raid", "armor", "hunter", "legs", "wei-ning", "eriana-3", "venus"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "great-hunt-cloak",
        "api_path": "/entries/cloak-of-the-great-hunt",
        "doc_type": "entry",
        "title": "Cloak of the Great Hunt",
        "source": {
            "type": "raid_armor",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 3489117630,
            "ishtar_url": "https://www.ishtar-collective.net/entries/cloak-of-the-great-hunt"
        },
        "entity": ["Unnamed Great Hunt Dragons"],
        "speaker": "Eriana-3",
        "tags": ["raid", "armor", "hunter", "cloak", "wei-ning", "eriana-3", "sorrow"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "great-hunt-hood",
        "api_path": "/entries/hood-of-the-great-hunt",
        "doc_type": "entry",
        "title": "Hood of the Great Hunt",
        "source": {
            "type": "raid_armor",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 3489117631,
            "ishtar_url": "https://www.ishtar-collective.net/entries/hood-of-the-great-hunt"
        },
        "entity": ["Riven"],
        "speaker": "Riven of a Thousand Voices",
        "tags": ["raid", "armor", "warlock", "helmet", "riven", "mara-sov", "dreaming-city"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "Anthem Anatheme & Wish-Bargains"
    },
    {
        "id": "great-hunt-gloves",
        "api_path": "/entries/gloves-of-the-great-hunt",
        "doc_type": "entry",
        "title": "Gloves of the Great Hunt",
        "source": {
            "type": "raid_armor",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 3489117632,
            "ishtar_url": "https://www.ishtar-collective.net/entries/gloves-of-the-great-hunt"
        },
        "entity": ["Riven"],
        "speaker": "Riven of a Thousand Voices",
        "tags": ["raid", "armor", "warlock", "gloves", "riven", "mara-sov", "covenant"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "Anthem Anatheme & Wish-Bargains"
    },
    {
        "id": "great-hunt-robes",
        "api_path": "/entries/robes-of-the-great-hunt",
        "doc_type": "entry",
        "title": "Robes of the Great Hunt",
        "source": {
            "type": "raid_armor",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 3489117633,
            "ishtar_url": "https://www.ishtar-collective.net/entries/robes-of-the-great-hunt"
        },
        "entity": ["Riven"],
        "speaker": "Riven of a Thousand Voices",
        "tags": ["raid", "armor", "warlock", "chest", "riven", "oryx", "taken"],
        "chronology": "The Taken War",
        "theme": "Anthem Anatheme & Wish-Bargains"
    },
    {
        "id": "great-hunt-boots",
        "api_path": "/entries/boots-of-the-great-hunt",
        "doc_type": "entry",
        "title": "Boots of the Great Hunt",
        "source": {
            "type": "raid_armor",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 3489117634,
            "ishtar_url": "https://www.ishtar-collective.net/entries/boots-of-the-great-hunt"
        },
        "entity": ["Riven"],
        "speaker": "Riven of a Thousand Voices",
        "tags": ["raid", "armor", "warlock", "legs", "riven", "savathun", "curse"],
        "chronology": "The Taken War",
        "theme": "Anthem Anatheme & Wish-Bargains"
    },
    {
        "id": "great-hunt-bond",
        "api_path": "/entries/bond-of-the-great-hunt",
        "doc_type": "entry",
        "title": "Bond of the Great Hunt",
        "source": {
            "type": "raid_armor",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 3489117635,
            "ishtar_url": "https://www.ishtar-collective.net/entries/bond-of-the-great-hunt"
        },
        "entity": ["Riven"],
        "speaker": "Riven of a Thousand Voices",
        "tags": ["raid", "armor", "warlock", "bond", "riven", "guardians", "revenge"],
        "chronology": "Forsaken & The Dreaming City Curse",
        "theme": "Anthem Anatheme & Wish-Bargains"
    },

    # 5. Warlord's Ruin Gear & Records (5 entries)
    {
        "id": "warlord-vengeful-whisper",
        "api_path": "/items/vengeful-whisper",
        "doc_type": "item",
        "title": "Vengeful Whisper",
        "source": {
            "type": "quest_lore",
            "game": "Destiny 2",
            "book": None,
            "release": "Season of the Wish",
            "bungie_ref": 2728448550,
            "ishtar_url": "https://www.ishtar-collective.net/items/vengeful-whisper"
        },
        "entity": ["Hefnd"],
        "speaker": "Naeem",
        "tags": ["dungeon", "warlords-ruin", "bow", "hefnd", "naeem", "wish-magic"],
        "chronology": "Dark Age & Early City Age",
        "theme": "Vengeance & Twisted Desires"
    },
    {
        "id": "warlord-dragoncult-sickle",
        "api_path": "/items/dragoncult-sickle",
        "doc_type": "item",
        "title": "Dragoncult Sickle",
        "source": {
            "type": "quest_lore",
            "game": "Destiny 2",
            "book": None,
            "release": "Season of the Wish",
            "bungie_ref": 2516499990,
            "ishtar_url": "https://www.ishtar-collective.net/items/dragoncult-sickle"
        },
        "entity": ["Hefnd"],
        "speaker": "Warlord Rath",
        "tags": ["dungeon", "warlords-ruin", "sword", "hefnd", "rath", "dragoncult"],
        "chronology": "Dark Age & Early City Age",
        "theme": "Vengeance & Twisted Desires"
    },
    {
        "id": "warlord-naeems-lance",
        "api_path": "/items/naeems-lance",
        "doc_type": "item",
        "title": "Naeem's Lance",
        "source": {
            "type": "quest_lore",
            "game": "Destiny 2",
            "book": None,
            "release": "Season of the Wish",
            "bungie_ref": 2045585093,
            "ishtar_url": "https://www.ishtar-collective.net/items/naeems-lance"
        },
        "entity": ["Hefnd"],
        "speaker": "Naeem",
        "tags": ["dungeon", "warlords-ruin", "sniper-rifle", "hefnd", "naeem", "bond"],
        "chronology": "Dark Age & Early City Age",
        "theme": "Vengeance & Twisted Desires"
    },
    {
        "id": "warlord-ziras-shell",
        "api_path": "/entries/ziras-shell",
        "doc_type": "entry",
        "title": "Zira's Shell",
        "source": {
            "type": "quest_lore",
            "game": "Destiny 2",
            "book": None,
            "release": "Season of the Wish",
            "bungie_ref": 3232014811,
            "ishtar_url": "https://www.ishtar-collective.net/entries/ziras-shell"
        },
        "entity": ["Hefnd"],
        "speaker": "Zira",
        "tags": ["dungeon", "warlords-ruin", "ghost-shell", "hefnd", "zira", "naeem"],
        "chronology": "Dark Age & Early City Age",
        "theme": "Vengeance & Twisted Desires"
    },
    {
        "id": "warlord-shadow-mountain-8",
        "api_path": "/items/in-the-shadow-of-the-mountain-8",
        "doc_type": "item",
        "title": "In the Shadow of the Mountain: Hefnd's Cairn",
        "source": {
            "type": "quest_lore",
            "game": "Destiny 2",
            "book": None,
            "release": "Season of the Wish",
            "bungie_ref": 825259733,
            "ishtar_url": "https://www.ishtar-collective.net/items/in-the-shadow-of-the-mountain-8"
        },
        "entity": ["Hefnd"],
        "speaker": None,
        "tags": ["dungeon", "warlords-ruin", "quest", "hefnd", "cairn", "bones"],
        "chronology": "Dark Age & Early City Age",
        "theme": "Deathless Bones & Parasitic Whispers"
    },

    # 6. Lore Books (15 entries)
    {
        "id": "book-marasenna-katabasis",
        "api_path": "/entries/katabasis",
        "doc_type": "entry",
        "title": "Marasenna: Katabasis",
        "source": {
            "type": "lore_book",
            "game": "Destiny 2",
            "book": "Marasenna",
            "release": "Forsaken",
            "bungie_ref": 2049926437,
            "ishtar_url": "https://www.ishtar-collective.net/entries/katabasis"
        },
        "entity": ["Riven"],
        "speaker": "Mara Sov",
        "tags": ["lore-book", "marasenna", "katabasis", "riven", "awoken", "dreaming-city"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "Anthem Anatheme & Wish-Bargains"
    },
    {
        "id": "book-marasenna-azirim",
        "api_path": "/entries/azirim",
        "doc_type": "entry",
        "title": "Marasenna: Azirim",
        "source": {
            "type": "lore_book",
            "game": "Destiny 2",
            "book": "Marasenna",
            "release": "Forsaken",
            "bungie_ref": 2049926438,
            "ishtar_url": "https://www.ishtar-collective.net/entries/azirim"
        },
        "entity": ["Azirim"],
        "speaker": "Esila",
        "tags": ["lore-book", "marasenna", "azirim", "cliff-singer", "deceit", "awoken"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "Anthem Anatheme & Wish-Bargains"
    },
    {
        "id": "book-marasenna-fideicide-i",
        "api_path": "/entries/fideicide-i",
        "doc_type": "entry",
        "title": "Marasenna: Fideicide I",
        "source": {
            "type": "lore_book",
            "game": "Destiny 2",
            "book": "Marasenna",
            "release": "Forsaken",
            "bungie_ref": 2049926439,
            "ishtar_url": "https://www.ishtar-collective.net/entries/fideicide-i"
        },
        "entity": ["Riven"],
        "speaker": "Mara Sov",
        "tags": ["lore-book", "marasenna", "fideicide", "riven", "great-hunt", "guardians"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "Anthem Anatheme & Wish-Bargains"
    },
    {
        "id": "book-marasenna-fideicide-ii",
        "api_path": "/entries/fideicide-ii",
        "doc_type": "entry",
        "title": "Marasenna: Fideicide II",
        "source": {
            "type": "lore_book",
            "game": "Destiny 2",
            "book": "Marasenna",
            "release": "Forsaken",
            "bungie_ref": 2049926440,
            "ishtar_url": "https://www.ishtar-collective.net/entries/fideicide-ii"
        },
        "entity": ["Riven"],
        "speaker": "Mara Sov",
        "tags": ["lore-book", "marasenna", "fideicide", "great-hunt", "extinction", "whispers"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "book-marasenna-fideicide-iii",
        "api_path": "/entries/fideicide-iii",
        "doc_type": "entry",
        "title": "Marasenna: Fideicide III",
        "source": {
            "type": "lore_book",
            "game": "Destiny 2",
            "book": "Marasenna",
            "release": "Forsaken",
            "bungie_ref": 2049926441,
            "ishtar_url": "https://www.ishtar-collective.net/entries/fideicide-iii"
        },
        "entity": ["Riven"],
        "speaker": "Mara Sov",
        "tags": ["lore-book", "marasenna", "fideicide", "great-hunt", "extinction"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "book-marasenna-imponent-i",
        "api_path": "/entries/imponent-i",
        "doc_type": "entry",
        "title": "Marasenna: Imponent I",
        "source": {
            "type": "lore_book",
            "game": "Destiny 2",
            "book": "Marasenna",
            "release": "Forsaken",
            "bungie_ref": 2049926442,
            "ishtar_url": "https://www.ishtar-collective.net/entries/imponent-i"
        },
        "entity": ["Riven"],
        "speaker": "Mara Sov",
        "tags": ["lore-book", "marasenna", "imponent", "riven", "bargain", "wish"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "Anthem Anatheme & Wish-Bargains"
    },
    {
        "id": "book-marasenna-imponent-iv",
        "api_path": "/entries/imponent-iv",
        "doc_type": "entry",
        "title": "Marasenna: Imponent IV",
        "source": {
            "type": "lore_book",
            "game": "Destiny 2",
            "book": "Marasenna",
            "release": "Forsaken",
            "bungie_ref": 2049926443,
            "ishtar_url": "https://www.ishtar-collective.net/entries/imponent-iv"
        },
        "entity": ["Riven"],
        "speaker": "Mara Sov",
        "tags": ["lore-book", "marasenna", "imponent", "wall-of-wishes", "techeuns", "riven"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "book-awoken-reef-telic-i",
        "api_path": "/entries/telic-i",
        "doc_type": "entry",
        "title": "The Awoken of the Reef: Telic I",
        "source": {
            "type": "lore_book",
            "game": "Destiny 2",
            "book": "The Awoken of the Reef",
            "release": "Forsaken",
            "bungie_ref": 2049926444,
            "ishtar_url": "https://www.ishtar-collective.net/entries/telic-i"
        },
        "entity": ["Riven"],
        "speaker": "Mara Sov",
        "tags": ["lore-book", "awoken-of-the-reef", "telic", "mara-sov", "riven", "purpose"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "Anthem Anatheme & Wish-Bargains"
    },
    {
        "id": "book-awoken-reef-telic-ii",
        "api_path": "/entries/telic-ii",
        "doc_type": "entry",
        "title": "The Awoken of the Reef: Telic II",
        "source": {
            "type": "lore_book",
            "game": "Destiny 2",
            "book": "The Awoken of the Reef",
            "release": "Forsaken",
            "bungie_ref": 2049926445,
            "ishtar_url": "https://www.ishtar-collective.net/entries/telic-ii"
        },
        "entity": ["Riven"],
        "speaker": "Mara Sov",
        "tags": ["lore-book", "awoken-of-the-reef", "telic", "mara-sov", "riven", "dreaming-city"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "Anthem Anatheme & Wish-Bargains"
    },
    {
        "id": "book-gifts-first-gift",
        "api_path": "/entries/first-gift",
        "doc_type": "entry",
        "title": "Book: Gifts and Bargains — First Gift",
        "source": {
            "type": "lore_book",
            "game": "Destiny 2",
            "book": "Book: Gifts and Bargains",
            "release": "Season of the Wish",
            "bungie_ref": 3617300747,
            "ishtar_url": "https://www.ishtar-collective.net/entries/first-gift"
        },
        "entity": ["Taranis"],
        "speaker": "Taranis",
        "tags": ["lore-book", "gifts-and-bargains", "taranis", "black-garden", "solitude", "clutch"],
        "chronology": "Season of the Wish & The Final Shape",
        "theme": "Parentage & The Uncorrupted Clutch"
    },
    {
        "id": "book-gifts-second-gift",
        "api_path": "/entries/second-gift",
        "doc_type": "entry",
        "title": "Book: Gifts and Bargains — Second Gift",
        "source": {
            "type": "lore_book",
            "game": "Destiny 2",
            "book": "Book: Gifts and Bargains",
            "release": "Season of the Wish",
            "bungie_ref": 3617300748,
            "ishtar_url": "https://www.ishtar-collective.net/entries/second-gift"
        },
        "entity": ["Taranis", "Riven"],
        "speaker": "Taranis",
        "tags": ["lore-book", "gifts-and-bargains", "taranis", "riven", "mating", "courtship"],
        "chronology": "Season of the Wish & The Final Shape",
        "theme": "Parentage & The Uncorrupted Clutch"
    },
    {
        "id": "book-gifts-third-gift",
        "api_path": "/entries/third-gift",
        "doc_type": "entry",
        "title": "Book: Gifts and Bargains — Third Gift",
        "source": {
            "type": "lore_book",
            "game": "Destiny 2",
            "book": "Book: Gifts and Bargains",
            "release": "Season of the Wish",
            "bungie_ref": 3617300749,
            "ishtar_url": "https://www.ishtar-collective.net/entries/third-gift"
        },
        "entity": ["Taranis", "Riven"],
        "speaker": "Taranis",
        "tags": ["lore-book", "gifts-and-bargains", "taranis", "riven", "separation", "clutch"],
        "chronology": "Season of the Wish & The Final Shape",
        "theme": "Parentage & The Uncorrupted Clutch"
    },
    {
        "id": "book-gifts-last-bargain",
        "api_path": "/entries/last-bargain",
        "doc_type": "entry",
        "title": "Book: Gifts and Bargains — Last Bargain",
        "source": {
            "type": "lore_book",
            "game": "Destiny 2",
            "book": "Book: Gifts and Bargains",
            "release": "Season of the Wish",
            "bungie_ref": 3617300750,
            "ishtar_url": "https://www.ishtar-collective.net/entries/last-bargain"
        },
        "entity": ["Taranis"],
        "speaker": "Taranis",
        "tags": ["lore-book", "gifts-and-bargains", "taranis", "self-sacrifice", "wish", "eggs"],
        "chronology": "Season of the Wish & The Final Shape",
        "theme": "Parentage & The Uncorrupted Clutch"
    },
    {
        "id": "lore-lethophobia",
        "api_path": "/entries/lethophobia",
        "doc_type": "entry",
        "title": "Lethophobia",
        "source": {
            "type": "lore_book",
            "game": "Destiny 2",
            "book": None,
            "release": "Season of the Wish",
            "bungie_ref": 3719914480,
            "ishtar_url": "https://www.ishtar-collective.net/entries/lethophobia"
        },
        "entity": ["Huginn", "Muninn"],
        "speaker": "Sjur Eido",
        "tags": ["lore", "bow", "huginn", "muninn", "sjur-eido", "skulls", "extinction"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "lore-oathkeeper",
        "api_path": "/entries/oathkeeper",
        "doc_type": "entry",
        "title": "Oathkeeper",
        "source": {
            "type": "lore_book",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 3719914481,
            "ishtar_url": "https://www.ishtar-collective.net/entries/oathkeeper"
        },
        "entity": ["Huginn", "Muninn"],
        "speaker": "Sjur Eido",
        "tags": ["lore", "hunter", "gauntlets", "huginn", "muninn", "sjur-eido", "covenant"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "Deathless Bones & Parasitic Whispers"
    },

    # 7. Wall of Wishes (15 entries)
    {
        "id": "wish-wall-first-wish",
        "api_path": "/entries/first-wish",
        "doc_type": "entry",
        "title": "First Wish: A wish to feed an addiction",
        "source": {
            "type": "wall_of_wishes",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 2049926451,
            "ishtar_url": "https://www.ishtar-collective.net/entries/first-wish"
        },
        "entity": ["Riven"],
        "speaker": "The Wall of Wishes",
        "tags": ["wall-of-wishes", "last-wish", "plate", "ethereal-key", "riven"],
        "chronology": "Forsaken & The Dreaming City Curse",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "wish-wall-second-wish",
        "api_path": "/entries/second-wish",
        "doc_type": "entry",
        "title": "Second Wish: A wish for material validation",
        "source": {
            "type": "wall_of_wishes",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 2049926452,
            "ishtar_url": "https://www.ishtar-collective.net/entries/second-wish"
        },
        "entity": ["Riven"],
        "speaker": "The Wall of Wishes",
        "tags": ["wall-of-wishes", "last-wish", "plate", "glittering-key", "riven"],
        "chronology": "Forsaken & The Dreaming City Curse",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "wish-wall-third-wish",
        "api_path": "/entries/third-wish",
        "doc_type": "entry",
        "title": "Third Wish: A wish for others to celebrate your success",
        "source": {
            "type": "wall_of_wishes",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 2049926453,
            "ishtar_url": "https://www.ishtar-collective.net/entries/third-wish"
        },
        "entity": ["Riven"],
        "speaker": "The Wall of Wishes",
        "tags": ["wall-of-wishes", "last-wish", "plate", "emblem", "riven"],
        "chronology": "Forsaken & The Dreaming City Curse",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "wish-wall-fourth-wish",
        "api_path": "/entries/fourth-wish",
        "doc_type": "entry",
        "title": "Fourth Wish: A wish to look athletic and sleek",
        "source": {
            "type": "wall_of_wishes",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 2049926454,
            "ishtar_url": "https://www.ishtar-collective.net/entries/fourth-wish"
        },
        "entity": ["Riven"],
        "speaker": "The Wall of Wishes",
        "tags": ["wall-of-wishes", "last-wish", "plate", "shuro-chi", "warp", "riven"],
        "chronology": "Forsaken & The Dreaming City Curse",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "wish-wall-fifth-wish",
        "api_path": "/entries/fifth-wish",
        "doc_type": "entry",
        "title": "Fifth Wish: A wish for a promising future",
        "source": {
            "type": "wall_of_wishes",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 2049926455,
            "ishtar_url": "https://www.ishtar-collective.net/entries/fifth-wish"
        },
        "entity": ["Riven"],
        "speaker": "The Wall of Wishes",
        "tags": ["wall-of-wishes", "last-wish", "plate", "morgeth", "warp", "riven"],
        "chronology": "Forsaken & The Dreaming City Curse",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "wish-wall-sixth-wish",
        "api_path": "/entries/sixth-wish",
        "doc_type": "entry",
        "title": "Sixth Wish: A wish to move the hands of time",
        "source": {
            "type": "wall_of_wishes",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 2049926456,
            "ishtar_url": "https://www.ishtar-collective.net/entries/sixth-wish"
        },
        "entity": ["Riven"],
        "speaker": "The Wall of Wishes",
        "tags": ["wall-of-wishes", "last-wish", "plate", "vault", "warp", "riven"],
        "chronology": "Forsaken & The Dreaming City Curse",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "wish-wall-seventh-wish",
        "api_path": "/entries/seventh-wish",
        "doc_type": "entry",
        "title": "Seventh Wish: A wish to help a friend in need",
        "source": {
            "type": "wall_of_wishes",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 2049926457,
            "ishtar_url": "https://www.ishtar-collective.net/entries/seventh-wish"
        },
        "entity": ["Riven"],
        "speaker": "The Wall of Wishes",
        "tags": ["wall-of-wishes", "last-wish", "plate", "riven", "warp"],
        "chronology": "Forsaken & The Dreaming City Curse",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "wish-wall-eighth-wish",
        "api_path": "/entries/eighth-wish",
        "doc_type": "entry",
        "title": "Eighth Wish: A wish to stay here forever",
        "source": {
            "type": "wall_of_wishes",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 2049926458,
            "ishtar_url": "https://www.ishtar-collective.net/entries/eighth-wish"
        },
        "entity": ["Riven"],
        "speaker": "The Wall of Wishes",
        "tags": ["wall-of-wishes", "last-wish", "plate", "paul-mccartney", "easter-egg"],
        "chronology": "Forsaken & The Dreaming City Curse",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "wish-wall-ninth-wish",
        "api_path": "/entries/ninth-wish",
        "doc_type": "entry",
        "title": "Ninth Wish: A wish to stay here forever",
        "source": {
            "type": "wall_of_wishes",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 2049926459,
            "ishtar_url": "https://www.ishtar-collective.net/entries/ninth-wish"
        },
        "entity": ["Riven"],
        "speaker": "The Wall of Wishes",
        "tags": ["wall-of-wishes", "last-wish", "plate", "failsafe", "dialogue"],
        "chronology": "Forsaken & The Dreaming City Curse",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "wish-wall-tenth-wish",
        "api_path": "/entries/tenth-wish",
        "doc_type": "entry",
        "title": "Tenth Wish: A wish for the common good",
        "source": {
            "type": "wall_of_wishes",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 2049926460,
            "ishtar_url": "https://www.ishtar-collective.net/entries/tenth-wish"
        },
        "entity": ["Riven"],
        "speaker": "The Wall of Wishes",
        "tags": ["wall-of-wishes", "last-wish", "plate", "drifter", "dialogue"],
        "chronology": "Forsaken & The Dreaming City Curse",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "wish-wall-eleventh-wish",
        "api_path": "/entries/eleventh-wish",
        "doc_type": "entry",
        "title": "Eleventh Wish: A wish to stay here forever",
        "source": {
            "type": "wall_of_wishes",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 2049926461,
            "ishtar_url": "https://www.ishtar-collective.net/entries/eleventh-wish"
        },
        "entity": ["Riven"],
        "speaker": "The Wall of Wishes",
        "tags": ["wall-of-wishes", "last-wish", "plate", "grunt-birthday", "easter-egg"],
        "chronology": "Forsaken & The Dreaming City Curse",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "wish-wall-twelfth-wish",
        "api_path": "/entries/twelfth-wish",
        "doc_type": "entry",
        "title": "Twelfth Wish: A wish to open your mind to new ideas",
        "source": {
            "type": "wall_of_wishes",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 2049926462,
            "ishtar_url": "https://www.ishtar-collective.net/entries/twelfth-wish"
        },
        "entity": ["Riven"],
        "speaker": "The Wall of Wishes",
        "tags": ["wall-of-wishes", "last-wish", "plate", "butterflies", "cosmetic"],
        "chronology": "Forsaken & The Dreaming City Curse",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "wish-wall-thirteenth-wish",
        "api_path": "/entries/thirteenth-wish",
        "doc_type": "entry",
        "title": "Thirteenth Wish: A wish for the means to feed an addiction",
        "source": {
            "type": "wall_of_wishes",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 2049926463,
            "ishtar_url": "https://www.ishtar-collective.net/entries/thirteenth-wish"
        },
        "entity": ["Riven"],
        "speaker": "The Wall of Wishes",
        "tags": ["wall-of-wishes", "last-wish", "plate", "petras-run", "flawless"],
        "chronology": "Forsaken & The Dreaming City Curse",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "wish-wall-fourteenth-wish",
        "api_path": "/entries/fourteenth-wish",
        "doc_type": "entry",
        "title": "Fourteenth Wish: A wish for love and support",
        "source": {
            "type": "wall_of_wishes",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": 2049926464,
            "ishtar_url": "https://www.ishtar-collective.net/entries/fourteenth-wish"
        },
        "entity": ["Riven"],
        "speaker": "The Wall of Wishes",
        "tags": ["wall-of-wishes", "last-wish", "plate", "corrupted-eggs", "taken-eggs"],
        "chronology": "Forsaken & The Dreaming City Curse",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "wish-wall-fifteenth-wish",
        "api_path": "/entries/fifteenth-wish",
        "doc_type": "entry",
        "title": "Fifteenth Wish: \"This one you shall cherish.\"",
        "source": {
            "type": "wall_of_wishes",
            "game": "Destiny 2",
            "book": None,
            "release": "Season of the Wish",
            "bungie_ref": 2049926465,
            "ishtar_url": "https://www.ishtar-collective.net/entries/fifteenth-wish"
        },
        "entity": ["Riven"],
        "speaker": "Riven of a Thousand Voices",
        "tags": ["wall-of-wishes", "fifteenth-wish", "cherish", "pale-heart", "last-wish", "curse"],
        "chronology": "Forsaken & The Dreaming City Curse",
        "theme": "The Wall of Wishes & Coded Desire"
    },

    # 8. Grimoire Cards (10 entries)
    {
        "id": "grimoire-ghost-fragment-legends-3",
        "api_path": "/cards/ghost-fragment-legends-3",
        "doc_type": "grimoire_card",
        "title": "Ghost Fragment: Legends 3 — The Great Ahamkara Hunt",
        "source": {
            "type": "grimoire_card",
            "game": "Destiny 1",
            "book": None,
            "release": "The Dark Below",
            "bungie_ref": 103090,
            "ishtar_url": "https://www.ishtar-collective.net/cards/ghost-fragment-legends-3"
        },
        "entity": ["General Ahamkara"],
        "speaker": None,
        "tags": ["grimoire", "destiny-1", "great-hunt", "extinction", "bargains"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "grimoire-ghost-fragment-warlock",
        "api_path": "/cards/ghost-fragment-warlock",
        "doc_type": "grimoire_card",
        "title": "Ghost Fragment: Warlock — Venus Hunt",
        "source": {
            "type": "grimoire_card",
            "game": "Destiny 1",
            "book": None,
            "release": "The Dark Below",
            "bungie_ref": 104030,
            "ishtar_url": "https://www.ishtar-collective.net/cards/ghost-fragment-warlock"
        },
        "entity": ["General Ahamkara"],
        "speaker": "Warlock Hunter",
        "tags": ["grimoire", "destiny-1", "warlock", "venus", "great-hunt", "bargain"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "grimoire-ghost-fragment-hunter",
        "api_path": "/cards/ghost-fragment-hunter",
        "doc_type": "grimoire_card",
        "title": "Ghost Fragment: Hunter — Whispering Spine",
        "source": {
            "type": "grimoire_card",
            "game": "Destiny 1",
            "book": None,
            "release": "The Dark Below",
            "bungie_ref": 104020,
            "ishtar_url": "https://www.ishtar-collective.net/cards/ghost-fragment-hunter"
        },
        "entity": ["General Ahamkara"],
        "speaker": "Pahanin",
        "tags": ["grimoire", "destiny-1", "hunter", "bones", "whispers", "pahanin"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "Deathless Bones & Parasitic Whispers"
    },
    {
        "id": "grimoire-ghost-fragment-titan",
        "api_path": "/cards/ghost-fragment-titan",
        "doc_type": "grimoire_card",
        "title": "Ghost Fragment: Titan — Caution Against Bargains",
        "source": {
            "type": "grimoire_card",
            "game": "Destiny 1",
            "book": None,
            "release": "The Dark Below",
            "bungie_ref": 104010,
            "ishtar_url": "https://www.ishtar-collective.net/cards/ghost-fragment-titan"
        },
        "entity": ["General Ahamkara"],
        "speaker": "Titan Hunter",
        "tags": ["grimoire", "destiny-1", "titan", "great-hunt", "caution", "bargains"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "grimoire-ghost-fragment-the-city-age",
        "api_path": "/cards/ghost-fragment-the-city-age",
        "doc_type": "grimoire_card",
        "title": "Ghost Fragment: The City Age",
        "source": {
            "type": "grimoire_card",
            "game": "Destiny 1",
            "book": None,
            "release": "The Dark Below",
            "bungie_ref": 107010,
            "ishtar_url": "https://www.ishtar-collective.net/cards/ghost-fragment-the-city-age"
        },
        "entity": ["General Ahamkara"],
        "speaker": None,
        "tags": ["grimoire", "destiny-1", "city-age", "consensus", "hunting-dragons"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "grimoire-lord-gheleon",
        "api_path": "/cards/lord-gheleon",
        "doc_type": "grimoire_card",
        "title": "Lord Gheleon",
        "source": {
            "type": "grimoire_card",
            "game": "Destiny 1",
            "book": None,
            "release": "House of Wolves",
            "bungie_ref": 108030,
            "ishtar_url": "https://www.ishtar-collective.net/cards/lord-gheleon"
        },
        "entity": ["General Ahamkara"],
        "speaker": "Lord Gheleon",
        "tags": ["grimoire", "destiny-1", "iron-lords", "gheleon", "bone-carving"],
        "chronology": "The Great Ahamkara Hunt",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "grimoire-osiris",
        "api_path": "/cards/osiris",
        "doc_type": "grimoire_card",
        "title": "Osiris",
        "source": {
            "type": "grimoire_card",
            "game": "Destiny 1",
            "book": None,
            "release": "House of Wolves",
            "bungie_ref": 108020,
            "ishtar_url": "https://www.ishtar-collective.net/cards/osiris"
        },
        "entity": ["General Ahamkara"],
        "speaker": "Osiris",
        "tags": ["grimoire", "destiny-1", "osiris", "caldera", "bargains", "conspiracy"],
        "chronology": "Dark Age & Early City Age",
        "theme": "Anthem Anatheme & Wish-Bargains"
    },
    {
        "id": "grimoire-sorrow-viii-leviathan",
        "api_path": "/cards/viii-leviathan",
        "doc_type": "grimoire_card",
        "title": "Books of Sorrow VIII: Leviathan",
        "source": {
            "type": "grimoire_card",
            "game": "Destiny 1",
            "book": "Books of Sorrow",
            "release": "The Taken King",
            "bungie_ref": 700180,
            "ishtar_url": "https://www.ishtar-collective.net/cards/viii-leviathan"
        },
        "entity": ["Harmony Wish-Dragons"],
        "speaker": "Leviathan",
        "tags": ["grimoire", "books-of-sorrow", "fundament", "leviathan", "sky-and-deep"],
        "chronology": "Pre-Collapse & Ancient Origins",
        "theme": "Anthem Anatheme & Wish-Bargains"
    },
    {
        "id": "grimoire-sorrow-xlv-cells",
        "api_path": "/cards/xlv-id-shut-them-all-in-cells",
        "doc_type": "grimoire_card",
        "title": "Books of Sorrow XLV: I'd shut them all in cells.",
        "source": {
            "type": "grimoire_card",
            "game": "Destiny 1",
            "book": "Books of Sorrow",
            "release": "The Taken King",
            "bungie_ref": 701310,
            "ishtar_url": "https://www.ishtar-collective.net/cards/xlv-id-shut-them-all-in-cells"
        },
        "entity": ["Harmony Wish-Dragons"],
        "speaker": "Savathûn",
        "tags": ["grimoire", "books-of-sorrow", "savathun", "harmony", "wish-dragons"],
        "chronology": "Pre-Collapse & Ancient Origins",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "grimoire-sorrow-xlvi-gift-mast",
        "api_path": "/cards/xlvi-the-gift-mast",
        "doc_type": "grimoire_card",
        "title": "Books of Sorrow XLVI: The Gift Mast",
        "source": {
            "type": "grimoire_card",
            "game": "Destiny 1",
            "book": "Books of Sorrow",
            "release": "The Taken King",
            "bungie_ref": 701320,
            "ishtar_url": "https://www.ishtar-collective.net/cards/xlvi-the-gift-mast"
        },
        "entity": ["Harmony Wish-Dragons"],
        "speaker": "Oryx",
        "tags": ["grimoire", "books-of-sorrow", "oryx", "harmony", "gift-mast", "dragons"],
        "chronology": "Pre-Collapse & Ancient Origins",
        "theme": "The Great Hunt & Extinction"
    },

    # 9. Dialogue & Transcripts (7 entries)
    {
        "id": "transcript-last-wish-introduction",
        "api_path": "/transcripts/last-wish-introduction",
        "doc_type": "transcript",
        "title": "Last Wish: Introduction",
        "source": {
            "type": "dialogue_transcript",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": None,
            "ishtar_url": "https://www.ishtar-collective.net/transcripts/last-wish-introduction"
        },
        "entity": ["Riven"],
        "speaker": "Petra Venj",
        "tags": ["transcript", "last-wish", "petra-venj", "mara-sov", "dreaming-city"],
        "chronology": "Forsaken & The Dreaming City Curse",
        "theme": "Anthem Anatheme & Wish-Bargains"
    },
    {
        "id": "transcript-last-wish-cinematic",
        "api_path": "/transcripts/last-wish-cinematic",
        "doc_type": "transcript",
        "title": "Last Wish: Cinematic & Post-Raid Unleashing",
        "source": {
            "type": "dialogue_transcript",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": None,
            "ishtar_url": "https://www.ishtar-collective.net/transcripts/last-wish-cinematic"
        },
        "entity": ["Riven"],
        "speaker": "Riven of a Thousand Voices",
        "tags": ["transcript", "last-wish", "cinematic", "curse-unleashed", "riven"],
        "chronology": "Forsaken & The Dreaming City Curse",
        "theme": "Anthem Anatheme & Wish-Bargains"
    },
    {
        "id": "transcript-pilgrimage-eaos-nest",
        "api_path": "/transcripts/pilgrimage-harbingers-seclude-eaos-nest",
        "doc_type": "transcript",
        "title": "Pilgrimage: Harbinger's Seclude, Eao's Nest",
        "source": {
            "type": "dialogue_transcript",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": None,
            "ishtar_url": "https://www.ishtar-collective.net/transcripts/pilgrimage-harbingers-seclude-eaos-nest"
        },
        "entity": ["Eao"],
        "speaker": "Techeun Kalli",
        "tags": ["transcript", "pilgrimage", "eao", "geode", "nest", "dreaming-city"],
        "chronology": "Dark Age & Early City Age",
        "theme": "The Great Hunt & Extinction"
    },
    {
        "id": "transcript-pilgrimage-tree-esila",
        "api_path": "/transcripts/pilgrimage-garden-of-esila-tree",
        "doc_type": "transcript",
        "title": "Pilgrimage: Garden of Esila, Tree of Azirim",
        "source": {
            "type": "dialogue_transcript",
            "game": "Destiny 2",
            "book": None,
            "release": "Forsaken",
            "bungie_ref": None,
            "ishtar_url": "https://www.ishtar-collective.net/transcripts/pilgrimage-garden-of-esila-tree"
        },
        "entity": ["Azirim"],
        "speaker": "Techeun Sedia",
        "tags": ["transcript", "pilgrimage", "azirim", "esila", "tree", "dreaming-city"],
        "chronology": "Reef Golden Age & The Dreaming City",
        "theme": "Anthem Anatheme & Wish-Bargains"
    },
    {
        "id": "transcript-tales-osiris-crow",
        "api_path": "/transcripts/ahamkara-tales-osiris-crow-week-1",
        "doc_type": "transcript",
        "title": "Ahamkara Tales: Osiris & Crow",
        "source": {
            "type": "dialogue_transcript",
            "game": "Destiny 2",
            "book": None,
            "release": "Season of the Wish",
            "bungie_ref": None,
            "ishtar_url": "https://www.ishtar-collective.net/transcripts/ahamkara-tales-osiris-crow-week-1"
        },
        "entity": ["Riven", "Taranis"],
        "speaker": "Osiris & Crow",
        "tags": ["transcript", "radio", "osiris", "crow", "taranis", "season-of-the-wish"],
        "chronology": "Season of the Wish & The Final Shape",
        "theme": "Parentage & The Uncorrupted Clutch"
    },
    {
        "id": "transcript-tales-shaxx-mara",
        "api_path": "/transcripts/ahamkara-tales-shaxx-mara-week-2",
        "doc_type": "transcript",
        "title": "Ahamkara Tales: Shaxx & Mara",
        "source": {
            "type": "dialogue_transcript",
            "game": "Destiny 2",
            "book": None,
            "release": "Season of the Wish",
            "bungie_ref": None,
            "ishtar_url": "https://www.ishtar-collective.net/transcripts/ahamkara-tales-shaxx-mara-week-2"
        },
        "entity": ["Riven"],
        "speaker": "Lord Shaxx & Mara Sov",
        "tags": ["transcript", "radio", "shaxx", "mara-sov", "great-hunt", "trophy"],
        "chronology": "Season of the Wish & The Final Shape",
        "theme": "The Wall of Wishes & Coded Desire"
    },
    {
        "id": "transcript-final-wish-conjure-riven",
        "api_path": "/transcripts/final-wish-conjure-riven",
        "doc_type": "transcript",
        "title": "Final Wish: Conjure Riven",
        "source": {
            "type": "dialogue_transcript",
            "game": "Destiny 2",
            "book": None,
            "release": "Season of the Wish",
            "bungie_ref": None,
            "ishtar_url": "https://www.ishtar-collective.net/transcripts/final-wish-conjure-riven"
        },
        "entity": ["Riven"],
        "speaker": "Mara Sov & Riven",
        "tags": ["transcript", "cutscene", "conjure-riven", "fifteenth-wish", "season-of-the-wish"],
        "chronology": "Season of the Wish & The Final Shape",
        "theme": "Anthem Anatheme & Wish-Bargains"
    }
]


# ==============================================================================
# 3. Normalization & Cleaning Layer
# ==============================================================================

def clean_transcript(raw_text: str) -> str:
    """Normalize raw API transcript text into pure markdown while preserving syntactic brackets.

    Invariants:
    1. HTML block breaks (<br/>, <p>) are converted to Markdown newlines.
    2. HTML formatting (<b>, <strong>, <i>, <em>) is converted to Markdown (** / *).
    3. HTML hyperlinks (<a href="...">...</a>) are converted to [label](url).
    4. Residual HTML tags (<...>) are stripped without altering bracketed text.
    5. HTML entities (&quot;, &#39;, &amp;, &#177;, &#251;) are decoded.
    6. Paracausal square brackets ([The Queen], [bargains], O [Reader] Mine)
       are strictly preserved intact!
    7. Trailing line whitespace is stripped and excess consecutive blank lines collapsed.
    """
    if not raw_text:
        return ""
    text = raw_text.replace("\r\n", "\n").replace("\r", "\n")
    # Structural HTML breaks
    text = re.sub(r"<\s*br\s*/?>\s*<\s*br\s*/?>", "\n\n", text, flags=re.IGNORECASE)
    text = re.sub(r"<\s*br\s*/?>", "\n", text, flags=re.IGNORECASE)
    text = re.sub(r"<\s*p[^>]*>", "\n\n", text, flags=re.IGNORECASE)
    text = re.sub(r"<\s*/\s*p\s*>", "\n\n", text, flags=re.IGNORECASE)
    # Formatting
    text = re.sub(r"<\s*(?:strong|b)\s*>(.*?)</\s*(?:strong|b)\s*>", r"**\1**", text, flags=re.IGNORECASE | re.DOTALL)
    text = re.sub(r"<\s*(?:em|i)\s*>(.*?)</\s*(?:em|i)\s*>", r"*\1*", text, flags=re.IGNORECASE | re.DOTALL)
    text = re.sub(r'<\s*a\s+[^>]*href=["\']([^"\']*)["\'][^>]*>(.*?)<\s*/\s*a\s*>', r"[\2](\1)", text, flags=re.IGNORECASE | re.DOTALL)
    # Strip residual tags (angle brackets only, leaves square brackets [The Queen] intact!)
    text = re.sub(r"<[^>]+>", "", text)
    # Decode HTML entities
    text = html.unescape(text)
    # Normalize whitespace
    lines = [line.rstrip() for line in text.split("\n")]
    text = "\n".join(lines)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def build_record(spec: dict, raw_payload: dict) -> dict:
    """Combine catalog specification and raw API payload into a normalized 9-field record."""
    d = raw_payload.get("data", {})
    desc = d.get("description")
    summary = d.get("short_summary")
    flavor = d.get("flavor_text")

    if spec["doc_type"] == "item":
        parts = []
        if flavor and flavor.strip():
            parts.append(f'"{flavor.strip()}"')
        if summary and summary.strip() and summary.strip() != flavor:
            parts.append(summary.strip())
        elif desc and desc.strip() and desc.strip() != flavor:
            parts.append(desc.strip())
        raw_text = "\n\n".join(parts) if parts else (desc or summary or flavor or "")
    else:
        raw_text = desc or summary or flavor or ""

    transcript = clean_transcript(raw_text)
    if not transcript:
        transcript = f"Canonical record: {spec['title']}"

    bungie_ref = spec["source"].get("bungie_ref")
    if bungie_ref is None and d.get("bungie_ref"):
        bungie_ref = d.get("bungie_ref")

    source_obj = dict(spec["source"])
    source_obj["bungie_ref"] = bungie_ref

    record = {
        "id": spec["id"],
        "title": spec["title"],
        "source": source_obj,
        "entity": spec["entity"],
        "speaker": spec["speaker"] if spec["speaker"] else None,
        "transcript": transcript,
        "tags": spec["tags"],
        "chronology": spec["chronology"],
        "theme": spec["theme"]
    }
    return record


# ==============================================================================
# 4. Serialization & Multi-Format Partitions
# ==============================================================================

def serialize_corpus(records: list, output_dir: str):
    """Write canonical JSON, streamable JSONL, and category partition archives."""
    os.makedirs(output_dir, exist_ok=True)
    cats_dir = os.path.join(output_dir, "categories")
    os.makedirs(cats_dir, exist_ok=True)

    # 1. Main JSON corpus
    corpus_json_path = os.path.join(output_dir, "ahamkara_corpus.json")
    with open(corpus_json_path, "w", encoding="utf-8") as f:
        json.dump(records, f, indent=2, ensure_ascii=False)
        f.write("\n")

    # 2. Main JSONL corpus (one line per record, strict LF byte 0x0a)
    corpus_jsonl_path = os.path.join(output_dir, "ahamkara_corpus.jsonl")
    with open(corpus_jsonl_path, "wb") as f:
        for r in records:
            line_str = json.dumps(r, ensure_ascii=False)
            f.write(line_str.encode("utf-8") + b"\n")

    # 3. Category partitions
    exotics = [r for r in records if r["source"]["type"] in ("exotic_armor", "exotic_weapon")]
    wishes = [r for r in records if r["source"]["type"] == "wall_of_wishes"]
    great_hunt = [
        r for r in records
        if r["source"]["type"] in ("raid_armor", "raid_weapon")
        or "great-hunt" in r["id"]
        or "Great Ahamkara Hunt" in r.get("chronology", "")
        or "Unnamed Great Hunt Dragons" in r.get("entity", [])
    ]
    riven = [r for r in records if "Riven" in r.get("entity", [])]
    taranis = [r for r in records if "Taranis" in r.get("entity", [])]

    partitions = {
        "exotics.json": exotics,
        "great_hunt.json": great_hunt,
        "riven.json": riven,
        "taranis.json": taranis,
        "wishes.json": wishes
    }

    for filename, part_records in partitions.items():
        part_path = os.path.join(cats_dir, filename)
        with open(part_path, "w", encoding="utf-8") as f:
            json.dump(part_records, f, indent=2, ensure_ascii=False)
            f.write("\n")

    return corpus_json_path, corpus_jsonl_path, cats_dir


# ==============================================================================
# 5. Schema Validation & Verification
# ==============================================================================

def validate_records(records: list) -> bool:
    """Verify all 9 fields, enums, formats, and canonical checklists."""
    id_pattern = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
    valid_chronology = {
        "Pre-Collapse & Ancient Origins",
        "Dark Age & Early City Age",
        "The Great Ahamkara Hunt",
        "Reef Golden Age & The Dreaming City",
        "The Taken War",
        "Forsaken & The Dreaming City Curse",
        "Season of the Wish & The Final Shape"
    }
    valid_themes = {
        "Anthem Anatheme & Wish-Bargains",
        "The Great Hunt & Extinction",
        "Fourth-Wall Transcendence (\"O [Reader] Mine\")",
        "The Wall of Wishes & Coded Desire",
        "Parentage & The Uncorrupted Clutch",
        "Deathless Bones & Parasitic Whispers",
        "Vengeance & Twisted Desires"
    }

    errors = []
    seen_ids = set()

    for idx, r in enumerate(records):
        rid = r.get("id", "")
        if not id_pattern.match(rid):
            errors.append(f"Record {idx}: invalid kebab-case id '{rid}'")
        if rid in seen_ids:
            errors.append(f"Record {idx}: duplicate id '{rid}'")
        seen_ids.add(rid)

        title = r.get("title")
        if not title or not isinstance(title, str):
            errors.append(f"Record '{rid}': empty or invalid title")

        src = r.get("source")
        if not isinstance(src, dict) or not src.get("type") or not src.get("game"):
            errors.append(f"Record '{rid}': missing required source fields")

        entity = r.get("entity")
        if not isinstance(entity, list) or len(entity) == 0:
            errors.append(f"Record '{rid}': entity must be a non-empty list")

        speaker = r.get("speaker")
        if speaker == "":
            errors.append(f"Record '{rid}': speaker cannot be empty string (must be null or non-empty string)")

        tags = r.get("tags")
        if not isinstance(tags, list) or len(tags) == 0:
            errors.append(f"Record '{rid}': tags must be a non-empty list")

        transcript = r.get("transcript", "")
        if not transcript or not transcript.strip():
            errors.append(f"Record '{rid}': transcript is empty")

        chron = r.get("chronology")
        if chron not in valid_chronology:
            errors.append(f"Record '{rid}': invalid chronology '{chron}'")

        theme = r.get("theme")
        if theme not in valid_themes:
            errors.append(f"Record '{rid}': invalid theme '{theme}'")

    if errors:
        print(f"[ERROR] Validation failed with {len(errors)} issues:")
        for e in errors[:10]:
            print(f"  - {e}")
        return False

    print(f"[SUCCESS] All {len(records)} records successfully validated against 9-field schema!")
    return True


# ==============================================================================
# 6. Main Pipeline Runner
# ==============================================================================

def main():
    parser = argparse.ArgumentParser(description="Ingest canonical Ahamkara lore records.")
    parser.add_argument("--fetch-live", action="store_true", help="Force fetching from live Ishtar API over IPv4")
    parser.add_argument("--offline", action="store_true", help="Strict offline mode: load exclusively from local cache")
    parser.add_argument("--cache-file", default="", help="Path to raw cache file")
    parser.add_argument("--output-dir", default="data", help="Output directory for generated archives")
    parser.add_argument("--rate-limit", type=float, default=0.1, help="Rate limit delay in seconds (default: 0.1)")
    parser.add_argument("--verify", action="store_true", help="Run schema verification on generated corpus")
    args = parser.parse_args()

    cache_path = args.cache_file
    if not cache_path:
        default_candidates = [
            os.path.join(args.output_dir, "cache", "raw_cache.json"),
            os.path.join(os.path.dirname(__file__), "..", "data", "cache", "raw_cache.json"),
            os.path.join("data", "cache", "raw_cache.json"),
            "/home/jeryd/.agents/m2_explorer_1/raw_cache.json",
            os.path.join(os.path.dirname(__file__), "raw_cache.json")
        ]
        for p in default_candidates:
            if os.path.exists(p):
                cache_path = p
                break

    raw_cache = {}
    if cache_path and os.path.exists(cache_path):
        try:
            with open(cache_path, "r", encoding="utf-8") as f:
                raw_cache = json.load(f)
            print(f"[CACHE] Loaded {len(raw_cache)} entries from cache: {cache_path}")
        except Exception as e:
            print(f"[WARN] Failed to read cache {cache_path}: {e}")

    client = IshtarClient(rate_limit=args.rate_limit)
    updated_cache = False

    if args.fetch_live or (not args.offline and len(raw_cache) < len(CANONICAL_CATALOG)):
        print(f"[INGEST] Fetching records from Ishtar API ({len(CANONICAL_CATALOG)} items)...")
        for spec in CANONICAL_CATALOG:
            rid = spec["id"]
            if not args.fetch_live and rid in raw_cache:
                continue

            path = spec["api_path"]
            doc_type = spec["doc_type"]
            res = client.fetch(path)
            if res and isinstance(res, dict) and doc_type in res:
                raw_cache[rid] = {
                    "id": rid,
                    "api_path": path,
                    "doc_type": doc_type,
                    "data": res[doc_type]
                }
                updated_cache = True
                print(f"  + Fetched: {rid}")
            else:
                print(f"  ! Fallback for: {rid}")

        if updated_cache and cache_path:
            os.makedirs(os.path.dirname(os.path.abspath(cache_path)), exist_ok=True)
            with open(cache_path, "w", encoding="utf-8") as f:
                json.dump(raw_cache, f, indent=2, ensure_ascii=False)
            print(f"[CACHE] Saved {len(raw_cache)} entries to {cache_path}")

    normalized_records = []
    missing = []
    for spec in CANONICAL_CATALOG:
        rid = spec["id"]
        if rid in raw_cache:
            rec = build_record(spec, raw_cache[rid])
            normalized_records.append(rec)
        else:
            missing.append(rid)

    if missing:
        print(f"[WARN] {len(missing)} records missing from cache/fetch: {missing}")

    print(f"[TRANSFORM] Processed {len(normalized_records)} normalized records.")

    json_path, jsonl_path, cats_dir = serialize_corpus(normalized_records, args.output_dir)
    print(f"[EXPORT] Created:\n  - {json_path}\n  - {jsonl_path}\n  - {cats_dir}")

    if args.verify or True:
        if not validate_records(normalized_records):
            sys.exit(1)

    print(f"[DONE] Lore ingestion pipeline successfully finished.")


if __name__ == "__main__":
    main()

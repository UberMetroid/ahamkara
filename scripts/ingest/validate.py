"""Schema verification: 9 fields, enums, formats, canonical checklist."""

import re


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

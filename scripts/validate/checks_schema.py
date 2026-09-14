"""Detailed 9-field schema validation.

Mixin for CorpusValidator — relies on self.reporter and self.records.
"""

import re
from typing import Set

from .constants import (
    ID_PATTERN,
    VALID_CHRONOLOGIES,
    VALID_ENTITIES,
    VALID_GAMES,
    VALID_SOURCE_TYPES,
    VALID_THEMES,
)


class SchemaChecks:
    def validate_record_schema(self):
        bad_id_format = []
        bad_title = []
        bad_source = []
        bad_entity = []
        bad_speaker = []
        bad_transcript = []
        bad_tags = []
        bad_chronology = []
        bad_theme = []
        html_leak_transcripts = []
        distinct_releases: Set[str] = set()

        html_tag_re = re.compile(r"<(?:p|br|div|span|h[1-6]|table|tr|td|a\s|strong|em)[^>]*>", re.IGNORECASE)

        for r in self.records:
            rid = str(r.get("id", ""))

            # 1. ID check: kebab-case
            if not ID_PATTERN.match(rid):
                bad_id_format.append((rid, "Does not match kebab-case regex"))

            # 2. Title check: non-empty string
            title = r.get("title")
            if not isinstance(title, str) or len(title.strip()) == 0:
                bad_title.append(rid)

            # 3. Source check
            src = r.get("source")
            if not isinstance(src, dict):
                bad_source.append((rid, "source is not a dict"))
            else:
                stype = src.get("type")
                sgame = src.get("game")
                srelease = src.get("release")
                surl = src.get("ishtar_url")

                if stype not in VALID_SOURCE_TYPES:
                    bad_source.append((rid, f"invalid source.type: {stype}"))
                if sgame not in VALID_GAMES:
                    bad_source.append((rid, f"invalid source.game: {sgame}"))
                if not isinstance(srelease, str) or len(srelease.strip()) == 0:
                    bad_source.append((rid, f"missing or blank source.release: {srelease}"))
                else:
                    distinct_releases.add(srelease.strip())
                if not isinstance(surl, str) or not (surl.startswith("http://") or surl.startswith("https://")):
                    bad_source.append((rid, f"invalid source.ishtar_url: {surl}"))
                if "bungie_ref" not in src:
                    bad_source.append((rid, "missing bungie_ref key"))

            # 4. Entity check
            entity = r.get("entity")
            if not isinstance(entity, list) or len(entity) == 0:
                bad_entity.append((rid, "entity is not a non-empty list"))
            else:
                for e in entity:
                    if e not in VALID_ENTITIES:
                        bad_entity.append((rid, f"unknown entity enum: '{e}'"))

            # 5. Speaker check: string or null (never "")
            if "speaker" not in r:
                bad_speaker.append((rid, "speaker key missing"))
            else:
                spk = r.get("speaker")
                if spk == "":
                    bad_speaker.append((rid, "speaker is empty string (must be null or non-empty string)"))
                elif spk is not None and not isinstance(spk, str):
                    bad_speaker.append((rid, f"speaker invalid type: {type(spk).__name__}"))

            # 6. Transcript check: non-empty string, no raw html
            trans = r.get("transcript")
            if not isinstance(trans, str) or len(trans.strip()) == 0:
                bad_transcript.append(rid)
            else:
                if html_tag_re.search(trans):
                    html_leak_transcripts.append(rid)

            # 7. Tags check: list of >= 1 string
            tags = r.get("tags")
            if not isinstance(tags, list) or len(tags) == 0:
                bad_tags.append((rid, "tags is not a non-empty list"))
            else:
                for t in tags:
                    if not isinstance(t, str) or len(t.strip()) == 0:
                        bad_tags.append((rid, f"tag is blank or not a string: '{t}'"))

            # 8. Chronology check
            chron = r.get("chronology")
            if chron not in VALID_CHRONOLOGIES:
                bad_chronology.append((rid, f"invalid chronology: '{chron}'"))

            # 9. Theme check
            theme = r.get("theme")
            if theme not in VALID_THEMES:
                bad_theme.append((rid, f"invalid theme: '{theme}'"))

        # Report results
        if not bad_id_format:
            self.reporter.pass_check("VAL-SCH-01", "Every record contains valid kebab-case 'id'")
        else:
            self.reporter.fail_check("VAL-SCH-01", "Every record contains valid kebab-case 'id'", f"{len(bad_id_format)} invalid IDs: {bad_id_format[:3]}")

        if not bad_title:
            self.reporter.pass_check("VAL-SCH-02", "Every record contains non-empty 'title'")
        else:
            self.reporter.fail_check("VAL-SCH-02", "Every record contains non-empty 'title'", f"{len(bad_title)} records missing title: {bad_title[:3]}")

        if not bad_source:
            self.reporter.pass_check("VAL-SCH-03", "Every record contains valid 'source' object with type, game, release, and bungie_ref")
        else:
            self.reporter.fail_check("VAL-SCH-03", "Every record contains valid 'source' object", f"{len(bad_source)} source errors: {bad_source[:3]}")

        if len(distinct_releases) >= 4:
            self.reporter.pass_check("VAL-SCH-04", f"Source releases span >= 4 distinct Destiny releases ({len(distinct_releases)} found)")
        else:
            self.reporter.fail_check("VAL-SCH-04", "Source releases span >= 4 distinct Destiny releases", f"Found only {len(distinct_releases)}: {distinct_releases}")

        if not bad_entity:
            self.reporter.pass_check("VAL-SCH-05", "Every record contains valid non-empty 'entity' list with allowed enums")
        else:
            self.reporter.fail_check("VAL-SCH-05", "Every record contains valid non-empty 'entity' list", f"{len(bad_entity)} entity errors: {bad_entity[:3]}")

        if not bad_speaker:
            self.reporter.pass_check("VAL-SCH-06", "Speaker field is either string or null (never empty string '')")
        else:
            self.reporter.fail_check("VAL-SCH-06", "Speaker field is either string or null", f"{len(bad_speaker)} speaker errors: {bad_speaker[:3]}")

        if not bad_transcript:
            self.reporter.pass_check("VAL-SCH-07", "Every record contains non-empty 'transcript' text")
        else:
            self.reporter.fail_check("VAL-SCH-07", "Every record contains non-empty 'transcript' text", f"{len(bad_transcript)} blank transcripts: {bad_transcript[:3]}")

        if not html_leak_transcripts:
            self.reporter.pass_check("VAL-SCH-08", "All transcripts sanitized of raw unrendered HTML tags (<br>, <p>, etc.)")
        else:
            self.reporter.fail_check("VAL-SCH-08", "All transcripts sanitized of raw unrendered HTML tags", f"{len(html_leak_transcripts)} records contain raw HTML: {html_leak_transcripts[:3]}")

        if not bad_tags:
            self.reporter.pass_check("VAL-SCH-09", "Every record contains non-empty 'tags' list with valid strings")
        else:
            self.reporter.fail_check("VAL-SCH-09", "Every record contains non-empty 'tags' list", f"{len(bad_tags)} tags errors: {bad_tags[:3]}")

        if not bad_chronology:
            self.reporter.pass_check("VAL-SCH-10", "Every record contains valid 'chronology' enum")
        else:
            self.reporter.fail_check("VAL-SCH-10", "Every record contains valid 'chronology' enum", f"{len(bad_chronology)} chronology errors: {bad_chronology[:3]}")

        if not bad_theme:
            self.reporter.pass_check("VAL-SCH-11", "Every record contains valid 'theme' enum")
        else:
            self.reporter.fail_check("VAL-SCH-11", "Every record contains valid 'theme' enum", f"{len(bad_theme)} theme errors: {bad_theme[:3]}")


"""Record assembly: transcript normalization and catalog+payload merging."""

import html
import re


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

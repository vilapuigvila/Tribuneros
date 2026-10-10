"""Shared helpers for the localization scripts (run with python3 from the repo root)."""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
FRAGMENTS = ROOT / "scripts/l10n/fragments"
CATALOG = ROOT / "Tribuneros/Localizable.xcstrings"
ALLOWLIST = ROOT / "scripts/l10n/allowlist.json"
SOURCE_LANGUAGE = "en"
TARGET_LANGUAGES = ["ca"]
PLURAL_CATEGORIES = {"zero", "one", "two", "few", "many", "other"}


def load_fragments():
    """Merges every fragment into {key: entry}. Returns (entries, errors)."""
    entries, origins, errors = {}, {}, []
    for path in sorted(FRAGMENTS.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            errors.append(f"{path.name}: invalid JSON: {error}")
            continue
        for key, entry in data.items():
            if key in entries and entries[key] != entry:
                errors.append(
                    f"{path.name}: key {key!r} also in {origins[key]} with a different entry"
                )
                continue
            entries[key] = entry
            origins[key] = path.name
    return entries, errors


def to_catalog(entries):
    strings = {}
    for key in sorted(entries):
        entry = entries[key]
        localizations = {}
        if "plural" in entry:
            for language, forms in entry["plural"].items():
                localizations[language] = {
                    "variations": {
                        "plural": {
                            category: {"stringUnit": {"state": "translated", "value": value}}
                            for category, value in forms.items()
                        }
                    }
                }
        else:
            for language in TARGET_LANGUAGES:
                if language in entry:
                    localizations[language] = {
                        "stringUnit": {"state": "translated", "value": entry[language]}
                    }
        item = {"extractionState": "manual", "localizations": localizations}
        if entry.get("comment"):
            item = {"comment": entry["comment"], **item}
        strings[key] = item
    return {"sourceLanguage": SOURCE_LANGUAGE, "strings": strings, "version": "1.0"}


def dump_catalog(catalog):
    """Xcode's own formatting: two-space indent, `"key" : value`, sorted keys."""
    return json.dumps(
        catalog,
        ensure_ascii=False,
        indent=2,
        separators=(",", " : "),
        sort_keys=True,
    ) + "\n"


SPECIFIER = re.compile(r"%(?:(\d+)\$)?[-+ #0]*\d*(?:\.\d+)?(hh|h|ll|l|q|z|t|j)?([@dDiuUxXoOfeEgGcCsSpaA])")


def specifiers(text):
    """The format specifiers of a string as a sorted list of (position, conversion)."""
    text = text.replace("%%", "")
    found, implicit = [], 0
    for match in SPECIFIER.finditer(text):
        position, length, conversion = match.groups()
        if position:
            index = int(position)
        else:
            implicit += 1
            index = implicit
        found.append((index, (length or "") + conversion))
    return sorted(found)

#!/usr/bin/env python3
"""Merges scripts/l10n/fragments/*.json into Tribuneros/Localizable.xcstrings.

Fragment entries, keyed by the English text used in `L10n.tr("…")`:
    "Races": {"ca": "Curses", "comment": "optional context for translators"}
    "%lld races": {"plural": {"en": {"one": "%lld race", "other": "%lld races"},
                              "ca": {"one": "%lld cursa", "other": "%lld curses"}}}
Never edit the catalog by hand: edit a fragment and run this script.
"""
import sys

from common import CATALOG, dump_catalog, load_fragments, to_catalog


def main():
    entries, errors = load_fragments()
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    CATALOG.write_text(dump_catalog(to_catalog(entries)), encoding="utf-8")
    print(f"Wrote {len(entries)} keys to {CATALOG.relative_to(CATALOG.parents[1])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

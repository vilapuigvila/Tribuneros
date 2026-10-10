#!/usr/bin/env python3
"""Checks the Catalan localization. Exits 1 on any error.

    python3 scripts/l10n/check_localization.py                 # full check (CI)
    python3 scripts/l10n/check_localization.py --paths Tribuneros/Tabs/CXRaces --no-catalog

Checks:
 1. every fragment entry has a non-empty Catalan value (plurals: en and ca, with `other`);
 2. format specifiers match between the English key/forms and the Catalan values;
 3. Catalan values that equal the English one are listed in allowlist.json (`same`);
 4. Catalan uses the typographic apostrophe (’) and keeps ALL-CAPS keys in caps;
 5. every `L10n.tr("…")` key used in Swift exists in the fragments (unused keys warn);
 6. no hardcoded English literal in a display position (`TribuneruText(content: "…")`,
    `.navigationTitle("…")`, `.accessibilityLabel("…")`, `title: "…"`, …) — mark a deliberate
    one with `// l10n:ignore` on its line, or list the literal in allowlist.json (`literals`);
 7. the catalog is up to date with the fragments, `ca` is in `knownRegions` and in
    `CFBundleLocalizations` (skipped with --no-catalog or --paths).
"""
import argparse
import json
import re
import subprocess
import sys

from common import (
    ALLOWLIST, CATALOG, ROOT, SOURCE_LANGUAGE, TARGET_LANGUAGES, PLURAL_CATEGORIES,
    dump_catalog, load_fragments, specifiers, to_catalog,
)

STRING = r'"(?:[^"\\\n]|\\.)*"'
TR_CALL = re.compile(r'L10n\.tr\(\s*(' + STRING + r')')
DISPLAY_POSITIONS = re.compile(
    r'(?:\b(?:content|title|subtitle|message|label|caption|tag|text|prompt|placeholder|detail|'
    r'headline|primaryButtonTitle|buttonTitle|accessibilityLabel|accessibilityHint|footer|eyebrow)'
    r'\s*:\s*'
    r'|\.(?:navigationTitle|accessibilityLabel|accessibilityHint|accessibilityValue|searchable\([^)]*prompt:)\s*\(?\s*'
    r'|\b(?:Button|Text|Label|Toggle|Section)\(\s*)'
    r'(' + STRING + r')'
)
EXCLUDED_FILE = re.compile(r'(Mock|MockScenario|MockPreview|Preview Content|ContentView\.swift|Item\.swift)')


def strip_interpolations(literal):
    """The literal's static text, with every `\\( … )` removed (nested parentheses aware)."""
    out, i = [], 0
    while i < len(literal):
        if literal.startswith("\\(", i):
            depth, i = 1, i + 2
            while i < len(literal) and depth:
                depth += {"(": 1, ")": -1}.get(literal[i], 0)
                i += 1
        else:
            out.append(literal[i])
            i += 1
    return "".join(out)


def unquote(literal):
    body = literal[1:-1]
    body = re.sub(r'\\u\{([0-9a-fA-F]+)\}', lambda m: chr(int(m.group(1), 16)), body)
    return body.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")


def swift_files(paths):
    args = ["git", "ls-files", "--cached", "--others", "--exclude-standard", "--"]
    args += [f"{p}" for p in (paths or ["Tribuneros"])]
    listed = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, check=True).stdout
    return [ROOT / f for f in listed.split() if f.endswith(".swift") and not EXCLUDED_FILE.search(f)]


def check_entries(entries, allowlist, errors, warnings):
    same_ok = set(allowlist.get("same", []))
    for key, entry in entries.items():
        if "plural" in entry:
            forms = entry["plural"]
            for language in [SOURCE_LANGUAGE] + TARGET_LANGUAGES:
                if language not in forms or not forms[language].get("other"):
                    errors.append(f"{key!r}: plural needs {language} with an `other` form")
                    continue
                unknown = set(forms[language]) - PLURAL_CATEGORIES
                if unknown:
                    errors.append(f"{key!r}: unknown plural categories {sorted(unknown)}")
            reference = specifiers(key)
            for language, variations in forms.items():
                for category, value in variations.items():
                    _check_value(key, f"{language}.{category}", value, reference, errors, check_typography=language != SOURCE_LANGUAGE, same_ok=True)
        else:
            for language in TARGET_LANGUAGES:
                value = entry.get(language)
                if not value or not value.strip():
                    errors.append(f"{key!r}: missing {language}")
                    continue
                _check_value(key, language, value, specifiers(key), errors, check_typography=True, same_ok=key in same_ok)
                if value == key and key not in same_ok and len(re.findall(r"[A-Za-z]", key)) >= 4:
                    errors.append(f"{key!r}: {language} equals English; translate it or add it to allowlist.json `same`")


def _check_value(key, where, value, reference, errors, check_typography, same_ok):
    if specifiers(value) != reference:
        errors.append(f"{key!r} [{where}]: specifiers {specifiers(value)} != {reference}")
    if check_typography:
        if "'" in value:
            errors.append(f"{key!r} [{where}]: use ’ instead of a straight apostrophe")
        letters = strip_interpolations(re.sub(r"%(\d+\$)?[a-zA-Z@]+", "", key))
        if re.search(r"[A-Z]{2}", letters) and not re.search(r"[a-z]", letters):
            stripped = re.sub(r"%(\d+\$)?(ll|l)?[a-zA-Z@]", "", value)
            if re.search(r"[a-zà-ÿ]", stripped):
                errors.append(f"{key!r} [{where}]: the key is all caps, so the translation should be too")


def check_sources(files, entries, allowlist, errors, warnings, report_unused):
    literals_ok = set(allowlist.get("literals", []))
    used = set()
    for path in files:
        source = path.read_text(encoding="utf-8")
        lines = source.splitlines()
        # Keys may sit on the line after `L10n.tr(`, so extract them from the whole file.
        for match in TR_CALL.finditer(source):
            line_text = lines[source.count("\n", 0, match.start())]
            if line_text.lstrip().startswith("//"):
                continue
            where = f"{path.relative_to(ROOT)}:{source.count(chr(10), 0, match.start()) + 1}"
            key = unquote(match.group(1))
            used.add(key)
            if "\\(" in match.group(1):
                errors.append(f"{where}: L10n.tr key must be a plain literal, not interpolated")
            elif key not in entries:
                errors.append(f"{where}: key {key!r} missing from the fragments")
        in_preview = False
        for number, line in enumerate(lines, 1):
            if line.startswith("#Preview"):
                in_preview = True
            where = f"{path.relative_to(ROOT)}:{number}"
            if line.lstrip().startswith("//"):
                continue
            if in_preview or "l10n:ignore" in line:
                continue
            for match in DISPLAY_POSITIONS.finditer(line):
                literal = match.group(1)
                static = strip_interpolations(literal[1:-1])
                if not re.search(r"[A-Za-z]{2}", static):
                    continue
                if unquote(literal) in literals_ok:
                    continue
                errors.append(f"{where}: hardcoded display text {literal} (wrap in L10n.tr or mark // l10n:ignore)")
    if report_unused:
        for key in sorted(set(entries) - used):
            warnings.append(f"unused key {key!r}")


def check_wiring(entries, errors):
    if not CATALOG.exists():
        errors.append(f"{CATALOG.name} missing: run scripts/l10n/build_catalog.py")
    elif CATALOG.read_text(encoding="utf-8") != dump_catalog(to_catalog(entries)):
        errors.append(f"{CATALOG.name} is out of date: run scripts/l10n/build_catalog.py")
    pbxproj = (ROOT / "Tribuneros.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    regions = re.search(r"knownRegions = \(([^)]*)\)", pbxproj)
    for language in TARGET_LANGUAGES:
        if not regions or not re.search(rf"\b{language}\b", regions.group(1)):
            errors.append(f"project.pbxproj knownRegions lacks {language}")
        plist = (ROOT / "Tribuneros/Info.plist").read_text(encoding="utf-8")
        localizations = re.search(r"<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>", plist, re.S)
        if not localizations or f"<string>{language}</string>" not in localizations.group(1):
            errors.append(f"Info.plist CFBundleLocalizations lacks {language}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--paths", nargs="*", help="limit the Swift scan to these paths")
    parser.add_argument("--no-catalog", action="store_true", help="skip the catalog and project wiring checks")
    args = parser.parse_args()

    errors, warnings = [], []
    entries, fragment_errors = load_fragments()
    errors += fragment_errors
    allowlist = json.loads(ALLOWLIST.read_text(encoding="utf-8")) if ALLOWLIST.exists() else {}
    check_entries(entries, allowlist, errors, warnings)
    check_sources(swift_files(args.paths), entries, allowlist, errors, warnings, report_unused=not args.paths)
    if not args.no_catalog and not args.paths:
        check_wiring(entries, errors)

    for warning in warnings:
        print(f"warning: {warning}")
    for error in errors:
        print(f"error: {error}")
    print(f"{len(entries)} keys, {len(errors)} errors, {len(warnings)} warnings")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())

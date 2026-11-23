#!/usr/bin/env python3
"""Checks the products' Vietnamese text against docs/manual/thuat-ngu.md.

Reads every "Không dùng" cell of the glossary and the "Giao diện" section's
exceptions, then scans the text people see: the app's strings.xml, the
website's src/i18n/vi/*.ts and the server's catalogs. Prints each hit and
exits 1 when there is one. Usage: python3 docs/i18n/check-terms.py [root]
"""
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[2])
GLOSSARY = ROOT / "docs/manual/thuat-ngu.md"
# The checkouts to scan, relative to ROOT; a worktree can stand in for one.
APP = os.environ.get("TERMS_APP", "app")
WEBSITE = os.environ.get("TERMS_WEBSITE", "website")
SERVER = os.environ.get("TERMS_SERVER", "server")


def glossary():
    """The banned terms, each with the term to use, and the UI exceptions."""
    banned, allowed, section = {}, set(), ""
    for line in GLOSSARY.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            section = line[3:].strip()
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if not line.startswith("|") or len(cells) < 3 or cells[0] in ("Dùng", "") or set(cells[0]) <= set("-"):
            continue
        if section == "Giao diện":
            # | Dùng trên giao diện | Thay cho | Lý do |: the phrase in the first cell
            # may hold the banned term in the second.
            allowed.update(a.strip() for a in cells[0].split(",") if a.strip())
            continue
        # A term to use may contain a banned one ("tạm khóa tài khoản").
        allowed.update(re.sub(r"\s*\(.*?\)", "", u).strip() for u in cells[0].split(","))
        for term in cells[2].split(","):
            term = re.sub(r"\s*\(.*?\)", "", term).strip()
            if term:
                banned[term] = cells[0]
    return banned, allowed


def texts():
    """(file, line, text) for every string people see."""
    for f in sorted((ROOT / APP).glob("**/src/main/res/values/strings.xml")):
        if any(part in str(f.relative_to(ROOT / APP)) for part in ("build/", ".worktrees", "tmp/")):
            continue
        for i, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            m = re.search(r">(.*)</(string|item)>", line)
            if m:
                yield f, i, m.group(1)
    for f in sorted((ROOT / WEBSITE / "src/i18n/vi").glob("*.ts")):
        for i, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if line.lstrip().startswith("//"):
                continue
            for m in re.finditer(r"'((?:[^'\\]|\\.)*)'|`((?:[^`\\]|\\.)*)`|\"((?:[^\"\\]|\\.)*)\"", line):
                yield f, i, next(g for g in m.groups() if g is not None)
    for f in sorted((ROOT / SERVER).glob("internal/**/*.json")):
        if f.parent.name not in ("text", "mail", "locales") or f.stem != "vi":
            continue
        for key, value in json.loads(f.read_text(encoding="utf-8")).items():
            yield f, key, value


def visible(text):
    """The words of a string people read: values (${x}, {x}, %1$s) and
    identifiers such as icon names are not words."""
    if re.fullmatch(r"[a-z0-9_.:/#-]+", text):
        return ""
    return re.sub(r"\$\{[^}]*\}|\{\w+\}|%(\d+\$)?[sd]|%\[\d+\][sd]", " ", text)


def main():
    banned, allowed = glossary()
    patterns = {t: re.compile(r"(?<![\w])" + re.escape(t) + r"(?![\w])", re.IGNORECASE) for t in banned}
    hits = 0
    for f, where, raw in texts():
        text = visible(raw)
        for term, pattern in patterns.items():
            if pattern.search(text) and not any(a.lower() in text.lower() and pattern.search(a) for a in allowed):
                hits += 1
                print(f"{f.relative_to(ROOT)}:{where}: “{term}” → {banned[term]}: {text}")
    print(f"{hits} hits", file=sys.stderr)
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main())

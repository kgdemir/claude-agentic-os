#!/usr/bin/env bash
# Structural checks on the rules pack in .claude/ (ADR-0010):
# - every rule in a stack, tool or feature guide carries a *Cost:* or *Why:*
#   line (ADR-0008), apart from the older ones listed in check-guides.baseline;
# - every ~/.claude/guides/... or ~/.claude/templates/... path resolves;
# - every add-on guide has a trigger row in .claude/CLAUDE.md (ADR-0007);
# - every ```yaml block parses (skipped when PyYAML is missing);
# - no project name from tools/leak-names.local appears (skipped without it).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

python3 -I - "$PWD" <<'PY'
import pathlib, re, sys

ROOT = pathlib.Path(sys.argv[1])
PACK = ROOT / ".claude"
GUIDES = PACK / "guides"
ADDON_DIRS = ("stacks", "tools", "features", "plugins", "addons")
RULE_DIRS = ("stacks", "tools", "features")
BASELINE = ROOT / "tools" / "check-guides.baseline"
LEAK_LIST = ROOT / "tools" / "leak-names.local"
PACK_REF = re.compile(r"~/\.claude/((?:guides|templates)/[\w./-]+\.md)")
RULE = re.compile(r"^- \*\*(.+?)\*\*")
REASON = re.compile(r"^\s+\*(Cost|Why):")

failures, notes = [], []
markdown = sorted(PACK.rglob("*.md"))

def rel(path):
    return path.relative_to(ROOT)

# 1. Cost/Why lines
known = set()
for line in BASELINE.read_text(encoding="utf-8").splitlines():
    if line.strip() and not line.startswith("#"):
        known.add(line)
used = set()
for folder in RULE_DIRS:
    for guide in sorted((GUIDES / folder).glob("*.md")):
        rules = []  # [line number, bold text, has reason]
        for number, line in enumerate(guide.read_text(encoding="utf-8").splitlines(), 1):
            match = RULE.match(line)
            if match:
                rules.append([number, match.group(1), False])
            elif rules and REASON.match(line):
                rules[-1][2] = True
        for number, text, has_reason in rules:
            key = f"{guide.relative_to(GUIDES)}|{text}"
            if key in known:
                used.add(key)
            if has_reason:
                if key in known:
                    failures.append(f"{rel(guide)}:{number}: rule now has a reason; drop it from {rel(BASELINE)}")
            elif key not in known:
                failures.append(f"{rel(guide)}:{number}: rule has no *Cost:* or *Why:* line: {text}")
for key in sorted(known - used):
    failures.append(f"{rel(BASELINE)}: stale entry, no such rule: {key}")

# 2. Pack paths resolve
for doc in markdown + [ROOT / "README.md", ROOT / "CONTRIBUTING.md"]:
    for number, line in enumerate(doc.read_text(encoding="utf-8").splitlines(), 1):
        for target in PACK_REF.findall(line):
            if not (PACK / target).is_file():
                failures.append(f"{rel(doc)}:{number}: ~/.claude/{target} does not exist in .claude/")

# 3. Trigger rows
table = (PACK / "CLAUDE.md").read_text(encoding="utf-8")
rows = "\n".join(line for line in table.splitlines() if line.startswith("| "))
for folder in ADDON_DIRS:
    for guide in sorted((GUIDES / folder).glob("*.md")):
        if folder == "addons":
            continue  # imported by install.sh through a placeholder, not a trigger row
        if f"~/.claude/guides/{folder}/{guide.name}" not in rows:
            failures.append(f"{rel(guide)}: no trigger row in .claude/CLAUDE.md")

# 4. YAML blocks
try:
    import yaml
except ImportError:
    yaml = None
    notes.append("SKIP yaml blocks: PyYAML not installed")
if yaml:
    for doc in markdown:
        lines = doc.read_text(encoding="utf-8").splitlines()
        block, start, indent = None, 0, ""
        for number, line in enumerate(lines, 1):
            stripped = line.lstrip()
            if block is None and stripped.startswith("```yaml"):
                block, start, indent = [], number, line[: len(line) - len(stripped)]
            elif block is not None and stripped.startswith("```"):
                try:
                    yaml.safe_load("\n".join(block))
                except yaml.YAMLError as exc:
                    failures.append(f"{rel(doc)}:{start}: yaml block does not parse: {str(exc).splitlines()[0]}")
                block = None
            elif block is not None:
                block.append(line[len(indent):] if line.startswith(indent) else line)

# 5. Project-name leaks
if LEAK_LIST.is_file():
    names = [n.strip() for n in LEAK_LIST.read_text(encoding="utf-8").splitlines()
             if n.strip() and not n.startswith("#")]
    if names:
        leak = re.compile(r"\b(" + "|".join(re.escape(n) for n in names) + r")\b", re.IGNORECASE)
        for doc in sorted(PACK.rglob("*")) + [ROOT / "README.md", ROOT / "CONTRIBUTING.md", ROOT / "install.sh"]:
            if doc.is_file() and doc.suffix in {".md", ".py", ".sh", ""}:
                for number, line in enumerate(doc.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                    found = leak.search(line)
                    if found:
                        failures.append(f"{rel(doc)}:{number}: project name {found.group(0)!r}")
else:
    notes.append(f"SKIP project-name leaks: no {rel(LEAK_LIST)}")

for note in notes:
    print(note)
if failures:
    print("\n".join(failures))
    sys.exit(1)
print("guides ok")
PY

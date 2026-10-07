"""Every UI string has an English, Spanish and Russian translation.

The code passes Turkish source strings to I18n.t(); components/Translations.js
maps them per language. Agent state labels come from AgentBridge.stateLook
and are translated at display time, so they are checked too."""
import json
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
used = set()
for f in list(root.rglob("*.qml")) + list(root.rglob("*.js")):
    for m in re.finditer(r'I18n\.t\(\s*"((?:[^"\\]|\\.)*)"', f.read_text()):
        used.add(json.loads('"' + m.group(1) + '"'))
bridge = (root / "services/AgentBridge.qml").read_text()
used |= set(re.findall(r'label:\s*"([^"]+)"', bridge))

tables = {}
src = (root / "components/Translations.js").read_text()
for name, body in re.findall(r"var (\w+) = (\{.*?\n\})", src, re.S):
    tables[name] = json.loads(body)

bad = 0
for lang in ("en", "es", "ru"):
    missing = sorted(used - set(tables.get(lang, {})))
    if missing:
        bad += 1
        print(f"{lang}: {len(missing)} missing")
        for s in missing:
            print("   ", json.dumps(s, ensure_ascii=False))
if bad:
    sys.exit(1)
print(f"i18n: {len(used)} strings, all translated to en, es, ru")

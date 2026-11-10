#!/usr/bin/env python3
"""Usage: render.py <template> <knowledge.md> <output>"""
import os
import sys

template_path, knowledge_path, out_path = sys.argv[1:4]

with open(template_path, encoding="utf-8") as f:
    text = f.read()
with open(knowledge_path, encoding="utf-8") as f:
    knowledge = f.read().strip()

for key in ("APP_TITLE", "LLM_BASE_URL", "LLM_MODEL", "LLM_TITLE_MODEL"):
    value = os.environ.get(key)
    if not value:
        sys.exit(f"render.py: {key} is not set")
    text = text.replace(f"__{key}__", value)

lines = text.splitlines()
out = []
found = False
for line in lines:
    if line.strip() == "__KNOWLEDGE__":
        indent = line[: len(line) - len(line.lstrip())]
        out.extend((indent + k) if k.strip() else "" for k in knowledge.splitlines())
        found = True
    else:
        out.append(line)
if not found:
    sys.exit("render.py: __KNOWLEDGE__ placeholder not found in template")

with open(out_path, "w", encoding="utf-8") as f:
    f.write("\n".join(out) + "\n")
print(f"render.py: wrote {out_path} ({len(knowledge.splitlines())} knowledge lines)")

"""Оставить в GLB нужные клипы и дать им понятные имена. Геометрия и кости не меняются.

usage: python3 -I pipelines/creature-quadruped/name_clips.py <вход.glb> <выход.glb> <старое=новое> [...]
"""
import json
import struct
import sys

source, target = sys.argv[1:3]
names = dict(a.split("=") for a in sys.argv[3:])
with open(source, "rb") as f:
    head = f.read(12)
    size, kind = struct.unpack("<II", f.read(8))
    g = json.loads(f.read(size))
    rest = f.read()
g["animations"] = [dict(a, name=names[a["name"]]) for a in g["animations"] if a["name"] in names]
missing = set(names.values()) - {a["name"] for a in g["animations"]}
if missing:
    raise SystemExit(f"нет клипов: {missing}")
text = json.dumps(g, ensure_ascii=False, separators=(",", ":")).encode()
text += b" " * (-len(text) % 4)
total = 12 + 8 + len(text) + len(rest)
with open(target, "wb") as f:
    f.write(head[:8] + struct.pack("<I", total))
    f.write(struct.pack("<II", len(text), kind) + text + rest)
print([a["name"] for a in g["animations"]])

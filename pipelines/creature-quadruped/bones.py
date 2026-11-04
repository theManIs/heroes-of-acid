"""Что внутри GLB: кости, анимации, сетка. Только чтение.

usage: python3 -I pipelines/creature-quadruped/bones.py <файл.glb> [...]
"""
import json
import struct
import sys


def read(path):
    with open(path, "rb") as f:
        f.read(12)
        size, _ = struct.unpack("<II", f.read(8))
        return json.loads(f.read(size))


for path in sys.argv[1:]:
    g = read(path)
    print("==", path)
    tris = sum(g["accessors"][p["indices"]]["count"] // 3 for m in g.get("meshes", []) for p in m["primitives"] if "indices" in p)
    print("треугольников:", tris, "текстур:", len(g.get("images", [])))
    for skin in g.get("skins", []):
        names = [g["nodes"][j].get("name", "?") for j in skin["joints"]]
        print("костей:", len(names))
        print(", ".join(names))
    if not g.get("skins"):
        print("костей: 0")
    for a in g.get("animations", []):
        print("анимация:", a.get("name"), "каналов:", len(a["channels"]))
    if not g.get("animations"):
        print("анимаций: 0")

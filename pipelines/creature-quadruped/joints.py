"""Положения костей GLB в позе рига и длины костей (по inverseBindMatrices). Только чтение.

usage: python3 -I pipelines/creature-quadruped/joints.py <файл.glb>
"""
import json
import math
import struct
import sys

path = sys.argv[1]
with open(path, "rb") as f:
    f.read(12)
    size, _ = struct.unpack("<II", f.read(8))
    g = json.loads(f.read(size))
    blen, _ = struct.unpack("<II", f.read(8))
    blob = f.read(blen)
skin = g["skins"][0]
acc = g["accessors"][skin["inverseBindMatrices"]]
view = g["bufferViews"][acc["bufferView"]]
off = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
raw = struct.unpack_from("<%df" % (16 * acc["count"]), blob, off)


def pos(i):
    m = raw[i * 16:i * 16 + 16]  # столбцы: R — m[0..2], m[4..6], m[8..10], t — m[12..14]
    r = [[m[0], m[4], m[8]], [m[1], m[5], m[9]], [m[2], m[6], m[10]]]
    t = m[12:15]
    # R ортогональна с масштабом s: inverse(R) = Rᵀ / s²
    s2 = sum(v * v for v in r[0])
    return [-sum(r[k][a] * t[k] for k in range(3)) / s2 for a in range(3)]


parents = {}
for i, n in enumerate(g["nodes"]):
    for c in n.get("children", []):
        parents[c] = i
joints = skin["joints"]
index = {j: i for i, j in enumerate(joints)}
points = [pos(i) for i in range(len(joints))]
lo = [min(p[a] for p in points) for a in range(3)]
hi = [max(p[a] for p in points) for a in range(3)]
print("габариты костей:", [round(h - l, 2) for l, h in zip(lo, hi)])
for i, j in enumerate(joints):
    p = parents.get(j)
    q = points[index[p]] if p in index else None
    length = math.dist(points[i], q) if q else 0.0
    print(f"{g['nodes'][j].get('name'):24} <- {(g['nodes'][p].get('name') if p is not None else '-'):24} длина {length:5.2f}  {[round(v, 2) for v in points[i]]}")

"""Светящиеся части на текстуре: карта свечения и где на модели они находятся.

Запуск: .venv/bin/python -I pipelines/creature-recolor/make_glow.py <creature_id> <имя_генерации>
Пишет game/assets/creatures/<id>/generations/<имя>/emission.png: яркие оранжевые пиксели, остальное чёрное.
Печатает центр светящихся вершин в осях рига и главную кость: их вписать в "glow" записи существа.
"""

import colorsys
import json
import struct
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
Image.MAX_IMAGE_PIXELS = None
SIZE = 1024
HUE = (15 / 360, 55 / 360)  # огонь: от красно-оранжевого до жёлтого
MIN_SAT, MIN_VAL = 0.55, 0.62


def glowing(rgb) -> bool:
    h, s, v = colorsys.rgb_to_hsv(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255)
    return HUE[0] < h < HUE[1] and s > MIN_SAT and v > MIN_VAL


def accessor(doc, binary, index, fmt, width):
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    offset = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    size = struct.calcsize("<" + fmt)
    stride = view.get("byteStride") or size * width
    return [struct.unpack_from(f"<{width}{fmt}", binary, offset + i * stride) for i in range(acc["count"])]


def main(creature_id: str, name: str) -> None:
    folder = ROOT / "game" / "assets" / "creatures" / creature_id / "generations" / name
    albedo = Image.open(folder / "albedo.jpg").convert("RGB")
    small = albedo.resize((SIZE, SIZE))
    out = Image.new("RGB", (SIZE, SIZE))
    src, dst = small.load(), out.load()
    for y in range(SIZE):
        for x in range(SIZE):
            if glowing(src[x, y]):
                dst[x, y] = src[x, y]
    out.save(folder / "emission.png")

    data = (ROOT / "creatures" / creature_id / "tripo" / "rig.glb").read_bytes()
    size = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20:20 + size])
    binary = data[20 + size + 8:]
    attrs = doc["meshes"][0]["primitives"][0]["attributes"]
    pos = accessor(doc, binary, attrs["POSITION"], "f", 3)
    uv = accessor(doc, binary, attrs["TEXCOORD_0"], "f", 2)
    joints_type = doc["accessors"][attrs["JOINTS_0"]]["componentType"]
    joints = accessor(doc, binary, attrs["JOINTS_0"], "B" if joints_type == 5121 else "H", 4)
    weights = accessor(doc, binary, attrs["WEIGHTS_0"], "f", 4)
    names = [doc["nodes"][i]["name"] for i in doc["skins"][0]["joints"]]
    w, h = albedo.size
    px = albedo.load()
    hits = [i for i, t in enumerate(uv) if glowing(px[min(int(t[0] % 1 * w), w - 1), min(int(t[1] % 1 * h), h - 1)])]
    votes = {}
    for i in hits:
        for j, weight in zip(joints[i], weights[i]):
            votes[names[j]] = votes.get(names[j], 0.0) + weight
    bone = max(votes, key=votes.get)
    # Центр по вершинам главной кости: случайные оранжевые точки на других частях тела отсекаются.
    main_hits = [i for i in hits if names[joints[i][max(range(4), key=lambda n: weights[i][n])]] == bone]
    center = [sorted(pos[i][k] for i in main_hits)[len(main_hits) // 2] for k in range(3)]
    print("светящихся вершин", len(hits), "из", len(pos))
    print("разброс", [round(max(pos[i][k] for i in main_hits) - min(pos[i][k] for i in main_hits), 3) for k in range(3)])
    print("кость", bone, "центр в осях сетки", [round(c, 4) for c in center])
    print("кости", sorted(((round(v, 1), k) for k, v in votes.items()), reverse=True)[:4])


if __name__ == "__main__":
    main(*sys.argv[1:3])

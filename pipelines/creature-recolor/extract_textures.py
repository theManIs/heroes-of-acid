"""Достать текстуры из GLB новой генерации в папку игры, для варианта в тесте существа.

Запуск: python3 -I pipelines/creature-recolor/extract_textures.py <creature_id> <имя_генерации>
Пишет game/assets/creatures/<id>/generations/<имя>/{albedo,normal,orm}.<расширение>.
"""

import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXT = {"image/png": "png", "image/jpeg": "jpg"}


def main(creature_id: str, name: str) -> None:
    data = (ROOT / "creatures" / creature_id / "tripo" / "generations" / name / "model.glb").read_bytes()
    size = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20:20 + size])
    binary = data[20 + size + 8:]
    pbr = doc["materials"][0]
    slots = {"albedo": pbr["pbrMetallicRoughness"]["baseColorTexture"]["index"],
             "normal": pbr["normalTexture"]["index"],
             "orm": pbr["pbrMetallicRoughness"]["metallicRoughnessTexture"]["index"]}
    out = ROOT / "game" / "assets" / "creatures" / creature_id / "generations" / name
    out.mkdir(parents=True, exist_ok=True)
    for slot, texture in slots.items():
        image = doc["images"][doc["textures"][texture]["source"]]
        view = doc["bufferViews"][image["bufferView"]]
        offset = view.get("byteOffset", 0)
        target = out / f"{slot}.{EXT[image['mimeType']]}"
        target.write_bytes(binary[offset:offset + view["byteLength"]])
        print(target.name, view["byteLength"])


if __name__ == "__main__":
    main(*sys.argv[1:3])

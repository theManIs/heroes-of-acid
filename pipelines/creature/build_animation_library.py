"""Общая библиотека анимаций: по файлу на пресет Tripo, без геометрии и текстур.

Запуск: .venv/bin/python pipelines/creature/build_animation_library.py

Берёт все оплаченные GLB из creatures/<id>/tripo/ и пишет game/assets/animations/<пресет>.glb
и README.md со списком. Один и тот же пресет берётся у первого существа из PRIORITY:
обычное телосложение переносится на других лучше, чем упырь или голем.
Скелет остаётся в файле: он нужен, чтобы пересчитать анимацию на чужую позу покоя.
"""

import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PRIORITY = ["militiaman", "vampire", "boilerman", "ghoul", "flesh-golem"]
OUT = ROOT / "game" / "assets" / "animations"
KEEP = ["asset", "scene", "scenes", "skins", "nodes"]


def read_glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    size = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20:20 + size])
    start = 20 + size + 8
    return doc, data[start:start + struct.unpack("<I", data[20 + size:24 + size])[0]]


def write_one(doc: dict, binary: bytes, anim: dict, target: Path) -> None:
    out = {k: json.loads(json.dumps(doc[k])) for k in KEEP if k in doc}
    for node in out["nodes"]:
        node.pop("mesh", None)
        node.pop("skin", None)
    accessors, views, blob = [], [], bytearray()
    remap = {}

    def copy(index: int) -> int:
        if index in remap:
            return remap[index]
        acc = dict(doc["accessors"][index])
        view = dict(doc["bufferViews"][acc["bufferView"]])
        offset = view.get("byteOffset", 0)
        chunk = binary[offset:offset + view["byteLength"]]
        while len(blob) % 4:
            blob.append(0)
        view["byteOffset"] = len(blob)
        view["buffer"] = 0
        blob.extend(chunk)
        acc["bufferView"] = len(views)
        views.append(view)
        remap[index] = len(accessors)
        accessors.append(acc)
        return remap[index]

    for skin in out.get("skins", []):
        if "inverseBindMatrices" in skin:
            skin["inverseBindMatrices"] = copy(skin["inverseBindMatrices"])
    new = json.loads(json.dumps(anim))
    for sampler in new["samplers"]:
        sampler["input"] = copy(sampler["input"])
        sampler["output"] = copy(sampler["output"])
    while len(blob) % 4:
        blob.append(0)
    out.update(animations=[new], accessors=accessors, bufferViews=views, buffers=[{"byteLength": len(blob)}])
    text = json.dumps(out, separators=(",", ":"), ensure_ascii=False).encode()
    text += b" " * (-len(text) % 4)
    total = 12 + 8 + len(text) + 8 + len(blob)
    target.write_bytes(struct.pack("<4sII", b"glTF", 2, total) + struct.pack("<I4s", len(text), b"JSON") + text
                       + struct.pack("<I4s", len(blob), b"BIN\0") + bytes(blob))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    taken = {}
    for creature in PRIORITY:
        tripo = ROOT / "creatures" / creature / "tripo"
        if creature == "militiaman":
            tripo = tripo / "v1"  # старый риг, за анимации платили на нём
        for path in sorted(tripo.glob("*.glb")):
            doc, binary = read_glb(path)
            for anim in doc.get("animations", []):
                name = anim.get("name")
                if name and name not in taken:
                    taken[name] = creature
                    write_one(doc, binary, anim, OUT / f"{name}.glb")
    lines = ["# Библиотека анимаций", "",
             "Пресеты Tripo (`preset:biped:*`), скелет 41 кость (риг `v1.0-20240301`, `spec: tripo`). Подходят к любому такому ригу: `creature.gd` пересчитывает их на его позу покоя.",
             "Папку можно передавать отдельно: в файлах только скелет и движение, геометрии и текстур нет.", "",
             "В записи существа: `\"extra\": [\"res://assets/animations/chop.glb\", …]`. Новая модель: только модель и риг (65 кредитов). Если на сильно другом теле перенос выглядит плохо, анимацию заказывают для него отдельно.", "",
             "Собирается скриптом `pipelines/creature/build_animation_library.py`.", "",
             "| Пресет | С какого рига |", "|---|---|"]
    lines += [f"| `{n}` | {taken[n]} |" for n in sorted(taken)]
    (OUT / "README.md").write_text("\n".join(lines) + "\n")
    print(len(taken), "пресетов:", ", ".join(sorted(taken)))


if __name__ == "__main__":
    main()

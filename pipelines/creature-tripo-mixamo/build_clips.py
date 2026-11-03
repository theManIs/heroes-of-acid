"""Шаг 3: клипы Mixamo → анимации на риге существа.

Запуск: .venv/bin/python pipelines/creature-tripo-mixamo/build_clips.py <creature_id>

Берёт creatures/<id>/mixamo/*.fbx по таблице creatures/<id>/mixamo/clips.json ({"Имя файла": {"name": "idle", ...}})
и пишет game/assets/creatures/<id>/anims/<name>.glb: скелет рига без геометрии и одна анимация.

Имена костей совпадают, но оси и позы покоя у рига Tripo и клипа Mixamo разные, поэтому повороты
переносятся не локально, а как отклонение кости от покоя в мировых осях.
Кости левой кисти и пальцев: кисть модели уже сжата на луке, клип сжимает её второй раз, поэтому пальцы не трогаем.
"_arm_out" в clips.json — постоянно отвести правую руку от тела, градусы: {"arm": плечо, "fore": предплечье и кисть сверх плеча}.
"""

import json
import math
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
PREFIX = "mixamorig:"


def read_glb(path):
    data = Path(path).read_bytes()
    size = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20:20 + size])
    start = 20 + size + 8
    return doc, data[start:start + struct.unpack("<I", data[20 + size:24 + size])[0]]


def accessor(doc, binary, index):
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    width = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[acc["type"]]
    offset = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    values = struct.unpack_from(f"<{acc['count'] * width}f", binary, offset)
    return [values[i:i + width] for i in range(0, len(values), width)]


# Кватернионы (x, y, z, w)
def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz)


def qinv(q):
    return (-q[0], -q[1], -q[2], q[3])


def qrot(q, v):
    x, y, z, _ = qmul(qmul(q, (v[0], v[1], v[2], 0.0)), qinv(q))
    return (x, y, z)


def qaxis(axis, angle):
    s = math.sin(angle / 2)
    return (axis[0] * s, axis[1] * s, axis[2] * s, math.cos(angle / 2))


def qnorm(q):
    n = math.sqrt(sum(c * c for c in q))
    return tuple(c / n for c in q)


def qlerp(a, b, t):
    if sum(x * y for x, y in zip(a, b)) < 0:
        b = tuple(-c for c in b)
    return qnorm(tuple(x + (y - x) * t for x, y in zip(a, b)))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def unit(v):
    n = math.sqrt(sum(c * c for c in v))
    return tuple(c / n for c in v)


class Skeleton:
    """Иерархия узлов GLB: локальные покои и глобальный покой (поворот, положение, равномерный масштаб)."""

    def __init__(self, doc):
        self.nodes = doc["nodes"]
        self.parent = {c: i for i, n in enumerate(self.nodes) for c in n.get("children", [])}
        self.by_name = {n.get("name"): i for i, n in enumerate(self.nodes)}
        self.bones = [n["name"] for n in self.nodes if n.get("name", "").startswith(PREFIX)]
        self.order = sorted(self.bones, key=self.depth)
        self.rest = {i: self.world(i, {}) for i in range(len(self.nodes))}

    def depth(self, name):
        i, d = self.by_name[name], 0
        while i in self.parent:
            i, d = self.parent[i], d + 1
        return d

    def local(self, i, pose):
        node = self.nodes[i]
        rot = pose.get(i, {}).get("r") or tuple(node.get("rotation", (0, 0, 0, 1)))
        pos = pose.get(i, {}).get("t") or tuple(node.get("translation", (0, 0, 0)))
        return rot, pos, node.get("scale", (1, 1, 1))[0]

    def world(self, i, pose):
        rot, pos, scale = self.local(i, pose)
        if i not in self.parent:
            return rot, pos, scale
        pr, pp, ps = self.world(self.parent[i], pose)
        p = qrot(pr, tuple(c * ps for c in pos))
        return qmul(pr, rot), tuple(a + b for a, b in zip(pp, p)), ps * scale

    def rest_of(self, name):
        return self.rest[self.by_name[PREFIX + name]]

    def frame(self):
        """Куда смотрит скелет: (вперёд, влево) в мировых осях, горизонтально."""
        left = tuple(a - b for a, b in zip(self.rest_of("LeftHand")[1], self.rest_of("RightHand")[1]))
        left = unit((left[0], 0.0, left[2]))
        return cross(left, (0.0, 1.0, 0.0)), left


def yaw_between(src_forward, dst_forward):
    a = math.atan2(src_forward[0], src_forward[2])
    b = math.atan2(dst_forward[0], dst_forward[2])
    return qaxis((0.0, 1.0, 0.0), b - a)


def retarget(rig_doc, rig, clip_path, name, cfg):
    doc, binary = read_glb(clip_path)
    src = Skeleton(doc)
    anim = doc["animations"][0]
    tracks = {}
    for ch in anim["channels"]:
        sampler = anim["samplers"][ch["sampler"]]
        path = ch["target"]["path"]
        if path in ("rotation", "translation"):
            tracks.setdefault(ch["target"]["node"], {})[path[0]] = (
                [t[0] for t in accessor(doc, binary, sampler["input"])], accessor(doc, binary, sampler["output"]))
    times = max((t for tr in tracks.values() for t, _ in tr.values()), key=len)
    times = [t - times[0] for t in times]

    align = yaw_between(src.frame()[0], rig.frame()[0])
    fwd, left = rig.frame()
    # Кисть с луком: у модели лук стоит вертикально при опущенной ладони, а в клипе рука держит лук большим пальцем вверх.
    grip = qaxis(left, math.radians(cfg.get("grip", 90)))
    # Отведение правой руки: поворот в позе покоя, от опущенной руки уводит её в сторону от тела.
    away = unit(cross(tuple(-c for c in left), (0.0, 1.0, 0.0)))
    arm_out = cfg.get("arm_out", {})
    outs = {PREFIX + "RightArm": qaxis(away, math.radians(arm_out.get("arm", 0)))}
    fore = qaxis(away, math.radians(arm_out.get("arm", 0) + arm_out.get("fore", 0)))
    for bone in rig.order:
        if bone.startswith(PREFIX + "RightForeArm") or bone.startswith(PREFIX + "RightHand"):
            outs[bone] = fore
    src_hip = src.rest_of("Hips")
    rig_hip = rig.rest_of("Hips")
    height = rig_hip[1][1] / src_hip[1][1]

    skip = {PREFIX + "LeftHand" + f + str(i) for f in ("Thumb", "Index", "Middle", "Ring", "Pinky") for i in (1, 2, 3, 4)}
    out = {b: [] for b in rig.bones}
    hip_out = []
    for f in range(len(times)):
        pose = {}
        for i, tr in tracks.items():
            pose[i] = {k: tuple(v[1][min(f, len(v[1]) - 1)]) for k, v in tr.items()}
        worlds = {}  # имя кости -> мировой поворот на риге
        for bone in rig.order:
            i_src = src.by_name.get(bone)
            i_rig = rig.by_name[bone]
            rest_rig = rig.rest[i_rig][0]
            parent = rig.parent.get(i_rig)
            parent_name = rig.nodes[parent].get("name") if parent is not None else None
            if i_src is None or bone in skip:
                world = qmul(worlds[parent_name], rig.local(i_rig, {})[0]) if parent_name in worlds else rest_rig
            else:
                delta = qmul(src.world(i_src, pose)[0], qinv(src.rest[i_src][0]))
                delta = qmul(qmul(align, delta), qinv(align))
                pre = grip if bone == PREFIX + "LeftHand" else outs.get(bone, (0, 0, 0, 1))
                world = qmul(delta, qmul(pre, rest_rig))
            worlds[bone] = world
            parent_world = worlds.get(parent_name) or (rig.rest[parent][0] if parent is not None else (0, 0, 0, 1))
            out[bone].append(qnorm(qmul(qinv(parent_world), world)))
        hip_now = src.world(src.by_name[PREFIX + "Hips"], pose)[1]
        move = qrot(align, tuple((a - b) * height for a, b in zip(hip_now, src_hip[1])))
        i_hip = rig.by_name[PREFIX + "Hips"]
        pr, _, ps = rig.world(rig.parent[i_hip], {}) if i_hip in rig.parent else ((0, 0, 0, 1), None, 1.0)
        back = qrot(qinv(pr), tuple(c / ps for c in move))
        hip_out.append(tuple(a + b for a, b in zip(rig.local(i_hip, {})[1], back)))
    return times, out, hip_out


def write(rig_doc, rig, name, times, rotations, hips, target):
    blob = bytearray()
    views, accessors = [], []

    def add(values, kind, minmax=False):
        flat = [c for v in values for c in (v if kind != "SCALAR" else (v,))]
        data = struct.pack(f"<{len(flat)}f", *flat)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)})
        blob.extend(data)
        acc = {"bufferView": len(views) - 1, "componentType": 5126, "count": len(values), "type": kind}
        if minmax:
            acc.update(min=[min(values)], max=[max(values)])
        accessors.append(acc)
        return len(accessors) - 1

    time_acc = add(times, "SCALAR", True)
    samplers, channels = [], []
    for bone, values in rotations.items():
        samplers.append({"input": time_acc, "output": add(values, "VEC4"), "interpolation": "LINEAR"})
        channels.append({"sampler": len(samplers) - 1, "target": {"node": rig.by_name[bone], "path": "rotation"}})
    samplers.append({"input": time_acc, "output": add(hips, "VEC3"), "interpolation": "LINEAR"})
    channels.append({"sampler": len(samplers) - 1, "target": {"node": rig.by_name[PREFIX + "Hips"], "path": "translation"}})

    out = {k: json.loads(json.dumps(rig_doc[k])) for k in ("asset", "scene", "scenes", "nodes", "skins") if k in rig_doc}
    for node in out["nodes"]:
        node.pop("mesh", None)
        node.pop("skin", None)
    # Скелет остаётся в файле без геометрии. Обратные матрицы привязки копируются как есть.
    rig_bin = read_glb(rig.path)[1]
    for skin in out.get("skins", []):
        src = rig_doc["accessors"][skin["inverseBindMatrices"]]
        view = rig_doc["bufferViews"][src["bufferView"]]
        chunk = rig_bin[view.get("byteOffset", 0):view.get("byteOffset", 0) + view["byteLength"]]
        while len(blob) % 4:
            blob.append(0)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(chunk)})
        blob.extend(chunk)
        accessors.append({**src, "bufferView": len(views) - 1})
        skin["inverseBindMatrices"] = len(accessors) - 1
    while len(blob) % 4:
        blob.append(0)
    out.update(animations=[{"name": name, "samplers": samplers, "channels": channels}], accessors=accessors,
               bufferViews=views, buffers=[{"byteLength": len(blob)}])
    text = json.dumps(out, separators=(",", ":"), ensure_ascii=False).encode()
    text += b" " * (-len(text) % 4)
    total = 12 + 8 + len(text) + 8 + len(blob)
    Path(target).write_bytes(struct.pack("<4sII", b"glTF", 2, total) + struct.pack("<I4s", len(text), b"JSON") + text
                             + struct.pack("<I4s", len(blob), b"BIN\0") + bytes(blob))


def main(creature_id):
    base = ROOT / "creatures" / creature_id
    out_dir = ROOT / "game" / "assets" / "creatures" / creature_id / "anims"
    out_dir.mkdir(parents=True, exist_ok=True)
    tmp = base / "mixamo" / "glb"
    tmp.mkdir(exist_ok=True)
    rig_doc, _ = read_glb(base / "tripo" / "rig.glb")
    rig = Skeleton(rig_doc)
    rig.path = base / "tripo" / "rig.glb"
    print("вперёд, влево:", rig.frame())
    clips = json.loads((base / "mixamo" / "clips.json").read_text())
    arm_out = clips.pop("_arm_out", {})
    for fbx, cfg in clips.items():
        cfg["arm_out"] = arm_out
        glb = tmp / (cfg["name"] + ".glb")
        if not glb.exists():
            subprocess.run(["blender", "-b", "--python", str(HERE / "fbx2glb.py"), "--", str(base / "mixamo" / fbx), str(glb)],
                           check=True, capture_output=True)
        times, rotations, hips = retarget(rig_doc, rig, glb, cfg["name"], cfg)
        write(rig_doc, rig, cfg["name"], times, rotations, hips, out_dir / (cfg["name"] + ".glb"))
        print(cfg["name"], f"{times[-1]:.2f} с, кадров {len(times)}")


if __name__ == "__main__":
    main(sys.argv[1])

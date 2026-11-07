"""184: щит Tripo → игровой: центр рамки в нуле, высота 1 по +Y (остриё вниз), толщина по Z, лицо (умбон) к +Z.

blender -b --python pipelines/creature-mixamo-first/prepare_shield.py -- input.glb output.glb
Хват weapon_grip.gd (mode "forearm") ставит его плашмя на предплечье и масштабирует по высоте.
"""
import sys
import bpy
from mathutils import Matrix, Vector

src, dst = sys.argv[sys.argv.index('--') + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
objects = [o for o in bpy.data.objects if o.type == 'MESH']
for o in objects:
    o.data.transform(o.matrix_world)
    o.parent = None
    o.matrix_world.identity()


def points():
    return [v.co.copy() for o in objects for v in o.data.vertices]


def box(ps):
    lo = Vector(tuple(min(p[i] for p in ps) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in ps) for i in range(3)))
    return lo, hi


def apply(m):
    for o in objects:
        o.data.transform(m)


lo, hi = box(points())
size = hi - lo
order = sorted(range(3), key=lambda i: size[i])  # толщина, ширина, высота
thin, wide, tall = order
# Оси Blender: высоту в Z (станет +Y glTF), ширину в X, толщину в Y (−Y Blender = +Z glTF).
basis = Matrix.Identity(3)
cols = [Vector((0, 0, 0)) for _ in range(3)]
target = {wide: Vector((1, 0, 0)), thin: Vector((0, -1, 0)), tall: Vector((0, 0, 1))}
m = Matrix(((0, 0, 0), (0, 0, 0), (0, 0, 0)))
for i in range(3):
    for r in range(3):
        m[r][i] = target[i][r]
if m.determinant() < 0:
    m[0][0], m[1][0], m[2][0] = -m[0][0], -m[1][0], -m[2][0]  # правая тройка: отражаем ширину
apply(m.to_4x4())
lo, hi = box(points())
apply(Matrix.Translation(-(lo + hi) / 2))
lo, hi = box(points())
apply(Matrix.Scale(1.0 / (hi.z - lo.z), 4))
ps = points()
lo, hi = box(ps)
# Остриё вниз: верхняя пятая часть шире нижней.
def width(top):
    band = [p for p in ps if (p.z > hi.z - 0.2 if top else p.z < lo.z + 0.2)]
    return max(p.x for p in band) - min(p.x for p in band)
if width(False) > width(True):
    apply(Matrix.Rotation(3.14159265, 4, 'Y'))
# Лицо — сторона с умбоном: в середине щита точки дальше от плоскости по −Y Blender (это +Z glTF).
ps = points()
middle = [p for p in ps if abs(p.z) < 0.15 and abs(p.x) < 0.15]
front = -min(p.y for p in middle)
back = max(p.y for p in middle)
if back > front:
    apply(Matrix.Rotation(3.14159265, 4, 'Z'))
lo, hi = box(points())
for o in objects:
    o.name = 'Shield'
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_animations=False)
print('SHIELD', [round(x, 3) for x in lo], [round(x, 3) for x in hi], flush=True)

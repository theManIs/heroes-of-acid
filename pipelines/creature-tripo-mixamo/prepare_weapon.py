"""Normalize separate Tripo weapon: +Y toward head, butt at zero, length one.

blender -b --python prepare_weapon.py -- input.glb output.glb
"""
import sys
import bpy
from mathutils import Vector

src, dst = sys.argv[sys.argv.index('--') + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
objects = [o for o in bpy.data.objects if o.type == 'MESH']
points = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
low = Vector(tuple(min(v[i] for v in points) for i in range(3)))
high = Vector(tuple(max(v[i] for v in points) for i in range(3)))
axis = max(range(3), key=lambda i: high[i] - low[i])
side = [i for i in range(3) if i != axis]
def end_width(top):
    values = [v for v in points if (v[axis] > high[axis] - (high[axis]-low[axis])*.22 if top else v[axis] < low[axis]+(high[axis]-low[axis])*.22)]
    return max(max(v[i] for v in values)-min(v[i] for v in values) for i in side)
direction = Vector(tuple((1 if end_width(True) > end_width(False) else -1) if i == axis else 0 for i in range(3)))
rotation = direction.rotation_difference(Vector((0, 0, 1))).to_matrix().to_4x4()
for obj in objects:
    transform = rotation @ obj.matrix_world
    obj.data.transform(transform)
    obj.parent = None
    obj.matrix_world.identity()
points = [v.co for o in objects for v in o.data.vertices]
low = Vector(tuple(min(v[i] for v in points) for i in range(3)))
high = Vector(tuple(max(v[i] for v in points) for i in range(3)))
# Median shaft position avoids centering the handle on the asymmetric beak.
shaft = [v for v in points if low.z + .3*(high.z-low.z) < v.z < low.z + .6*(high.z-low.z)]
center = Vector((sum(v.x for v in shaft)/len(shaft), sum(v.y for v in shaft)/len(shaft), low.z))
length = high.z-low.z
for obj in objects:
    for v in obj.data.vertices:
        v.co = (v.co-center)/length
    obj.name = 'Hammer'
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_animations=False)
print('NORMALIZED', list(low), list(high), 'length', length, flush=True)

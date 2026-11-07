"""185: манекен пайплайна — Mixamo X Bot (лежит в любом скачанном наборе Mixamo как `X Bot.fbx`) → GLB со скелетом
и сеткой, без анимаций, масштаб и поворот FBX применены (кости в метрах, иначе таз клипов улетает),
лицом по +X, как модели Tripo.
blender -b --python pipelines/creature-mixamo-first/mannequin.py -- <X Bot.fbx> game/assets/mannequin/xbot.glb
Затем копия в creatures/<id>/tripo/rig.glb и rig-mannequin.glb — риг для build_clips.py на шаге манекена."""
import sys, bpy
src, dst = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
# Цвет манекена: серая поверхность, тёмные суставы (в FBX — розовая заглушка).
for o in bpy.data.objects:
    if o.type == "MESH":
        dark = "Joint" in o.name
        for slot in o.material_slots:
            mat = slot.material
            mat.use_nodes = True
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            for link in list(bsdf.inputs["Base Color"].links):
                mat.node_tree.links.remove(link)
            bsdf.inputs["Base Color"].default_value = (0.08, 0.08, 0.09, 1) if dark else (0.55, 0.56, 0.58, 1)
            bsdf.inputs["Roughness"].default_value = 0.45 if dark else 0.6
            bsdf.inputs["Metallic"].default_value = 0.0
# Лицом по +X, как модели Tripo: Creature считает, что модель смотрит по +X (FRONT_YAW). X Bot из FBX
# смотрит по +Z glTF (−Y Blender) — без поворота ходит и стоит боком, вынос удара меряется не туда.
import math
for o in bpy.data.objects:
    if o.parent is None:
        o.rotation_euler.z += math.radians(90.0)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_animations=False, export_skins=True, export_yup=True)

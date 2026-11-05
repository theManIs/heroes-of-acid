"""Convert selected local Mixamo pack FBXs in one Blender session.

blender -b --python prepare_pack.py -- hammerer
"""
import json
import sys
from pathlib import Path
import bpy

root = Path(__file__).resolve().parents[2]
creature = sys.argv[sys.argv.index('--') + 1]
base = root / 'creatures' / creature / 'mixamo'
out = base / 'glb'
out.mkdir(exist_ok=True)
clips = json.loads((base / 'clips.json').read_text())
for fbx, cfg in clips.items():
    if fbx.startswith('_'):
        continue
    target = out / (cfg['name'] + '.glb')
    if target.exists():
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(base / fbx))
    bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB',
        export_animations=True, export_skins=True, export_yup=True,
        export_optimize_animation_size=False)
    print('CONVERTED', fbx, cfg['name'], flush=True)

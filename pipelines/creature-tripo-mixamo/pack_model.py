"""Limit embedded GLB textures without changing nodes, bind poses or geometry.

Usage: .venv/bin/python pack_model.py input.glb output.glb [max_texture_size]
"""
import io
import json
import struct
import sys
from pathlib import Path
from PIL import Image
from build_clips import read_glb


def pack(src, dst, limit=1024):
    doc, binary = read_glb(src)
    replacement = {}
    for img in doc.get('images', []):
        if 'bufferView' not in img:
            continue
        index = img['bufferView']
        view = doc['bufferViews'][index]
        start = view.get('byteOffset', 0)
        image = Image.open(io.BytesIO(binary[start:start + view['byteLength']]))
        image.thumbnail((limit, limit), Image.Resampling.LANCZOS)
        stream = io.BytesIO()
        image.save(stream, format='PNG', optimize=True)
        img['mimeType'] = 'image/png'
        replacement[index] = stream.getvalue()
    blob = bytearray()
    for index, view in enumerate(doc['bufferViews']):
        start = view.get('byteOffset', 0)
        chunk = replacement.get(index, binary[start:start + view['byteLength']])
        blob.extend(b'\0' * (-len(blob) % 4))
        view.update(byteOffset=len(blob), byteLength=len(chunk))
        blob.extend(chunk)
    blob.extend(b'\0' * (-len(blob) % 4))
    doc['buffers'] = [{'byteLength': len(blob)}]
    text = json.dumps(doc, separators=(',', ':')).encode()
    text += b' ' * (-len(text) % 4)
    payload = struct.pack('<4sII', b'glTF', 2, 28 + len(text) + len(blob))
    payload += struct.pack('<I4s', len(text), b'JSON') + text
    payload += struct.pack('<I4s', len(blob), b'BIN\0') + blob
    Path(dst).parent.mkdir(parents=True, exist_ok=True)
    Path(dst).write_bytes(payload)
    print(dst, len(payload))


if __name__ == '__main__':
    pack(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 1024)

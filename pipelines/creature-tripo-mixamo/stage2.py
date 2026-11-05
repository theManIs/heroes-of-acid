"""Шаг 2 пайплайна creature-tripo-mixamo: 4 вида → модель → риг со spec: mixamo (Tripo API).

Запуск: .venv/bin/python pipelines/creature-tripo-mixamo/stage2.py <creature_id>

Виды: creatures/<id>/concept/views/{front,left,back,right}.png.
Результат: creatures/<id>/tripo/model.glb и rig.glb. Готовые шаги помнятся в tripo_state.json:
повторный запуск не платит за сделанное.
"""

import asyncio
import json
import sys
import time
from pathlib import Path

from PIL import Image
from tripo3d import TripoClient
from tripo3d.models import TaskStatus

ROOT = Path(__file__).resolve().parents[2]
MODEL_VERSION = "v3.1-20260211"
RIG_VERSION = "v3.0-20260909"
FACE_LIMIT = 20000
PAD = 0.15  # поля вокруг вида, доля стороны


def load_key() -> str:
    for line in (ROOT / ".env").read_text().splitlines():
        if line.startswith("TRIPO_API_KEY="):
            return line.split("=", 1)[1].strip().strip("'\"")
    sys.exit("TRIPO_API_KEY не найден в .env")


def pad_view(src: Path, dst: Path) -> None:
    img = Image.open(src).convert("RGB")
    side = int(max(img.size) * (1 + 2 * PAD))
    canvas = Image.new("RGB", (side, side), img.getpixel((img.width // 2, 2)))
    canvas.paste(img, ((side - img.width) // 2, (side - img.height) // 2))
    canvas.save(dst)


async def run_step(client, state, state_path, name, start):
    if name not in state:
        task_id = await start()
        state[name] = {"task_id": task_id}
        state_path.write_text(json.dumps(state, indent=2))
    if state[name].get("status") != TaskStatus.SUCCESS.value:
        t0 = time.monotonic()
        task_id = state[name]["task_id"]
        print(f"{name}: задача {task_id}", flush=True)
        task = await client.wait_for_task(task_id, verbose=True)
        state[name].update(status=task.status.value, seconds=round(time.monotonic() - t0))
        state_path.write_text(json.dumps(state, indent=2))
        if task.status != TaskStatus.SUCCESS:
            sys.exit(f"{name}: {task.status.value} {task.error_msg or ''}")
    return state[name]["task_id"]


async def fetch(client, task_id, out, target):
    if not target.exists():
        files = await client.download_task_models(await client.get_task(task_id), str(out))
        Path(next(p for p in files.values() if p)).rename(target)


async def main(creature_id: str) -> None:
    views = ROOT / "creatures" / creature_id / "concept" / "views"
    out = ROOT / "creatures" / creature_id / "tripo"
    out.mkdir(exist_ok=True)
    state_path = out / "tripo_state.json"
    state = json.loads(state_path.read_text()) if state_path.exists() else {}

    images = []
    for name in ["front", "left", "back", "right"]:
        padded = out / f"{name}-padded.png"
        pad_view(views / f"{name}.png", padded)
        images.append(str(padded))

    async with TripoClient(api_key=load_key()) as client:
        before = (await client.get_balance()).balance
        print(f"Баланс: {before}")
        model_id = await run_step(client, state, state_path, "model", lambda: client.multiview_to_model(
            images, model_version=MODEL_VERSION, texture_quality="detailed", face_limit=FACE_LIMIT))
        await fetch(client, model_id, out, out / "model.glb")
        await run_step(client, state, state_path, "rig_check", lambda: client.rig_check(model_id))
        rig_id = await run_step(client, state, state_path, "rig", lambda: client.rig(
            model_id, model=RIG_VERSION, rig_type="biped", spec="mixamo"))
        await fetch(client, rig_id, out, out / "rig.glb")
        after = (await client.get_balance()).balance
    print(f"Кредиты: {before} → {after} (потрачено {before - after})")


if __name__ == "__main__":
    asyncio.run(main(sys.argv[1]))

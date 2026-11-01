"""Модель по нескольким видам (Tripo multiview), без рига и анимаций.

Запуск: .venv/bin/python pipelines/creature/stage2_multiview.py <creature_id>

Виды лежат в creatures/<id>/views/: front.png (обязателен), left.png, back.png, right.png.
Результат: creatures/<id>/multiview/model.glb. Готовая задача запоминается в state.json:
повторный запуск не платит второй раз.
"""

import asyncio
import json
import sys
import time
from pathlib import Path

from tripo3d import TripoClient
from tripo3d.models import TaskStatus

from stage2_tripo import FACE_LIMIT, MODEL_VERSION, ROOT, load_key, pad_concept


async def main(creature_id: str) -> None:
    views = ROOT / "creatures" / creature_id / "views"
    out = ROOT / "creatures" / creature_id / "multiview"
    out.mkdir(exist_ok=True)
    state_path = out / "state.json"
    state = json.loads(state_path.read_text()) if state_path.exists() else {}

    images = []
    for name in ["front", "left", "back", "right"]:
        src = views / f"{name}.png"
        if not src.exists():
            images.append(None)
            continue
        padded = out / f"{name}-padded.png"
        pad_concept(src, padded)
        images.append(str(padded))

    async with TripoClient(api_key=load_key()) as client:
        before = (await client.get_balance()).balance
        print(f"Баланс: {before}")
        if "task_id" not in state:
            t0 = time.monotonic()
            state["task_id"] = await client.multiview_to_model(
                images, model_version=MODEL_VERSION, texture_quality="detailed", face_limit=FACE_LIMIT)
            state_path.write_text(json.dumps(state, indent=2))
            print(f"Задача: {state['task_id']}")
            task = await client.wait_for_task(state["task_id"], verbose=True)
            if task.status != TaskStatus.SUCCESS:
                sys.exit(f"Модель: {task.status.value} {task.error_msg or ''}")
            state["seconds"] = round(time.monotonic() - t0)
            state_path.write_text(json.dumps(state, indent=2))
        task = await client.get_task(state["task_id"])
        files = await client.download_task_models(task, str(out))
        path = next(p for p in files.values() if p)
        Path(path).rename(out / "model.glb")
        after = (await client.get_balance()).balance

    state["credits"] = before - after
    state_path.write_text(json.dumps(state, indent=2))
    print(f"Готово за {state.get('seconds')} с, кредиты: {before} → {after} (потрачено {before - after})")


if __name__ == "__main__":
    asyncio.run(main(sys.argv[1]))

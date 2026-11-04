"""Модель четвероногого по концепту через Tripo API, сразу с лимитом треугольников.

Запуск: .venv/bin/python pipelines/creature-quadruped/model.py <id> <concept.png>
Результат: creatures/<id>/tripo/<id>.glb. Кредиты API, готовый шаг помнится в tripo_state.json.
"""

import asyncio
import json
import sys
from pathlib import Path

from tripo3d import TripoClient
from tripo3d.models import TaskStatus

ROOT = Path(__file__).resolve().parents[2]
MODEL_VERSION = "v3.1-20260211"
FACE_LIMIT = 20000


def load_key() -> str:
    for line in (ROOT / ".env").read_text().splitlines():
        if line.startswith("TRIPO_API_KEY="):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise SystemExit("TRIPO_API_KEY not found in .env")


async def main(creature: str, concept: str) -> None:
    out = ROOT / "creatures" / creature / "tripo"
    out.mkdir(parents=True, exist_ok=True)
    state_path = out / "tripo_state.json"
    state = json.loads(state_path.read_text()) if state_path.exists() else {}
    async with TripoClient(api_key=load_key()) as client:
        before = (await client.get_balance()).balance
        if "model" not in state:
            state["model"] = await client.image_to_model(image=concept, model_version=MODEL_VERSION, face_limit=FACE_LIMIT, texture_quality="detailed")
            state_path.write_text(json.dumps(state, indent=2))
        task = await client.wait_for_task(state["model"], verbose=False)
        if task.status != TaskStatus.SUCCESS:
            raise SystemExit(f"{task.status.value} {task.error_msg or ''}")
        files = await client.download_task_models(task, str(out))
        print(files)
        print("Кредиты API:", before, "->", (await client.get_balance()).balance)


asyncio.run(main(sys.argv[1], sys.argv[2]))

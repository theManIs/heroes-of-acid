"""Риг четвероногого и ходьба через Tripo API (кредиты API).

Запуск: .venv/bin/python pipelines/creature-quadruped/rig.py <id> [версия рига]
Результат: creatures/<id>/tripo/api-<версия>/, номера задач в tripo_state.json, повторный запуск не платит второй раз.
"""

import asyncio
import json
import sys
from pathlib import Path

from tripo3d import TripoClient
from tripo3d.models import TaskStatus

ROOT = Path(__file__).resolve().parents[2]
WALK = "preset:quadruped:walk"


def load_key() -> str:
    for line in (ROOT / ".env").read_text().splitlines():
        if line.startswith("TRIPO_API_KEY="):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise SystemExit("TRIPO_API_KEY not found in .env")


async def finish(client, task_id: str, out: Path) -> None:
    task = await client.wait_for_task(task_id, verbose=False)
    if task.status != TaskStatus.SUCCESS:
        raise SystemExit(f"{task.status.value} {task.error_msg or ''}")
    out.mkdir(parents=True, exist_ok=True)
    print(await client.download_task_models(task, str(out)))


async def main(creature: str, version: str) -> None:
    base = ROOT / "creatures" / creature / "tripo"
    state_path = base / "tripo_state.json"
    state = json.loads(state_path.read_text())
    out = base / f"api-{version}"
    async with TripoClient(api_key=load_key()) as client:
        before = (await client.get_balance()).balance
        rig_key, walk_key = f"rig-{version}", f"walk-{version}"
        if rig_key not in state:
            state[rig_key] = await client.rig_model(state["model"], model_version=version, rig_type="quadruped", spec="tripo")
            state_path.write_text(json.dumps(state, indent=2))
        await finish(client, state[rig_key], out / "rig")
        if walk_key not in state:
            state[walk_key] = await client.retarget(state[rig_key], animations=[WALK], export_with_geometry=True, animate_in_place=True)
            state_path.write_text(json.dumps(state, indent=2))
        await finish(client, state[walk_key], out / "walk")
        print("Кредиты API:", before, "->", (await client.get_balance()).balance)


asyncio.run(main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "v3.0-20260909"))

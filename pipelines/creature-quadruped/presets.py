"""Пресеты Tripo на готовом риге существа, кредиты API: 10 за пресет.

Запуск: .venv/bin/python pipelines/creature-quadruped/presets.py <id> <имя партии> <версия рига> <пресет> [...]
Результат: creatures/<id>/tripo/api-<версия>/<имя партии>/, номер задачи в tripo_state.json, повторный запуск не платит.
"""

import asyncio
import json
import sys
from pathlib import Path

from tripo3d import TripoClient
from tripo3d.models import TaskStatus

ROOT = Path(__file__).resolve().parents[2]


def load_key() -> str:
    for line in (ROOT / ".env").read_text().splitlines():
        if line.startswith("TRIPO_API_KEY="):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise SystemExit("TRIPO_API_KEY not found in .env")


async def main(creature: str, batch: str, version: str, presets: list) -> None:
    base = ROOT / "creatures" / creature / "tripo"
    state_path = base / "tripo_state.json"
    state = json.loads(state_path.read_text())
    key = f"{batch}-{version}"
    out = base / f"api-{version}" / batch
    async with TripoClient(api_key=load_key()) as client:
        before = (await client.get_balance()).balance
        if key not in state:
            state[key] = await client.retarget(state[f"rig-{version}"], animations=presets, export_with_geometry=True, animate_in_place=False)
            state_path.write_text(json.dumps(state, indent=2))
        task = await client.wait_for_task(state[key], verbose=False)
        print(task.status.value, task.error_msg or "")
        if task.status == TaskStatus.SUCCESS:
            out.mkdir(parents=True, exist_ok=True)
            print(await client.download_task_models(task, str(out)))
        print("Кредиты API:", before, "->", (await client.get_balance()).balance)


asyncio.run(main(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]))

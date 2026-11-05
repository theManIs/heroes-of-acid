"""Риг Mixamo для уже оплаченной модели Tripo, без повторной генерации модели.

Запуск: .venv/bin/python pipelines/creature-tripo-mixamo/rig_existing.py <id>
Источник: tripo/tripo_state.json:model. Отдельное состояние: mixamo_rig_state.json.
"""
import asyncio
import json
import sys
from pathlib import Path

from tripo3d import TripoClient
from tripo3d.models import TaskStatus

from stage2 import ROOT, RIG_VERSION, load_key, fetch


async def main(creature_id):
    out = ROOT / "creatures" / creature_id / "tripo"
    source = json.loads((out / "tripo_state.json").read_text())["model"]["task_id"]
    path = out / "mixamo_rig_state.json"
    state = json.loads(path.read_text()) if path.exists() else {"model_task_id": source}
    if state["model_task_id"] != source:
        raise ValueError("Модель изменилась, требуется отдельное состояние рига")

    def save():
        path.write_text(json.dumps(state, indent=2) + "\n")

    async with TripoClient(api_key=load_key()) as client:
        before = (await client.get_balance()).balance
        if "balance_before" not in state:
            state["balance_before"] = before
            save()
        for name, start in [
            ("rig_check", lambda: client.rig_check(source)),
            ("rig", lambda: client.rig(source, model=RIG_VERSION, rig_type="biped", spec="mixamo")),
        ]:
            if name not in state:
                state[name] = {"task_id": await start()}
                save()  # запомнить оплаченную задачу до ожидания, не создавать её повторно
            task_id = state[name]["task_id"]
            print(name, task_id, flush=True)
            task = await client.wait_for_task(task_id, verbose=True)
            state[name]["status"] = task.status.value
            save()
            if task.status != TaskStatus.SUCCESS:
                raise RuntimeError(f"{name}: {task.status.value} {task.error_msg or ''}")
        await fetch(client, state["rig"]["task_id"], out, out / "rig.glb")
        state["balance_after"] = (await client.get_balance()).balance
        save()
        print("Кредиты:", state["balance_before"], "→", state["balance_after"])


if __name__ == "__main__":
    asyncio.run(main(sys.argv[1]))

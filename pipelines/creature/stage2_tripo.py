"""Этап 2 пайплайна: концепт → модель → риг → 5 анимаций (Tripo API).

Запуск: .venv/bin/python pipelines/creature/stage2_tripo.py <creature_id>

Готовые шаги запоминаются в creatures/<id>/tripo/tripo_state.json: повторный запуск
продолжает с упавшего шага и не платит второй раз за уже сделанное.
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
RIG_VERSION = "v1.0-20240301"  # 90+ пресетов preset:biped:* — из них подбираем удар и стойку
# Tripo принимает до 5 анимаций за задачу. Первая партия идёт с геометрией (<id>.glb),
# остальные — только скелет и анимации (<id>-anims<N>.glb), Godot подмешивает их к модели.
ANIMATION_BATCHES = [
    # Партия 1 (с геометрией): стоячие — без «на месте».
    ["preset:biped:idle", "preset:biped:hit_to_body_01", "preset:biped:fall"],
    # Партия 2: ходьба — «на месте». Удар и своя стойка подбираются потом по одной (tripo.json).
    ["preset:biped:walk"],
]
FACE_LIMIT = 20000  # треугольников; без предела Tripo отдаёт ~1,5 млн
PAD = 0.15  # поля вокруг концепта, доля стороны


def load_key() -> str:
    for line in (ROOT / ".env").read_text().splitlines():
        if line.startswith("TRIPO_API_KEY="):
            return line.split("=", 1)[1].strip().strip("'\"")
    sys.exit("TRIPO_API_KEY не найден в .env")


def pad_concept(src: Path, dst: Path) -> None:
    img = Image.open(src).convert("RGB")
    w, h = img.size
    bg = img.getpixel((w // 2, 2))  # цвет фона у верхнего края
    side = int(max(w, h) * (1 + 2 * PAD))
    canvas = Image.new("RGB", (side, side), bg)
    canvas.paste(img, ((side - w) // 2, (side - h) // 2))
    canvas.save(dst)


async def run_step(client, state, name, start, report):
    if name in state:
        print(f"{name}: уже готов ({state[name]['task_id']})")
        return state[name]["task_id"]
    t0 = time.monotonic()
    task_id = await start()
    print(f"{name}: задача {task_id}")
    task = await client.wait_for_task(task_id, verbose=True)
    secs = round(time.monotonic() - t0)
    if task.status != TaskStatus.SUCCESS:
        sys.exit(f"{name}: {task.status.value} {task.error_msg or ''}")
    state[name] = {"task_id": task_id, "seconds": secs}
    report.append((name, task_id, secs))
    return task_id


def load_config(out: Path) -> None:
    """creatures/<id>/tripo/tripo.json переопределяет риг и анимации существа:
    {"rig_version": "...", "animation_batches": [[...], [...]]}."""
    global RIG_VERSION, ANIMATION_BATCHES
    path = out / "tripo.json"
    if path.exists():
        cfg = json.loads(path.read_text())
        RIG_VERSION = cfg.get("rig_version", RIG_VERSION)
        ANIMATION_BATCHES = cfg.get("animation_batches", ANIMATION_BATCHES)


async def main(creature_id: str) -> None:
    concept = ROOT / "creatures" / creature_id / "concept"
    out = ROOT / "creatures" / creature_id / "tripo"
    out.mkdir(exist_ok=True)
    load_config(out)
    state_path = out / "tripo_state.json"
    state = json.loads(state_path.read_text()) if state_path.exists() else {}
    report = []

    padded = concept / "concept-padded.png"
    if not padded.exists():
        pad_concept(concept / "concept.png", padded)

    async with TripoClient(api_key=load_key()) as client:
        balance_before = (await client.get_balance()).balance
        print(f"Баланс: {balance_before}")
        try:
            model_id = await run_step(client, state, "model", lambda: client.image_to_model(
                str(padded), model_version=MODEL_VERSION, texture_quality="detailed", face_limit=FACE_LIMIT), report)
            rig_id = await run_step(client, state, "rig", lambda: client.rig(
                model_id, model=RIG_VERSION, rig_type="biped", spec="tripo"), report)
            outputs = []
            for i, batch in enumerate(ANIMATION_BATCHES):
                step = "animations" if i == 0 else f"animations{i + 1}"
                name = f"{creature_id}.glb" if i == 0 else f"{creature_id}-anims{i + 1}.glb"
                # «На месте» только для ходьбы/бега: у стоячих анимаций Tripo прибивает таз,
                # и ступни скользят. Поэтому ходьбу и бег держать в отдельной партии.
                in_place = any(a.endswith((":walk", ":run")) for a in batch)
                anim_id = await run_step(client, state, step, lambda b=batch, g=(i == 0), p=in_place: client.retarget(
                    rig_id, animations=b, export_with_geometry=g, animate_in_place=p), report)
                outputs.append((anim_id, out / name))
        finally:
            state_path.write_text(json.dumps(state, indent=2))

        for anim_id, target in outputs:
            if target.exists():
                continue
            files = await client.download_task_models(await client.get_task(anim_id), str(out))
            Path(next(p for p in files.values() if p)).rename(target)
        balance_after = (await client.get_balance()).balance

    lines = [f"# Отчёт этапа 2 — {creature_id}", "",
             f"Модель {MODEL_VERSION} (face_limit {FACE_LIMIT}), риг {RIG_VERSION} (biped, tripo), анимации: {' | '.join(', '.join(b) for b in ANIMATION_BATCHES)}.", "",
             "| Шаг | Задача | Секунд |", "|---|---|---|"]
    lines += [f"| {n} | {t} | {s} |" for n, t, s in report]
    lines += ["", f"Кредиты: {balance_before} → {balance_after} (потрачено {balance_before - balance_after})."]
    (out / "report.md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    asyncio.run(main(sys.argv[1]))

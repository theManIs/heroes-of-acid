"""Новая текстура на готовой модели Tripo по 4 видам. Геометрия та же.

Запуск: .venv/bin/python pipelines/creature-recolor/retexture.py <creature_id> <папка_видов> <имя_генерации> [original_image|geometry]

Виды: front обязателен, ещё хотя бы один из left, back, right. geometry — если поза на картинках не совпадает с моделью.

Всё по генерации лежит в creatures/<id>/tripo/generations/<имя>/: входные виды, какими их отправили,
request.json (параметры), state.json (задача, цена), model.glb, рендер Tripo. Строка добавляется в
creatures/<id>/tripo/generations/README.md. Готовая задача помнится: повторный запуск не платит второй раз.
"""

import asyncio
import json
import shutil
import struct
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

from PIL import Image
from tripo3d import TripoClient
from tripo3d.models import TaskStatus

ROOT = Path(__file__).resolve().parents[2]
TEXTURE_VERSION = "v3.0-20250812"  # по документации Tripo: для моделей v3.0 и v3.1
QUALITY = "detailed"
PAD = 0.15  # те же поля, что при генерации модели: вид совпадает с геометрией
VIEWS = ["front", "left", "back", "right"]


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


def source_model(tripo: Path) -> str:
    """Задача модели: tripo_state.json (модель и риг одним скриптом) или multiview/state.json."""
    state = tripo / "tripo_state.json"
    if state.exists():
        return json.loads(state.read_text())["model"]["task_id"]
    return json.loads((tripo / "multiview" / "state.json").read_text())["task_id"]


def fetch(url: str, target: Path) -> None:
    """Докачка с повторами: на медленной связи загрузка обрывается. Длину сверяем с заголовком GLB."""
    part = target.with_suffix(".part")
    for _ in range(30):
        subprocess.run(["curl", "-s", "-L", "-C", "-", "--connect-timeout", "30", "-m", "90", "-o", str(part), url])
        head = part.read_bytes()[:12] if part.exists() else b""
        if len(head) == 12 and struct.unpack("<I", head[8:12])[0] == part.stat().st_size:
            part.rename(target)
            return
    sys.exit("Модель не докачалась, запусти ещё раз: задача оплачена, второй раз не платим")


async def main(creature_id: str, views_dir: str, name: str, alignment: str = "original_image") -> None:
    tripo = ROOT / "creatures" / creature_id / "tripo"
    out = tripo / "generations" / name
    out.mkdir(parents=True, exist_ok=True)
    state_path = out / "state.json"
    state = json.loads(state_path.read_text()) if state_path.exists() else {}
    source_task = source_model(tripo)

    padded = []
    views = [view for view in VIEWS if (ROOT / views_dir / f"{view}.png").exists()]
    for view in views:
        shutil.copy(ROOT / views_dir / f"{view}.png", out / f"input-{view}.png")
        pad_view(out / f"input-{view}.png", out / f"sent-{view}.png")
        padded.append(out / f"sent-{view}.png")
    request = {"source_model_task": source_task, "views_from": views_dir, "texture_version": TEXTURE_VERSION,
               "texture_quality": QUALITY, "texture_alignment": alignment, "views": views, "pad": PAD}
    (out / "request.json").write_text(json.dumps(request, indent=2, ensure_ascii=False))

    async with TripoClient(api_key=load_key()) as client:
        before = (await client.get_balance()).balance
        print(f"Баланс: {before}")
        if "task_id" not in state:
            images = []
            for view, path in zip(views, padded):
                images.append({view: await client._resolve_input(str(path))})
                print(f"Загружен вид: {view}", flush=True)
            state["task_id"] = await client.texture_model(
                source_task, model_version=TEXTURE_VERSION, texture_quality=QUALITY, texture_alignment=alignment, texture_prompt={"images": images})
            state["started"] = datetime.now().isoformat(timespec="seconds")
            state_path.write_text(json.dumps(state, indent=2))
            print(f"Задача: {state['task_id']}", flush=True)
        t0 = time.monotonic()
        task = await client.wait_for_task(state["task_id"], verbose=True)
        if task.status != TaskStatus.SUCCESS:
            sys.exit(f"Текстура: {task.status.value} {task.error_msg or ''}")
        state.setdefault("seconds", round(time.monotonic() - t0))
        files = await client.download_task_models(await client.get_task(state["task_id"]), str(out))
        output = (await client.get_task(state["task_id"])).output
        if not (out / "model.glb").exists():
            fetch(getattr(output, "pbr_model", None) or output.model, out / "model.glb")
        render = getattr(output, "rendered_image", None)
        if render and not (out / "render.webp").exists():
            subprocess.run(["curl", "-s", "-L", "-m", "90", "-o", str(out / "render.webp"), render])
        after = (await client.get_balance()).balance
    if "credits" not in state:
        state["credits"] = before - after
    state_path.write_text(json.dumps(state, indent=2))

    if not (out / "model.glb").exists():
        sys.exit("Модель не скачалась")
    log = tripo / "generations" / "README.md"
    if not log.exists():
        log.write_text("# Генерации\n\n| Имя | Что на входе | Исходная модель | Задача | Настройки | Кредиты |\n|---|---|---|---|---|---|\n")
    with log.open("a") as f:
        if name in log.read_text():
            print("Строка уже в журнале")
            return
        f.write(f"| `{name}` | `{views_dir}` (копии в папке генерации) | `{source_task}` | `{state['task_id']}` | текстура {TEXTURE_VERSION}, {QUALITY}, {alignment} | {state['credits']} |\n")
    print(f"Готово за {state['seconds']} с, кредиты: {before} → {after}")


if __name__ == "__main__":
    asyncio.run(main(*sys.argv[1:5]))

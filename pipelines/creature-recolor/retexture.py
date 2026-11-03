"""Новая текстура на готовой модели Tripo по 4 видам. Геометрия та же.

Запуск: .venv/bin/python pipelines/creature-recolor/retexture.py <creature_id> <папка_видов> <имя_генерации>

Всё по генерации лежит в creatures/<id>/tripo/generations/<имя>/: входные виды, какими их отправили,
request.json (параметры), state.json (задача, цена), model.glb, рендер Tripo. Строка добавляется в
creatures/<id>/tripo/generations/README.md. Готовая задача помнится: повторный запуск не платит второй раз.
"""

import asyncio
import json
import shutil
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


async def main(creature_id: str, views_dir: str, name: str) -> None:
    tripo = ROOT / "creatures" / creature_id / "tripo"
    out = tripo / "generations" / name
    out.mkdir(parents=True, exist_ok=True)
    state_path = out / "state.json"
    state = json.loads(state_path.read_text()) if state_path.exists() else {}
    source_task = json.loads((tripo / "tripo_state.json").read_text())["model"]["task_id"]

    padded = []
    for view in VIEWS:
        shutil.copy(ROOT / views_dir / f"{view}.png", out / f"input-{view}.png")
        pad_view(out / f"input-{view}.png", out / f"sent-{view}.png")
        padded.append(out / f"sent-{view}.png")
    request = {"source_model_task": source_task, "views_from": views_dir, "texture_version": TEXTURE_VERSION,
               "texture_quality": QUALITY, "texture_alignment": "original_image", "pad": PAD}
    (out / "request.json").write_text(json.dumps(request, indent=2, ensure_ascii=False))

    async with TripoClient(api_key=load_key()) as client:
        before = (await client.get_balance()).balance
        print(f"Баланс: {before}")
        if "task_id" not in state:
            images = []
            for view, path in zip(VIEWS, padded):
                images.append({view: await client._resolve_input(str(path))})
                print(f"Загружен вид: {view}", flush=True)
            state["task_id"] = await client.texture_model(
                source_task, model_version=TEXTURE_VERSION, texture_quality=QUALITY, texture_prompt={"images": images})
            state["started"] = datetime.now().isoformat(timespec="seconds")
            state_path.write_text(json.dumps(state, indent=2))
            print(f"Задача: {state['task_id']}", flush=True)
        t0 = time.monotonic()
        task = await client.wait_for_task(state["task_id"], verbose=True)
        if task.status != TaskStatus.SUCCESS:
            sys.exit(f"Текстура: {task.status.value} {task.error_msg or ''}")
        state.setdefault("seconds", round(time.monotonic() - t0))
        files = await client.download_task_models(await client.get_task(state["task_id"]), str(out))
        # В ответе может быть и рендер: модель выбираем по расширению, рендер сохраняем отдельно.
        for path in filter(None, files.values()):
            Path(path).rename(out / ("model.glb" if str(path).endswith(".glb") else "render.webp"))
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
        f.write(f"| `{name}` | `{views_dir}` (копии в папке генерации) | `{source_task}` | `{state['task_id']}` | текстура {TEXTURE_VERSION}, {QUALITY} | {state['credits']} |\n")
    print(f"Готово за {state['seconds']} с, кредиты: {before} → {after}")


if __name__ == "__main__":
    asyncio.run(main(*sys.argv[1:4]))

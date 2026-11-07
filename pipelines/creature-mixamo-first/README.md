# Пайплайн: гуманоид, сначала анимации (основной, задача 181)

Заменяет `creature` и `creature-tripo-mixamo` (решение пользователя 2026-11-07). Порядок: **анимации на манекене →
концепт → модель → оружие и щит отдельно → клипы на модели → автопроверка → витрина**. Модель делаем под уже
выбранные движения, а не ищем движения под готовую модель.

Перед началом: прочитать [ERRORS.md](ERRORS.md) — решённые ошибки и как их ловит автопроверка.
Инструменты прежнего пайплайна (`stage2.py`, `build_clips.py`, `pack_model.py`, `weapon.py`, `prepare_weapon.py`,
`prepare_pack.py`, `fbx2glb.py`) остаются в `pipelines/creature-tripo-mixamo/` и вызываются оттуда.

## 1. Бриф

Со слов пользователя и листа: роль, оружие (одноручное, двуручное, древковое, лук), щит, дальний бой.
Рост — по гексу (`HEX_RADIUS` 0,6), не «крупнее соседа» (E12).

## 2. Анимации на манекене (до концепта)

1. Манекен — тело прежнего молотобойца без молота, риг Mixamo:
   `creatures/<id>/tripo/rig.glb` ← копия `creatures/hammerer/tripo/rig.glb`; ещё одна копия — `tripo/rig-mannequin.glb`.
2. Кандидаты по локальному каталогу `catalogs/mixamo` под оружие с листа (M01): на каждую роль 2–4 клипа.
   Роли: стойка, шаг, бег, удар (и второй режим, если есть), реакция, защита, смерть, отклик.
3. Скачать с mixamo.com через Chrome: FBX Binary, `Without Skin`, 30 fps, шаг и бег — галка `In Place`
   (проверять по экрану: сбрасывается при смене клипа). Файлы — `creatures/<id>/mixamo/search/`.
4. `creatures/<id>/mixamo/clips.json`: у каждого клипа `"grip": 0, "keep_left_fingers": false` (кроме лука);
   имена кандидатов `c_<роль>_<что>`; руки из стойки — `arms_from` (E09).
   Сборка: `.venv/bin/python pipelines/creature-tripo-mixamo/build_clips.py <id>`.
5. `creatures/<id>/mixamo/candidates.json` — квадраты витрины и заглушки оружия (`game/scenes/weapon_grip.gd`):
   ```json
   {"idle": "c_idle_shield", "size": 1.8,
    "props": [{"hand": "Right", "mode": "fist", "shape": "axe", "length": 0.42, "grip_at": 0.12},
              {"hand": "Left", "mode": "forearm", "shape": "shield", "length": 0.36, "width": 0.26}],
    "cells": [["Стойка: …", "c_idle_shield", true], ["Удар: …", "c_attack_chop", false]]}
   ```
6. Отсев без пользователя: `check_clips.gd -- --set=<id>` (см. ниже). Провалы и явные «ВНИМАНИЕ» (таз уезжает,
   стопы едут, оружие сквозь тело) — не показывать, искать замену.
7. Витрина кандидатов: `godot --path game res://scenes/mannequin_search.tscn -- --id=<id>`. Выбирает пользователь.
   Выбранные клипы получают игровые имена через `aliases` в `clips.json`.

## 3. Концепт

ChatGPT в Chrome, один чат на всё существо (M26). T-поза, тело **без оружия и щита** (M20–M25).
Отдельные технические референсы оружия и щита — в том же чате, промпты сохранить рядом.
Виды `front`, `left`, `back`, `right` → `creatures/<id>/concept/views/`. Показать и дождаться подтверждения.

## 4. Модель и риг

`.venv/bin/python pipelines/creature-tripo-mixamo/stage2.py <id>` — модель 40 + риг `spec: mixamo` 25 кредитов,
`face_limit` 20 000 (E02). Риг манекена остаётся в `tripo/rig-mannequin.glb`.
`pack_model.py` → `game/assets/creatures/<id>/body.glb`, текстуры до 1024 px. Номер оплаченной задачи — в состояние
до ожидания (M30).

## 5. Оружие и щит

`weapon.py` (около 40 кредитов на предмет) → `prepare_weapon.py` (длинная ось +Y, начало у торца; направление
проверить замером, M31) → `game/assets/creatures/<id>/<предмет>.glb`. В игре — `weapon_grip.gd` с `model`, тем же
`hand`, `mode`, `length`, `grip_at`, что у заглушки. Поворот рабочей стороны — один раз (`roll`), не по ходу клипа (E13).

## 6. Клипы на модели

Риг модели вместо рига манекена в `tripo/rig.glb`, тот же `clips.json`: `build_clips.py <id>` пересобирает выбранный
набор. Если бёдра в покое разведены — `"_match_leg_rest": true` (E04).

## 7. В игру

Запись существа (в `CREATURES` или свой `<id>_config.gd`): клипы ролей, `weapon_face` для проверки E13,
`fidget_on_hover`, `walk_speed` по замеру `tools/pose_sheet.tscn`. В бою — `MOVES`, `START_ROWS`. Пиктограмма:
`godot --path game res://tools/icon_shot.tscn -- --id=<id>`, затем `--import` (M42).

## 8. Автопроверка

```bash
pipelines/creature-mixamo-first/check.sh <id>
```

Клипы и кости (`check_clips.gd`) плюс тест существа, бой и витрина без окна на ошибки в логе. Цель — ноль провалов.
«ВНИМАНИЕ» — снять кадр клипа в указанную секунду, решить по ERRORS.md. Отдельный запуск по костям:
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script "$PWD/pipelines/creature-mixamo-first/check_clips.gd" -- --id=<id> --verbose=1`.

## 9. Финал

[Отдельная витрина существа](../README.md#финал-работы-над-существом): `showcase.tscn -- --creature=<id>`,
строка в `SCENES.md`. Чат ChatGPT — архивировать после всей задачи.

# Ополченец, новый (задача 184)

Пайплайн `creature-mixamo-first`. Прежний ополченец (`creatures/militiaman/`) остаётся в игре до замены.
Концепт — финальный `creatures/militiaman/references/militiaman-final.jpg`; топор и щит — отдельные модели.

## Шаг 2 — анимации на манекене (2026-11-07)

- Манекен: Mixamo X Bot (185), `tripo/rig.glb` = `rig-mannequin.glb` = `game/assets/mannequin/xbot.glb`; исходник `tripo/xbot.fbx`.
  Первый прогон был на теле молотобойца — пользователь попросил настоящий манекен; итог автопроверки тот же.
- Наборы Mixamo (FBX, 30 fps, T-pose): `mixamo/packs/Pro Melee Axe Pack/` (47, топор в правой, левая свободна)
  и `mixamo/packs/Sword And Shield Pack/` (49, одноручное + щит). Собрано 45 кандидатов: `a_*` — топор, `s_*` — щит.
  У всех, кроме смертей, `hip_scale: 0`.
- Отсев `check_clips.gd --set=militiaman2`: убраны атаки с выпадом — стопы проезжают 0,5–1,3 м (E06):
  `a_attack_back`, `a_attack_combo1–3`, `s_slash2–5`, `s_attack1–3`, `s_kick`.
  Шаг и бег обоих наборов уводят стопу под землю на 6–12 см (E07) — оставлены как единственные кандидаты роли.
- У набора топора нет смерти; смешивать наборы нельзя (M02).
- Витрина: `godot --path game res://scenes/mannequin_search.tscn -- --id=militiaman2`, 33 квадрата,
  заглушки топора (правая кисть) и щита (левое предплечье).

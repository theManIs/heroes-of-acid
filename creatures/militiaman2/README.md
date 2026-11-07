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

## Набор утверждён (2026-11-07)

Обычный режим (набор «топор»): idle ← `a_idle`, walk ← `inplace/Standing Walk Forward.fbx` (In Place), run ← `inplace/Standing Run Forward.fbx`,
attack ← `a_attack_down`, hurt ← `a_hurt_gut`, defend ← `a_block_react`, fall ← `s_death1` (в наборе топора смерти нет), fidget ← `a_taunt_thump`.
Стойка со щитом (186, набор «меч и щит»): shield_up ← `s_block1`, shield_idle ← `s_block_idle`, shield_walk ← `inplace/Sword And Shield Walk.fbx`
с руками из `s_block_idle`, shield_hurt ← `s_impact1` (Blocked Impact), shield_down ← `s_block2`.
Запись — `game/scenes/militiaman2_config.gd`; в бой не выходит, пока манекен (`in_battle: false`). walk_speed 1,04 по замеру стопы.
Стопа уходила в землю на 8–10 см: `Creature._align_hips` подгонял высоту таза шага к низкой стойке с топором; для скелета Mixamo
высота таза теперь не трогается. Автопроверка `check.sh militiaman2`: провалов 0.

Дальше по пайплайну: концепт → модель → топор и щит отдельно → клипы на модели.

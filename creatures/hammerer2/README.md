# Молотобоец, новая модель (задача 168)

Пайплайн: `creature-tripo-mixamo`.

- Концепт: картинка пользователя с рогатым шлемом `concept/front.png`; виды `concept/views/` (ChatGPT, тот же чат).
- Tripo: модель `ae3603b6…`, риг `e7f15389…`, 65 кредитов (510 → 445). `tripo/rig.glb` → `game/assets/creatures/hammerer2/body.glb` (`pack_model.py`).
- Клипы: набор 167 из FBX прежнего молотобойца (`mixamo/clips.json`, пути `../../hammerer/mixamo/…`), `build_clips.py hammerer2`.
- Молот прежний (`assets/creatures/hammerer/hammer.glb`), хват `hammer_grip.gd` без изменений.
- `hammerer_config.gd`: сцена, клипы и пиктограмма из `hammerer2`, рост 2,3 (псарь 2,0), шаг 1,43, витрина 3,2.
- Прежняя модель и клипы остаются в `hammerer/`.

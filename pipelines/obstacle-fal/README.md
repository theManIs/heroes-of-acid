# Пайплайн: преграда на поле боя, Meshy через fal (проба, задача 101)

Ключ: `FAL_KEY` в `.env`, значение нигде не печатать. Запуск из корня проекта.

1. `python3 -I pipelines/obstacle-fal/generate.py <name> "<запрос>"`. Модель `fal-ai/meshy/v6/text-to-3d`, режим `full`, 4–7 минут, около 5 МБ. Результат: `obstacles/generations/<name>/`.
2. Скопировать `model.glb` в `game/assets/obstacles/<name>.glb`, запустить `godot --headless --path game --import`.
3. В `game/scenes/battle_test.gd` добавить в `OBSTACLES` и `OBSTACLE_WIDTH`, цвет при необходимости в `OBSTACLE_TINT`.
4. Проверять на кадре из игры.

**Заметки:** запрос «сухое дерево» дал пень, валун вышел слишком светлым и приглушён через `OBSTACLE_TINT`. Точную цену в деньгах не смотрел: на странице fal указано 30 кредитов за модель в режиме `full`.

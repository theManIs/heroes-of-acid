# Псарь: журнал работ

Половина существа «Псарь с собакой» (задача 109). Гуманоид, пайплайн `creature`, кроме концепта: он сделан через fal, `pipelines/creature-quadruped/concept.py`.

- Концепт: `concept/v1.png`, копия `concept/concept.png`. Принят пользователем. Стёганка темнее, чем на его листе. Цепи нет.
- Модель и риг: `tripo/houndmaster.glb`, 19 117 треугольников, 41 кость, анимаций в файле нет. 65 кредитов API, баланс 785. Первая попытка упала с «Internal processing error», кредиты не списала.
- `tripo/tripo.json`: `animation_batches` пуст, анимации из `game/assets/animations/`, бесплатно.
- На витрине: запись `NEW_CREATURES` в `game/scenes/showcase.gd`. Удар `box_01`, реакция `hit_to_head`, защита `hit_to_side`: взяты как пробные.
- Нет: бега, отклика, пиктограммы, места в бою.

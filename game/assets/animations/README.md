# Библиотека анимаций

Пресеты Tripo (`preset:biped:*`), скелет 41 кость (риг `v1.0-20240301`, `spec: tripo`). Подходят к любому такому ригу: `creature.gd` пересчитывает их на его позу покоя.
Папку можно передавать отдельно: в файлах только скелет и движение, геометрии и текстур нет.

В записи существа: `"extra": ["res://assets/animations/chop.glb", …]`. Новая модель: только модель и риг (65 кредитов). Если на сильно другом теле перенос выглядит плохо, анимацию заказывают для него отдельно.

Собирается скриптом `pipelines/creature/build_animation_library.py`.

| Пресет | С какого рига |
|---|---|
| `afraid` | ghoul |
| `box_01` | boilerman |
| `box_02` | flesh-golem |
| `chop` | militiaman |
| `cross_body_crunch` | boilerman |
| `fall` | militiaman |
| `fold_arms` | flesh-golem |
| `football_save` | flesh-golem |
| `hit_to_body_01` | militiaman |
| `hit_to_head` | militiaman |
| `hit_to_side` | vampire |
| `idle` | militiaman |
| `look_around` | ghoul |
| `pitch_baseball` | ghoul |
| `scared_01` | militiaman |
| `slash` | vampire |
| `standing_relax` | vampire |
| `walk` | militiaman |

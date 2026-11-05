# Конь для всадника — журнал (задача 159)

Пайплайн `creature-quadruped`, как собака: модель Tripo, скелет и анимации донора, привязка в Blender.

## Донор (2026-11-06)

Quaternius, poly.pizza, лицензия на странице: «Public Domain (CC0)», тот же набор, что хаски собаки.
- Horse — https://poly.pizza/m/qvTrSG9pZF , файл https://static.poly.pizza/d37dbc87-ca61-4b2c-a2da-d2f0c4240bef.glb
  → `donors/quaternius-horse/horse.glb`
- White Horse — https://poly.pizza/m/bEdE4rmZy9 , файл https://static.poly.pizza/3edc2bd9-3378-4b43-a50d-d5e1f858562b.glb
  → `donors/quaternius-white-horse/white-horse.glb` (тот же скелет и клипы, другая окраска)

Скелет 50 костей. Клипы (у каждого есть копия с приставкой `AnimalArmature|`, каналов столько же):

| Клип | Длина | Для всадника |
|---|---|---|
| Idle, Idle_2, Idle_Headlow | 3,33 с | стойка, отклик |
| Eating | 6,0 с | отклик (щиплет траву) |
| Walk | 1,17 с | шаг |
| Gallop | 0,58 с | бег и разгон тарана |
| Attack_Headbutt | 1,0 с | бросок головой |
| Attack_Kick | 1,0 с | удар задними ногами |
| Idle_HitReact_Left, Right | 0,67 с | реакция |
| Death | 1,0 с | смерть, падает на бок |
| Gallop_Jump, Jump_toIdle | 1,46 / 1,71 с | прыжок |

Рыси нет: шаг и галоп. Кадры всех клипов: `screens/current/horse-donor.png` (лабораторная копия
`game/assets/creatures/horse/lab/donor_horse.glb`). Первый лист показал 4 клипа замершими — ошибка съёмки,
при повторе они двигаются.

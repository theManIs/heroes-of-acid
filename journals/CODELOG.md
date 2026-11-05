# Code log

### 2026-10-23 00:20 — тестовая сцена существа в Godot

Новые файлы:
- `pipelines/creature/stage2_tripo.py` — этап 2 пайплайна (Tripo: модель → риг → 5 анимаций, состояние в `tripo_state.json`, отчёт `report.md`); `face_limit 20000`, риг v3.0 spec tripo.
- `game/project.godot` — проект Godot 4.7, главная сцена `scenes/creature_test.tscn`.
- `game/scenes/creature_test.tscn` + `creature_test.gd` — голем на плоскости: ЛКМ по земле — идти (walk, цикл), кнопки HUD «Удар» (slash), «Получить удар» (hurt), «Смерть» (fall, держит последний кадр), «Воскресить»; idle/walk зациклены, разовые анимации возвращаются в idle.
- `game/assets/creatures/flesh-golem/flesh-golem.glb` — копия из `creatures/flesh-golem/`.

Команды:
```bash
python3 -m venv .venv && .venv/bin/pip install tripo3d pillow
.venv/bin/python pipelines/creature/stage2_tripo.py flesh-golem
godot --headless --path game --import
godot --path game
```

### 2026-10-23 00:55 — правки тестовой сцены

- `pipelines/creature/stage2_tripo.py`: `ANIMATION_BATCHES` — партия 1 с геометрией (`<id>.glb`), партия 2 без (`<id>-anims2.glb`: run, jump, turn, shoot). Цена 10 кредитов за анимацию.
- `game/scenes/creature_test.gd`:
  - разовые анимации ускоряются до ≤ `MAX_ONESHOT` = 3 с (hurt 13,9 с → ×4,6; slash 6,6 с → ×2,2);
  - `FRONT_YAW = -PI/2` — модель Tripo смотрит по +X; плавный разворот `lerp_angle`, стартует лицом к камере;
  - подмешивание `flesh-golem-anims2.glb` с переписыванием путей треков на скелет основной модели;
  - кнопки Выстрел, Прыжок, Поворот, переключатель «Бег»;
  - `_keep_above_ground()`: AnimationPlayer в ручном режиме, после каждого кадра модель поднимается по нижней кости + 0,35 толщины тела, когда она лежит;
  - отладка `-- --shot=<префикс>`: кадры спереди и после падения.

```bash
.venv/bin/python pipelines/creature/stage2_tripo.py flesh-golem
godot --headless --path game --import
godot --path game -- --shot=<scratchpad>/shot2
```

### 2026-10-23 01:05 — поле и камера

- `game/scenes/creature_test.gd`: `FIELD = 5.0` — поле 5×5, точка ходьбы зажата в пределах поля (отступ 0,4); камера вдвое ближе: `(0, 2.4, 2.9)` → взгляд на `(0, 0.9, 0)`.

### 2026-10-23 01:10 — поле-доска

- `game/scenes/creature_test.gd`: `FIELD = Vector2(20, 5)` — ширина как раньше, глубина 5; ограничение точки ходьбы по обеим осям.

### 2026-10-23 01:15 — края поля в кадре

- `game/scenes/creature_test.gd`: `FIELD = Vector2(8, 5)` — при близкой камере ширина 20 уводила края за кадр; 8 — максимум, при котором боковые края уходят в даль внутри кадра.

### 2026-10-23 00:15 — артефакт «едет» после движения

Причина (замер по костям, `--demo`): в walk/run от Tripo таз смещён относительно idle (run — ~1,15 м в мире, walk — ~0,2 м); при переходе в idle тело за время бленда «доезжало» на место.

- `game/scenes/creature_test.gd`:
  - `_align_hips()` — трек позиции `Hip` циклических анимаций сдвигается так, чтобы среднее совпало с первым ключом idle; дрейф таза в idle после остановки: 1,18 м → 0,01 м;
  - `WALK_SPEED` 1,5 → 1,0 (ближе к шагу анимации);
  - прижатие к земле работает только когда существо мёртво;
  - `_walk_to()` вынесен из обработки клика;
  - демо `-- --demo` (шаг → стоп → бег → стоп) + строки замера `P` в stdout.

```bash
godot --path game --write-movie screens/golem-move.avi --fixed-fps 30 -- --demo
```

### 2026-10-23 00:35 — убраны выстрел и поворот, выравнивание таза для всех анимаций

- `game/scenes/creature_test.gd`: кнопки «Выстрел» и «Поворот» убраны; `_align_hips()` теперь для всех анимаций (циклические — по среднему, разовые — по первому ключу); `--shot` дополнительно снимает `-hurt.png`.
- `pipelines/creature/stage2_tripo.py`: партия 2 — run, jump (shoot — только стрелкам), turn не берём.
- `pipelines/creature/README.md`: цена ~135 кредитов за 7 анимаций, раздел «Особенности анимаций Tripo».

### 2026-10-23 00:45 — получение удара кодом

- `game/scenes/creature_test.gd`: `flinch()` — твин отбрасывает модель назад на `FLINCH_PUSH` 0,15 с наклоном `FLINCH_TILT` 0,17 рад за 0,08 с и возвращает за 0,3 с; кнопка «Получить удар» вызывает его вместо пресета hurt.
- `pipelines/creature/stage2_tripo.py`, `README.md`: пресет hurt больше не заказываем; ~125 кредитов за 6 анимаций.

### 2026-10-23 00:55 — вздрагивание длиной 3 с

- `game/scenes/creature_test.gd`: `flinch()` — толчок `FLINCH_HIT` 0,5 с + возврат 2,5 с = `MAX_ONESHOT` 3 с, как у остальных разовых анимаций.

### 2026-10-23 01:10 — получение удара синхронно с моментом попадания

- `game/scenes/creature_test.gd`:
  - `_find_impact()` — при загрузке прогоняет slash по 121 кадру и ищет кадр, где кисть (`*Hand`) дальше всего вперёд по +X модели; у голема — 32 % длины (~0,96 с из 3 с), проверено снимком;
  - `flinch()` — пауза до момента попадания, резкий толчок назад `FLINCH_HIT` 0,15 с, плавный возврат до конца 3 с;
  - `--shot` снимает кадр `-impact.png` в момент попадания вместо `-hurt.png`.

### 2026-10-23 01:30 — арена с двумя големами

- `game/scenes/creature.gd` (новый, `class_name Creature`): логика существа вынесена из сцены — загрузка модели и второй партии анимаций, выравнивание таза, поиск момента и дальности удара (`impact`, `reach`), ходьба с сигналом `arrived`, `face()`, `play_once()`, `flinch(hit_at)`, смерть с прижатием к земле.
- `game/scenes/creature_test.gd`: арена — игрок слева, враг справа, смотрят друг на друга; «Удар» или клик по врагу — подойти на `reach + ENEMY_RADIUS` и ударить, враг получает удар в момент попадания бьющего; «Воскресить» поднимает обоих; `--shot` снимает арену и момент попадания, `--demo` — подход и удар.

### 2026-10-23 01:40 — клик по врагу

- `game/scenes/creature_test.gd`: `_on_enemy()` — клик считается по врагу, если попал в экранную рамку от ступней до макушки шириной `CLICK_HALF_WIDTH` 0,6 м; раньше проверялась точка на земле, и клик по телу уходил за спину врага и превращался в ходьбу.

### 2026-10-23 01:45 — подсказка удара при наведении

- `game/scenes/creature_test.gd`: `hint` — надпись «Удар» у курсора и курсор-рука, когда мышь над живым врагом, а свой голем жив.

### 2026-10-23 01:50 — подсказка удара в строке статуса

- `game/scenes/creature_test.gd`: убраны надпись у курсора и смена курсора; при наведении на живого врага строка статуса в HUD показывает «Противник: ЛКМ — ударить».

### 2026-10-23 01:55 — хитбокс врага по костям

- `game/scenes/creature_test.gd`: `_on_enemy()` — экранная рамка строится по всем костям врага в текущей позе и расширяется на `HITBOX_PAD` 0,25 м; прежняя рамка от точки на земле шириной 0,6 м не покрывала левую руку и голову.

### 2026-10-23 02:05 — дистанция удара

Замер: вынос кулака в момент попадания 1,17 м, толщина тела 0,78 м, таз в idle смещён на 0,27 м вбок от точки существа.

- `game/scenes/creature.gd`: `_center_on_hip()` — модель сдвигается так, чтобы таз в idle был над точкой существа (иначе тела противников разъезжались вбок); `front()` — половина толщины тела.
- `game/scenes/creature_test.gd`: дистанция удара `reach + enemy.front() - OVERLAP` (0,1 м — кулак входит в тело) ≈ 1,46 м вместо 1,62 м.

### 2026-10-23 02:10 — смерть врага после трёх ударов

- `game/scenes/creature_test.gd`: счётчик `hits`; на `HITS_TO_KILL` = 3-м ударе враг вместо получения удара падает в момент попадания; дальше атаковать нельзя; «Воскресить» обнуляет счётчик; в строке статуса «Удары: n/3».

### 2026-10-23 02:15 — удары — свойство существа

- `game/scenes/creature.gd`: `HITS_TO_KILL`, `hits`, `take_hit(hit_at)` (последний удар — смерть в момент попадания), `can_be_hit()`; `revive()` обнуляет `hits`.
- `game/scenes/creature_test.gd`: счётчик убран из арены; строка статуса показывает «Противник: удары n/3» только при наведении на врага.

### 2026-10-23 02:25 — мёртвый не парит

- `game/scenes/creature.gd`: прижатие к земле — нижняя кость держится не ниже `lerp(высота в стойке, LIMB_RADIUS 0,12 м, лежит)`; убрана добавка 0,35 толщины тела, из-за которой труп висел в воздухе.
- `game/scenes/creature_test.gd`: `--shot` дополнительно снимает `-dead.png` — убитого врага сбоку.

### 2026-10-23 02:30 — убраны бег и прыжок

- `game/scenes/creature_test.gd`: кнопки «Прыжок» и «Бег» убраны, вторая партия анимаций не подключается.
- `game/scenes/creature.gd`: убраны бег (`RUN_SPEED`, `running`, `set_running`), `extra_anims` в `setup()` необязателен.
- `game/assets/creatures/flesh-golem/flesh-golem-anims2.glb` удалён из ассетов игры (исходник остаётся в `creatures/flesh-golem/`).
- `pipelines/creature/stage2_tripo.py`, `README.md`: вторая партия пустая (стрелкам — shoot); существо с 4 анимациями ≈ 105 кредитов.

### 2026-10-23 02:50 — гексовое поле и пошаговый бой

- `game/scenes/creature.gd`: `walk_path(points)` — проход по центрам гексов подряд, сигнал `arrived` в конце.
- `game/scenes/creature_test.gd` (переписан):
  - поле 6×4 pointy-top гексов (`CylinderMesh` с 6 гранями, щели, тёмное основание); радиус гекса считается так, чтобы соседние центры были на дистанции удара (`reach + front − OVERLAP`);
  - ходы: игрок — клик по подсвеченному гексу (BFS, до `MOVE` = 3) или по противнику (подойти к ближайшему свободному соседу в пределах хода и ударить); противник — подходит к соседнему гексу и бьёт, если дошёл; после удара ход переходит через 3 с;
  - обводка гекса под големом игрока: синяя в свой ход, красная в ход противника;
  - кнопки «Пропустить ход», «Заново»; тестовые «Удар/Получить удар/Смерть» убраны.

### 2026-10-23 03:00 — противник заслоняет гексы

- `game/scenes/creature_test.gd`: когда курсор над противником, гекс под курсором не подсвечивается (раньше луч проходил сквозь противника и подсвечивал гекс за ним).

### 2026-10-23 03:05 — обводка под тем, кто ходит

- `game/scenes/creature_test.gd`: `active` — существо, чей ход; обводка ездит под ним: синяя под своим големом, красная под противником в его ход; после конца боя скрыта.

### 2026-10-23 03:20 — обводка по контуру существа

- `game/scenes/creature.gd`: `set_outline(color | null)` — копии материалов модели со `stencil_mode = STENCIL_MODE_OUTLINE` (Godot 4.5+), толщина `OUTLINE_WIDTH` 0,025 м; первая попытка — шейдер «вывернутой оболочки» — давала линии внутри силуэта на сложной сетке голема, удалена.
- `game/scenes/creature_test.gd`: обводка гекса убрана; в свой ход контур своего голема синий, в ход противника — контур противника красный; после конца боя без обводки.

### 2026-10-23 03:25 — обводка только на время выбора

- `game/scenes/creature_test.gd`: `_move_and_maybe_strike()` снимает обводку с того, кто ходит, как только действие выбрано (у противника — после паузы «на раздумье» 0,6 с).

### 2026-10-23 04:30 — второе существо: упырь

- `pipelines/creature/stage2_tripo.py`: `load_config()` — `creatures/<id>/tripo.json` переопределяет риг и партии анимаций.
- `creatures/ghoul/tripo.json`: риг v1.0, анимации idle, walk, fall, hit_to_body_01, chop | box_01, slash. 135 кредитов (баланс 685), модель 19 тыс. треугольников, 41 кость.
- `game/scenes/creature.gd`: `height`, `attack_anim`, `hurt_anim` в `setup()`; `set_attack()`; `strike(target, distance, overlap)` с выпадом, если кулак не достаёт; `take_hit()` играет анимацию реакции в момент попадания, если она задана.
- `game/scenes/creature_test.gd`: противник — упырь (рост 1,6 м); радиус гекса по дальнему удару; кнопки «Удар упыря: chop/box_01/slash» и «Реакция упыря: анимация/толчок»; `--shot` снимает удар упыря по голему.
- `game/assets/creatures/ghoul/`: `ghoul.glb`, `ghoul-anims2.glb`.

### 2026-10-23 04:45 — камера ближе, игрок может взять упыря

- `game/scenes/creature_test.gd`: камера `(0, 2.7, 3.3)` → `(0, 0.5, 0)`, крайние гексы обрезаются; старт на втором гексе от края; `_make(kind)` создаёт голема или упыря; кнопка «Мой боец: голем/упырь» (`_swap_player`) меняет своего бойца и пересобирает поле (`board`) под новую дальность удара; выбор удара и реакции применяется ко всем упырям на поле.

### 2026-10-23 05:00 — арена под одно проверяемое существо

- `game/scenes/creature_test.gd`: голем убран из арены; оба бойца — проверяемое существо (блок `CREATURE`, `EXTRA_ANIMS`, `ATTACKS`, `HURT`, `SIZE` в начале файла); убраны выбор бойца и переключатель реакции (реакция всегда анимацией); осталась кнопка «Удар» по кандидатам; камера `(0, 2.2, 3.0)`, `fov 45`; старт на гексах (1,1) и (3,1).
- `pipelines/creature/README.md`: этап 3 — как подключить существо через этот блок.

### 2026-10-23 05:05 — камера чуть дальше

- `game/scenes/creature_test.gd`: камера `(0, 2.6, 3.6)`, `fov 55` — крайние нижние гексы видны частично, фигурки крупнее, чем при полном поле.

### 2026-10-23 05:10 — противник ближе к зрителю

- `game/scenes/creature_test.gd`: свой боец стартует на гексе (2,1) в глубине поля, противник — на (3,3) у зрителя, между ними 2 гекса.

### 2026-10-23 05:15 — зелёная обводка цели

- `game/scenes/creature_test.gd`: в свой ход, когда курсор над противником, которого можно ударить, на нём зелёная обводка (`TARGET`); снимается, когда курсор ушёл или действие выбрано.

### 2026-10-23 05:20 — расстановка как в Героях

- `game/scenes/creature_test.gd`: свой слева на (1,1), противник справа на (COLS−2, 2) — на ряд ближе к зрителю; между ними 3 гекса.

### 2026-10-23 05:40 — удар упыря pitch_baseball

- `creatures/ghoul/tripo.json`: третья партия `preset:biped:pitch_baseball` (10 кредитов, баланс 675) → `ghoul-anims3.glb`, скопирован в `game/assets/creatures/ghoul/`.
- `game/scenes/creature.gd`: `setup()` принимает список дополнительных GLB с анимациями.
- `game/scenes/creature_test.gd`: `EXTRA_ANIMS` — список; кандидаты удара `pitch_baseball` (по умолчанию), `chop`, `slash`; `box_01` убран.

### 2026-10-23 05:55 — одна анимация удара, удар с середины

- `game/scenes/creature.gd`: `attack_from` (6-й параметр `setup`) — удар проигрывается с этой доли длины; `_find_impact()` ищет попадание в проигрываемой части по самому быстрому выбросу кисти вперёд (а не по самой дальней точке).
- `game/scenes/creature_test.gd`: одна анимация удара `ATTACK = "pitch_baseball"`, `ATTACK_FROM = 0.33` (клип 3,8 с, попадание было на 43 %); кнопка выбора удара убрана.
- `pipelines/creature/ARTIFACTS.md`: пункты 23–24.

### 2026-10-23 06:05 — удар без позирования, точное время попадания

- `game/scenes/creature.gd`: после попадания через `RECOIL` 0,3 с удар уходит в idle за 0,35 с; `hit_delay()` — секунды до попадания; `take_hit(delay)`, `flinch(delay)`, выпад — по нему (раньше `MAX_ONESHOT × impact`, неверно для ударов короче 3 с).
- `game/scenes/creature_test.gd`: после удара ход передаётся через `hit_delay() + 1,5 с`.
- `pipelines/creature/ARTIFACTS.md`: пункты 25–26.

### 2026-10-23 06:15 — стойка упыря look_around

- `creatures/ghoul/tripo.json`: четвёртая партия `preset:biped:look_around` (10 кредитов, баланс 665) → `ghoul-anims4.glb`.
- `game/scenes/creature.gd`: 7-й параметр `setup(... idle)` — своя стойка подменяет `idle` в библиотеке анимаций.
- `game/scenes/creature_test.gd`: `IDLE = "look_around"`, четвёртый файл анимаций в `EXTRA_ANIMS`.

### 2026-10-23 06:30 — стойка без in place

- `pipelines/creature/stage2_tripo.py`: `animate_in_place` только для партий с ходьбой/бегом.
- `creatures/ghoul/tripo.json`: пятая партия — `look_around` без in place (10 кредитов, баланс 655), таз ходит на 12 см → `ghoul-anims5.glb`; `ghoul-anims4.glb` убран из ассетов игры.
- `game/scenes/creature_test.gd`: стойка из `ghoul-anims5.glb`.
- `pipelines/creature/ARTIFACTS.md` п.27, `README.md`: правило in place.

### 2026-10-23 06:55 — защита

- `creatures/ghoul/tripo.json`: партия 6 — `afraid` без in place (2,6 с; 10 кредитов, баланс 645) → `ghoul-anims6.glb`.
- `game/scenes/creature.gd`: `defend_anim`, `defend_from`, `defending`; `take_hit()` у защищающегося не увеличивает счётчик и играет защиту за `DEFEND_LEAD` 0,3 с до попадания; `_start_of()` — частичный старт для удара и защиты.
- `game/scenes/creature_test.gd`: кнопка «Защита» — ход заканчивается, `defending` до своего следующего хода; `DEFEND = "afraid"`, `DEFEND_FROM = 0`; `--shot` снимает удар по защищающемуся.
- `pipelines/creature/README.md`: подбор анимации защиты.

### 2026-10-23 07:20 — голем на риге v1.0

- `creatures/flesh-golem/`: прежние файлы рига v3.0 — в `v3-rig/`; `tripo_state.json` оставлен только с моделью (тяжёлая, 1,4 млн — по решению пользователя, без новой генерации); `tripo.json`: риг v1.0, партия 1 без in place — idle, slash, hit_to_body_01, fall, football_save; партия 2 in place — walk. 85 кредитов (баланс 560); риг тяжёлой сетки прошёл.
- `game/scenes/creature_test.gd`: настройки существ — словарь `CREATURES` (ghoul, flesh-golem), выбор `TESTED = "flesh-golem"`.
- `game/assets/creatures/flesh-golem/`: новые `flesh-golem.glb`, `flesh-golem-anims2.glb`.

### 2026-10-23 07:35 — защита голема на месте

- `game/scenes/creature.gd`: `_pin_hip()` — во время анимации защиты таз удерживается над точкой существа по горизонтали (`football_save` уносил тело на ~1,6 единицы).
- `game/scenes/creature_test.gd`: `--shot` снимает ещё кадр через 1 с после попадания (`-hit2.png`).
- `pipelines/creature/ARTIFACTS.md`: п.28.

### 2026-10-23 07:50 — защита голема box_02

- `creatures/flesh-golem/tripo.json`: партия 3 — `box_02` (2,8 с, без in place; таз смещается ≤ 0,09) → `flesh-golem-anims3.glb`; 10 кредитов, баланс 550.
- `game/scenes/creature_test.gd`: защита голема — `box_02` вместо `football_save`.

### 2026-10-23 08:05 — защита голема fold_arms кусочком

- `creatures/flesh-golem/tripo.json`: партия 4 — `fold_arms` (17 с; таз ≤ 0,02) → `flesh-golem-anims4.glb`; 10 кредитов, баланс 540; `anims3` (box_02) убран из ассетов игры.
- `game/scenes/creature.gd`: `defend_len` — играть кусок защиты с обычной скоростью и уйти в idle; `defend_lead` — опережение попадания для каждого существа (вместо константы `DEFEND_LEAD`).
- `game/scenes/creature_test.gd`: голем — защита `fold_arms` с 1,75 с, 1,6 с, опережение 1 с (замер: кисти сходятся с 1,25 до 2,75 с); упырь — прежние значения.
- `pipelines/creature/ARTIFACTS.md`: п.29.

### 2026-10-23 08:30 — пиктограммы существ в арене

- `game/assets/creatures/<id>/icon.png` — 128×128, верх концепта (голова и плечи).
- `game/scenes/creature_test.gd`: в `CREATURES` — `name`, `icon`; слева колонка кнопок-пиктограмм (одна выбрана); клик — `_switch(id)`: оба бойца пересоздаются, поле пересобирается под их дальность удара, бой заново; `TESTED` — с кого начинать.
- `pipelines/creature/README.md`: этап 3 — пиктограмма для нового существа.

### 2026-10-23 08:40 — камера под размер поля

- `game/scenes/creature_test.gd`: `_place_camera()` — позиция и точка взгляда камеры масштабируются на `radius / CAMERA_REF_RADIUS` (0,445 — упырь); вызывается при старте и смене существа.
- `pipelines/creature/ARTIFACTS.md`: п.31.

### 2026-10-23 08:50 — одно поле для всех существ

- `game/scenes/creature_test.gd`: радиус гекса — константа `HEX_RADIUS` 0,6 (раньше считался из дальности удара — у каждого существа было своё поле); смена существа пересоздаёт только бойцов, поле и камера не меняются.
- `game/scenes/creature.gd`: `strike()` — выпад в обе стороны: вперёд, если кулак не достаёт, назад, если достаёт с запасом.
- `pipelines/creature/ARTIFACTS.md`: п.21 и п.31 переписаны — разные поля были ошибкой.

### 2026-10-23 09:10 — сборка под Windows

- Шаблоны экспорта Godot 4.7.2 (официальный `export_templates.tpz`, 1,28 ГБ) — установлены только `windows_*x86_64*` в `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`; скачанный архив удалён.
- `game/export_presets.cfg`: пресет «Windows Desktop», x86_64, PCK рядом с exe, путь `../builds/windows/HeroesOfAcid.exe`.
- `builds/` в `.gitignore`.

```bash
godot --headless --path game --export-release "Windows Desktop" ../builds/windows/HeroesOfAcid.exe
```

Результат: `builds/windows/HeroesOfAcid.exe` (109 МБ) + `HeroesOfAcid.pck` (125 МБ), архив `builds/HeroesOfAcid-windows.zip`.

### 2026-10-23 09:25 — быстрая смена существа

- `game/scenes/creature_test.gd`: `_cache` — при старте загружаются модели и файлы анимаций всех существ из `CREATURES` и держатся до конца; `_switch()` удаляет бойцов через `queue_free()`.
- `pipelines/creature/ARTIFACTS.md`: п.32.

### 2026-10-23 09:40 — пиктограммы из 3D и белая обводка

- `game/tools/icon_shot.{gd,tscn}` (новые): снимок каждого существа в стойке idle, лицом в камеру, фокус чуть ниже кости `Head`, 256×256 → `game/assets/creatures/<id>/icon.png`.
- `game/scenes/creature.gd`: `size_top()` — высота макушки в текущей позе.
- `game/scenes/creature_test.gd`: стили кнопок-пиктограмм — при наведении белая обводка 3 px, выбранная — тонкая серая.
- `pipelines/creature/README.md`: как обновить пиктограмму.

### 2026-10-23 09:55 — короткая реакция голема

- `game/scenes/creature.gd`: `hurt_len` — реакция играется куском с обычной скоростью и плавно уходит в idle; общий `_len_of()` для защиты и реакции.
- `game/scenes/creature_test.gd`: голем — `hurt_len` 0,65 с (половина `hit_to_body_01`, без раскачки в бок); упырь — целиком.

### 2026-10-23 10:05 — вздрагивание при ударе в защиту

- `game/scenes/creature.gd`: удар по защищающемуся — кроме анимации защиты, в момент попадания лёгкий толчок назад `BLOCK_PUSH` 0,07 м с наклоном `BLOCK_TILT` 0,07 рад и возврат за 0,45 с; толчок — свойство `jolt`, учитывается в `_pin_hip()` (иначе удержание таза его гасит).

### 2026-10-23 11:55 — котельщик в арене

- `creatures/boilerman/`: этап 2 — модель, риг v1.0, idle/hit_to_body_01/fall + walk, затем box_01 и hit_to_head; 125 кредитов (баланс 415).
- `game/assets/creatures/boilerman/`: glb, anims2, anims3, icon.png.
- `game/scenes/creature_test.gd`: запись `boilerman` в `CREATURES` (удар box_01 — один прямой выпад, пик 0,65 с; реакция hit_to_body_01 0,65 с; защита hit_to_head; рост 1,9 м); `TESTED = "boilerman"`.
- `game/tools/icon_shot.gd`: `icon_up`, `icon_dist` из записи существа.
- `pipelines/creature/README.md`: столбец котельщика в «Что выбрано», настройки пиктограммы.

### 2026-10-23 12:35 — дым из трубы котельщика

- `game/scenes/creature.gd`: `add_smoke()` — точка дыма = самая высокая вершина модели (верх трубы) в позе привязки, привязана к ближайшей кости через `BoneAttachment3D`; `GPUParticles3D` (`top_level`, 48 частиц, 2,4 с, мягкие серые клубы растут и тают, сносятся вверх-вбок); `puff_smoke()` — втрое сильнее на 0,6 с, у бьющего и у цели в момент попадания.
- `game/scenes/creature_test.gd`: ключ `"smoke": true` у котельщика; защита котельщика снова пустая (`cross_body_crunch` убран, `anims4` удалён из ассетов игры).

### 2026-10-23 12:50 — защита котельщика scared_01

- `creatures/boilerman/tripo.json`: партия 5 — `scared_01` (3,3 с; корпус вертикален, руки у лица, таз отходит назад до 0,23) → `boilerman-anims5.glb`; 10 кредитов, баланс 395.
- `game/scenes/creature_test.gd`: защита котельщика — `scared_01` с 27 % (0,9 с), 1,4 с, опережение 0,3 с; `anims5` в `extra`.
- `pipelines/creature/README.md`: столбец котельщика, раздел про дым.

### 2026-10-23 13:00 — Windows одним файлом

- `game/export_presets.cfg`: `binary_format/embed_pck=true` — ресурсы внутри exe.
- `builds/windows/HeroesOfAcid.exe` — 280 МБ (три существа, гексовое поле, пиктограммы, дым); `builds/HeroesOfAcid-windows.zip` — архив с ним.

### 2026-10-23 13:20 — текстуры существ 2048, VRAM-сжатие

- `game/assets/creatures/*/*_{Color,ORM,NormalGL}_*.import`: `compress/mode=2`, `process/size_limit=2048` — 9 текстур 131 → 25 МБ.
- Сборка Windows: `HeroesOfAcid.exe` 280 → 174 МБ; zip пересобран.
- `pipelines/creature/ARTIFACTS.md` п.37, `README.md` этап 3.

### 2026-10-23 13:45 — сторона атаки, как в Героях

- `game/scenes/sword_cursor.gd` (новый): меч в HUD, остриё в курсоре, повёрнут в сторону удара (системный курсор не меняется).
- `game/scenes/creature_test.gd`: `_attack_hex()` — сектор по смещению курсора от середины тела противника на экране → соседний гекс; занятый, за краем или вне хода — ближайший по углу доступный; клик по противнику — идти именно на этот гекс и бить; гекс атаки подсвечен зелёным; нет доступной стороны — подсказка в статусе.
- `pipelines/creature/ARTIFACTS.md`: п.38.

### 2026-10-23 14:00 — сторона атаки от гекса; камера ближе

- `game/scenes/creature_test.gd`: `_attack_hex()` — клин гекса противника на земле под курсором (продлённые 6 треугольников), не от модели; `_ground_point()`; нацеливание — курсор на теле противника или на его гексе; `CAMERA_ZOOM` 0,85 — камера ближе.
- `pipelines/creature/ARTIFACTS.md`: п.38 переписан.

### 2026-10-23 14:08 — камера ещё ближе

- `game/scenes/creature_test.gd`: `CAMERA_ZOOM` 0,85 → 0,75.

### 2026-10-23 14:12 — сборка Windows

- `builds/windows/HeroesOfAcid.exe` пересобран: сторона атаки от гекса, меч у курсора, камера ближе; zip обновлён.

### 2026-10-23 15:55 — вампир в арене

- `creatures/vampire/`: этап 2 + партия 3 (slash, standing_relax, hit_to_side, hit_to_head), 145 кредитов, баланс 250.
- `game/assets/creatures/vampire/`: glb, anims2, anims3, icon.png; текстуры 2048 + VRAM-сжатие.
- `game/scenes/creature.gd`: `defend_pin` — удержание таза в защите можно выключить (уклон).
- `game/scenes/creature_test.gd`: запись `vampire` (удар slash, реакция hit_to_head, стойка standing_relax, защита hit_to_side без удержания, рост 1,95 м); `TESTED = "vampire"`.
- `pipelines/creature/README.md`, `ARTIFACTS.md` п.40.

### 2026-10-23 16:05 — мёртвый на своём гексе, пиктограмма вампира

- `game/scenes/creature.gd`: `_pin_hip()` держит таз над точкой существа, пока оно мертво (`fall` без «на месте» уносил тело на 1,6 м); замер после смерти — 0,00.
- Пиктограмма вампира: повторный импорт после `icon_shot` (игра показывала заглушку).
- `pipelines/creature/ARTIFACTS.md` п.41, `README.md`.

### 2026-10-23 16:20 — git и GitHub

```bash
brew install git-lfs
git init -b main && git lfs install --local && git lfs track "*.glb" "*.png" "*.jpg" "*.avi"
git commit -m "Heroes of Acid: концепция, пайплайн существ и арена в Godot"
gh repo create theManIs/heroes-of-acid --public --source . --remote origin --push   # SSH не прошёл
git remote set-url origin https://github.com/theManIs/heroes-of-acid.git && gh auth setup-git && git push -u origin main
```

- Коммит `8deea01`, 147 файлов, 52 объекта LFS (263 МБ). В `.gitignore`: `.env`, `.venv/`, `screens/`, `builds/`, `.godot/`.

### 2026-11-01 20:45 — ополченец в арене

- `creatures/militiaman/`: концепт — T-поза пользователя; модель, риг v1.0, idle/hit_to_body_01/fall + walk, затем chop, scared_01, hit_to_head; 135 кредитов (баланс 115).
- `game/assets/creatures/militiaman/`: glb, anims2, anims3, icon.png; текстуры 2048 + VRAM-сжатие.
- `game/scenes/creature_test.gd`: запись `militiaman`; `TESTED = "militiaman"`.
- `pipelines/creature/README.md`: столбец ополченца, старт с готовой T-позы.

### 2026-11-01 21:20 — щипок и колесо: приближение с возвратом

- `game/scenes/creature_test.gd`: `InputEventMagnifyGesture` и колесо мыши двигают камеру к существу под курсором или точке на земле; `ZOOM_NEAR` 0,55; `ZOOM_HOLD` 0,5 с без событий жеста — плавный возврат на общий план. Проверено синтетическими событиями щипка: приблизилось, через 1,5 с после последнего события камера на базовой позиции.

### 2026-11-01 21:30 — зум слабее

- `game/scenes/creature_test.gd`: `ZOOM_NEAR` 0,55 → 0,35, `ZOOM_PINCH` 1,5 → 0,8.

### 2026-11-01 21:35 — зум ещё слабее

- `game/scenes/creature_test.gd`: `ZOOM_NEAR` 0,35 → 0,2, `ZOOM_PINCH` 0,8 → 0,5.

### 2026-11-02 — сцена боя 15×11 (задача 23)

- Новые файлы: `game/scenes/battle_test.gd`, `game/scenes/battle_test.tscn`. Записи существ берутся из `creature_test.gd`, арена не менялась.
- Поле 15×11, по 5 существ слева (игрок) и справа (ИИ), стороны ходят по очереди, мёртвые не занимают гекс.
- Проверка: `godot --path game res://scenes/battle_test.tscn -- --auto --shot=<префикс>` (автобой доиграл до конца, слева живых 1, справа 0); клики, защита и пропуск проверены временным скриптом, он удалён.

### 2026-11-02 — ход и скорость ходьбы в сцене боя (задача 24)

- `battle_test.gd`: `MOVE` 3 → 6, новая `WALK_RATE := 2.0`.
- `creature.gd`: новое поле `walk_rate` (по умолчанию 1.0), умножает скорость анимации walk и скорость движения; арена не меняется.

### 2026-11-02 — дальность хода по массивности (задача 25)

- `battle_test.gd`: `MOVE` заменён на словарь `MOVES`: упырь 8, вампир 7, ополченец 6, котельщик 5, голем 4.

### 2026-11-02 — камера сцены боя 60° (задача 26)

- `battle_test.gd`: `CAMERA_DIR` (0, 2.6, 3.6) → (0, 0.866, 0.5). Арена не менялась.

### 2026-11-02 — камера сцены боя 45° (задача 27)

- `battle_test.gd`: `CAMERA_DIR` (0, 0.866, 0.5) → (0, 1, 1).

### 2026-11-02 — камера сцены боя ближе (задача 28)

- `battle_test.gd`: новая `CAMERA_CLOSE := 0.8`, дистанция после подбора умножается на неё.

### 2026-11-02 — ускорение сцены боя (задача 29)

- `battle_test.gd`: новая `GAME_SPEED := 2.0`, ставится в `Engine.time_scale` при запуске сцены.

### 2026-11-02 — дальность хода при наведении (задача 30)

- `battle_test.gd`: `_inspected`, `_ally_under`, `_range_of`; `_paint` показывает дальность существа под курсором: противник красным, своё синим, пока курсор на нём.

### 2026-11-02 — шкала инициативы и игровые ходы (задача 31)

- `battle_test.gd`: очерёдность сторон заменена игровыми ходами: `_queue`, `round_no`, `_round_order` (инициатива = дальность хода, при равенстве левая сторона). Шкала сверху: `_show_queue`, `_queue_slot`, `_queue_label`.
- Проверка: автобой с журналом порядка, повторов в одном ходу 0.

### 2026-11-02 — механика ожидания (задача 32)

- `battle_test.gd`: кнопка «Ждать», `_wait`, `_waiting`, `_wait_phase`; ожидавшие ходят в конце игрового хода, из них медленные первыми; второй раз ждать нельзя. В шкале — блок «Ждут».
- Проверка временным скриптом: порядок голем → котельщик → ополченец → вампир → упырь, повторное ожидание блокируется, новый ход идёт в обычном порядке.

### 2026-11-02 — шкала после смерти и конца боя (задача 33)

- `battle_test.gd`: `_act` обновляет шкалу в момент попадания; `_game_over` очищает шкалу; мёртвые не показываются в блоке «Ждут».

### 2026-11-02 — новый ополченец: multiview, риг, старые анимации (задачи 35, 36)

- `pipelines/creature/stage2_multiview.py`: модель по нескольким видам. Заказ: модель 40, риг 25, баланс 115 → 50.
- `creature.gd`: пустой `AnimationPlayer` для рига без анимаций, `_adapt_track` — перенос анимаций на другую позу покоя.
- `creature_test.gd`: запись `militiaman` — новая модель, анимации со старых файлов.
- Команды: `godot --path game res://scenes/battle_test.tscn -- --auto`, импорт с `compress/mode=2`, `size_limit=2048`.

### 2026-11-02 — заморозка руки в реакции (задача 37)

- `creature.gd`: `freeze_bones`; `creature_test.gd`, `battle_test.gd`: вызов из `_make`; запись `militiaman`: `hurt_still`. Пиктограмма ополченца переснята.

- Заморозка распространена на защиту: `hurt_still` → `still`, применяется к `hurt` и `defend`.

### 2026-11-02 — удар без перемещения (задача 38)

- `battle_test.gd`, `creature_test.gd`: `_attack_hex` возвращает свой гекс, если противник уже рядом.

- `creature_test.gd`: клик по соседнему противнику падал с ошибкой типов (`[]` без типа в `Array[Vector2i]`), удар с места никогда не срабатывал. Теперь путь берётся из `reachable`.

### 2026-11-02 — защита ополченца с файла вампира (задача 39)

- `creature_test.gd`: запись `militiaman`: `defend` → `hit_to_side`, `defend_lead` 0.4, `defend_pin` false, в `extra` добавлен `vampire-anims3.glb`, `still` убран. Механизм `freeze_bones` оставлен, сейчас никем не используется.

### 2026-11-02 — половина движения левой руки в защите (задача 40)

- `creature.gd`: `freeze_bones` заменён на `hold_bones`; `_make` в обеих сценах; запись `militiaman`: `defend_hold`.

- `creature_test.gd`: `defend_hold_from` 0,5 → 0,25.

- `creature.gd`: `hold_bones` заменён на `scale_bones`: обрезка по времени почти не меняла движение (53° в первой четверти), теперь масштабируется размах. Запись `militiaman`: `defend_calm`, `defend_calm_by` 0.25.

### 2026-11-02 — структура папок и библиотека анимаций (задача 41)

- `creatures/<id>/`: `concept/`, `references/`, `tripo/`; `references/` в корне — только список. Старый риг ополченца: `creatures/militiaman/tripo/v1/`.
- `game/assets/animations/`: 18 пресетов, 2,5 МБ, `README.md`; сборка `pipelines/creature/build_animation_library.py`.
- `game/assets/creatures/militiaman/`: только новая модель и текстуры; анимации из библиотеки. Старые файлы удалены из игры, источники в `tripo/v1/`.
- `stage2_tripo.py`, `stage2_multiview.py`: новые пути.
- Проверка: арена без ошибок, автобой доигран, 0 ERROR.

### 2026-11-02 — рамка в шкале инициативы (задача 45)

- `battle_test.gd`: `_queue_slot` без белой рамки.

### 2026-11-02 — голем 20 тысяч (задача 44)

- `pipelines/creature/decimate.py`: упрощение в Blender. `flesh-golem.glb` 1 436 104 → 19 997 треугольников, анимации вынесены в `flesh-golem-anims1.glb`, запись `flesh-golem` дополнена. Исходник с высокой детализацией в `creatures/flesh-golem/tripo/flesh-golem.glb`.
- `build_animation_library.py`: `write_one` принимает список анимаций.

### 2026-11-02 — сцена витрины (задача 46)

- `game/scenes/showcase.{gd,tscn}`, `game/assets/showcase/` (12 уровней без текстур, 68 МБ, материал берётся у основной модели), `pipelines/creature/build_showcase.sh`, `decimate.py` с параметром `noimages`. `SCENES.md` дополнен.

### 2026-11-02 — иконки действий в бою (задача 47)

- `game/scenes/action_icon.gd`: иконки рисуются кодом. `battle_test.gd`: кнопки-иконки, `_skip` убран.

- `action_icon.gd`: иконки в один цвет (бронза); `battle_test.gd`: `_action_style`, кнопки тёмного дерева с бронзовой рамкой.

- `action_icon.gd`: `_blot` — клякса-подложка, подсветка под курсором; `battle_test.gd`: стиль кнопок пустой (задача 48).

### 2026-11-02 — свет в сцене боя (задача 50)

- `battle_test.gd`, `_build_world`: `ProceduralSkyMaterial` как источник рассеянного света и отражений, солнце тёплое, энергия 1,5. Фон пока прежний.

- `battle_test.gd`, `_paint`: подсветка гексов через свечение, чтобы тёплое солнце не съедало синий; рассеянный свет 1,5, солнце 1,4.

### 2026-11-02 — земля и дымка в бою (задача 51)

- `battle_test.gd`: фон — небо, туман; плоскость земли; `_soil_texture`, `_apply_soil`: шумовая почва в мировых координатах.

- Откат задачи 51: `battle_test.gd` вернулся к состоянию до земли, почвы и дымки.

### 2026-11-02 — белое поле (задача 52)

- `battle_test.gd`: `TILE_COLOR` белый, матовый; отражения убраны; подсветка насыщеннее.

### 2026-11-02 — свет с двух сторон (задача 53)

- `battle_test.gd`: солнце выше (-62°) и слабее, встречный холодный `fill` без теней.

- `battle_test.gd`: заполняющий свет перенесён к камере (-28°, -25°), плитки темнее (0,62), чтобы поле не пересвечивалось.

- `battle_test.gd`: `TILE_COLOR` 0,62 → 0,78.

### 2026-11-03 Задача 54: лучник, пайплайн creature-tripo-mixamo

- `pipelines/creature-tripo-mixamo/`: `stage2.py` (4 вида → модель → риг `spec: mixamo`), `fbx2glb.py`, `build_clips.py` (перенос клипов от покоя в мировых осях), README.
- `game/scenes/creature.gd`: `HIP_NAMES`/`_hip()`, `walk_speed`, `fire()`, `bone_tip()`.
- `game/scenes/projectile.gd`: новый, стрела и фонарь по дуге, вспышка.
- `game/scenes/creature_test.gd`: запись `lantern-archer`, `shots`, `_fire()`, кнопка «Бросить фонарь», стартовое существо `lantern-archer`, кадры `_shoot_ranged`.
- `game/tools/pose_sheet.*`: новый, лист поз и замер шага; `icon_shot.gd`: `--id`, голова через `bone_tip`.
- Команды: `.venv/bin/python pipelines/creature-tripo-mixamo/stage2.py lantern-archer` (65 кредитов, 1050 → 985), `.venv/bin/python pipelines/creature-tripo-mixamo/build_clips.py lantern-archer`, `godot --headless --path game --import`.

### 2026-11-03 Задача 56: курсор лука

- `game/scenes/bow_cursor.gd`: новый, по образцу `sword_cursor.gd`.
- `game/scenes/creature_test.gd`: `bow`, показывается над целью у стрелка; кадр `-cursor` в `_shoot_ranged`.

### 2026-11-03 Задача 57: руки при получении удара

- `game/scenes/creature_test.gd`: `hurt_calm`, `hurt_calm_by` в записи существа, вызов `scale_bones` для клипа реакции.
- `game/tools/pose_sheet.gd`: то же при съёмке листа.

### 2026-11-03 Задача 58: «Заново» после смерти

- `game/scenes/creature.gd`: `revive()` возвращает `model.position` к `_model_base`.
- `game/scenes/creature_test.gd`: кадр `-reset` и вывод сдвига в `_shoot_ranged`.

### 2026-11-03 Задача 59: снимок идущей игры

- `game/scenes/creature_test.gd`: `_check_shot_request()`, только в отладочной сборке.

### 2026-11-04 Задача 60: руки при получении удара

- `game/scenes/creature_test.gd`: `hurt_calm_by` 0.0 → 0.25.

### 2026-11-04 Задача 61: курсор лука

- `game/scenes/bow_cursor.gd`: сдвиг рисунка, центр в точке курсора.
- `game/scenes/creature_test.gd`: без поворота, `Input.mouse_mode` скрывает системный курсор, пока виден лук.

### 2026-11-04 Задача 62: правая рука от фонаря

- `pipelines/creature-tripo-mixamo/build_clips.py`: `_arm_out`, отведение правой руки в позе покоя.
- `creatures/lantern-archer/mixamo/clips.json`: `{"arm": 5, "fore": 12}`.
- Команды: `.venv/bin/python pipelines/creature-tripo-mixamo/build_clips.py lantern-archer`, `godot --headless --path game --import`.

### 2026-11-04 Задача 63: кисть дальше

- `creatures/lantern-archer/mixamo/clips.json`: `_arm_out.fore` 12 → 18.

### 2026-11-04 Задачи 64, 65: режим огня, сцена боя

- `game/scenes/creature.gd`: `shots`, `shot_mode`, `ranged()`, `next_shot_mode()`, `fire_shot()`.
- `game/scenes/creature_test.gd`: кнопка режима вместо «Бросить фонарь», `_fire()` без вида снаряда, `title` в `shots`.
- `game/scenes/battle_test.gd`: иконка `FIRE_MODE`, `_fire()`, `_switch_mode()`, стрелок ИИ, курсор, `MOVES` и `START_ROWS` на 6 существ, `hurt_calm` и `walk_speed` в `_make`.
- `game/scenes/action_icon.gd`: `FIRE_MODE`, лук и фонарь; `game/scenes/bow_cursor.gd`: курсор-фонарь.

### 2026-11-04 Задача 66: дуга стрелы

- `game/scenes/creature_test.gd`: `arc` — доля расстояния: стрела 0.12, фонарь 0.14.
- `game/scenes/creature.gd`: `fire_shot` умножает `arc` на расстояние.

### 2026-11-04 Задачи 67, 68: защита-уклон, без «Пропустить ход»

- `pipelines/creature-tripo-mixamo/build_clips.py`: `hip_scale`, доля смещения таза по земле.
- `creatures/lantern-archer/mixamo/`: `Standing Dodge Right.fbx`, `Standing Dodge Backward.fbx`, записи в `clips.json`.
- `game/scenes/creature_test.gd`: `defend` → `dodge_right`, `defend_len` 0.5, `defend_pin` false; убраны кнопка и `_skip()`.
- Команды: `.venv/bin/python pipelines/creature-tripo-mixamo/build_clips.py lantern-archer`, `godot --headless --path game --import`.

### 2026-11-04 Задача 69: удар с другого гекса вплотную

- `game/scenes/creature_test.gd`, `game/scenes/battle_test.gd`: из `_attack_hex` убран ранний возврат для стоящего рядом.

### 2026-11-04 Задача 70: лук вплотную запрещён

- `game/scenes/creature.gd`: `shot_wanted`, `set_shot()`, `allowed_shots()`, `update_shot()`, `next_shot_mode(adjacent)`.
- `game/scenes/creature_test.gd`: `no_adjacent` у стрелы; кнопка режима выключается, режим обновляется в начале хода; ИИ.
- `game/scenes/battle_test.gd`: `_enemy_adjacent()`, обновление режима в начале хода и у ИИ, иконка гаснет.

### 2026-11-04 Задача 71: рука ополченца

- `game/scenes/creature.gd`: `turn_bones()`, постоянный поворот кости вокруг вертикали позы покоя во всех анимациях.
- `game/scenes/creature_test.gd`: `bone_turn` у ополченца; вызов в `_make` тоже в `battle_test.gd` и `tools/pose_sheet.gd`.

### 2026-11-04 Задача 72: рукоять ополченца круче

- `game/scenes/creature.gd`: `turn_bones` принимает `Vector2(вертикаль, ось руки)`.
- `game/scenes/creature_test.gd`: `R_Hand` у ополченца `Vector2(30, -30)`.

### 2026-11-04 Задача 73: щит ополченца при получении удара

- `game/scenes/creature_test.gd`: `hurt_calm`, `hurt_calm_by` 0.25 у ополченца, те же кости, что в защите.

### 2026-11-04 Задача 74: короткий удар ополченца

- `game/scenes/creature_test.gd`: `attack_from` 0.0 → 0.17.

### 2026-11-04 Имя Фонарщик

- `game/scenes/creature_test.gd`: `name` → «Фонарщик»; описание, README и задачи. `id` и папки `lantern-archer` прежние.

### 2026-11-04 Задача 77: генерации в тесте существа

- `game/scenes/creature_test.gd`: `variants` в записи существа, `_pick_variant()`, `_variant_column()`, `ROMAN`.
- `game/scenes/creature.gd`: `set_textures()`.
- `pipelines/creature-recolor/retexture.py`: новая текстура по 4 видам с записью входа и результата.

### 2026-11-04 Задача 76: новая текстура Фонарщика

- `pipelines/creature-recolor/extract_textures.py`: новый; `retexture.py`: выбор модели по расширению.
- `game/assets/creatures/lantern-archer/generations/final-v1/`: `albedo.jpg`, `normal.jpg`, `orm.png`.
- `game/scenes/creature_test.gd`: `variants`, последняя — по умолчанию; `battle_test.gd`, `tools/icon_shot.gd`: финальная генерация.
- Команды: `.venv/bin/python pipelines/creature-recolor/retexture.py lantern-archer creatures/lantern-archer/concept/views-final final-v1` (20 кредитов, 985 → 965), `python3 -I pipelines/creature-recolor/extract_textures.py lantern-archer final-v1`.

### 2026-11-04 Задача 76: исправление текстуры Фонарщика

- `game/scenes/creature_test.gd`: путь `orm` был испорчен, карта материала не загружалась.
- `game/assets/creatures/lantern-archer/generations/final-v1/*.import`: `normal_map=0`, мипмапы как у остальных; пиктограмма снята заново.

### 2026-11-04 Задачи 78, 79: пайплайн и свет фонаря

- `pipelines/creature-recolor/README.md`, строка в `pipelines/README.md`; `make_glow.py`: карта свечения, кость и точка.
- `game/scenes/creature.gd`: `add_glow()`, `emission` в `set_textures()`.
- `game/scenes/creature_test.gd`, `battle_test.gd`: `glow` в варианте.
- `game/assets/creatures/lantern-archer/generations/final-v1/emission.png`.

### 2026-11-04 Задачи 76, 80: ополченец и поле

- `game/assets/creatures/militiaman/generations/concept-v2/`, `variants` у ополченца, новая пиктограмма.
- `game/scenes/battle_test.gd`: `COLS` 11, `ROWS` 7, `START_ROWS`, `MOVES`, `CAMERA_CLOSE` 0.92, `CREATURE_SCALE` 1.2, `_pan_by()`: два пальца, стрелки, правая кнопка.
- `pipelines/creature-recolor/`: путь без T-позы основной, `geometry` не использовать; `retexture.py`: докачка, `alignment`, виды от двух.
- Команды: `.venv/bin/python pipelines/creature-recolor/retexture.py militiaman creatures/militiaman/concept/views-concept concept-v2 original_image` (20 кредитов), `python3 -I pipelines/creature-recolor/extract_textures.py militiaman concept-v2`.

### 2026-11-04 Задача 81: подсветка противника

- `game/scenes/battle_test.gd`: `ENEMY_RANGE` 0.18, свечение пропорционально.

### 2026-11-04 Задача 82: стрелка под мечом

- `game/scenes/battle_test.gd`, `creature_test.gd`: `Input.mouse_mode` скрыт и при видимом мече.

### 2026-11-04 Задача 83: поле 11×11

- `game/scenes/battle_test.gd`: `ROWS` 11, `START_ROWS` `[0, 2, 4, 6, 8, 10]`, `CAMERA_CLOSE` 0.664: расстояние камеры то же, что при 7 рядах (при окне 16:9).
- Команды: `godot --path game res://scenes/battle_test.tscn -- --auto --shot=<путь>`.

### 2026-11-04 Задача 84: подсветка союзника

- `game/scenes/battle_test.gd`: `ENEMY_RANGE` → `INSPECT_RANGE`; в `_paint()` тусклая подсветка у всех, кроме текущего существа.

### 2026-11-04 Задача 85: дальние ряды

- `game/scenes/battle_test.gd`: `CAMERA_FOV` 30 вместо 55, `CAMERA_CLOSE` 0.681: расстояние 15,15 м, дальние ряды мельче ближних в 1,53 раза вместо 2,1.

### 2026-11-04 Задача 86: нижние углы поля

- `game/scenes/battle_test.gd`: `CAMERA_CLOSE` 0.782 (17,4 м), `CAMERA_SHIFT` 0.7 в `_place_camera()`.

### 2026-11-04 Задача 87: подсветка во время ходьбы

- `game/scenes/battle_test.gd`: в `_process` при `Turn.BUSY` существо под курсором не показывает дальность.

### 2026-11-04 Задача 88: трава и контуры

- `game/scenes/battle_test.gd`: `_build_grass()` (шум, `GROUND_SIZE` 80), `_build_lines()` (кольца одной сеткой), заливка гекса плоская и видна только при подсветке; `_paint()` меняет прозрачность вместо цвета плитки; плита-основание и `TILE_COLOR` убраны.

### 2026-11-04 Задача 89: угол обзора 20°

- `game/scenes/battle_test.gd`: `CAMERA_FOV` 20, `CAMERA_CLOSE` 0.839 (26,4 м), `CAMERA_SHIFT` 0.2.

### 2026-11-04 Задача 90: контуры в тени

- `game/scenes/battle_test.gd`, `_build_lines()`: материал освещаемый, нормаль вверх, порядок вершин лицом к камере, без `CULL_DISABLED`.

### 2026-11-04 Задача 91: одна заливка хода

- `game/scenes/battle_test.gd`: `INSPECT_RANGE` → `RANGE_ALPHA` 0.18; `strength` убран из `_paint()`.

### 2026-11-04 Задача 92: поле 12×10

- `game/scenes/battle_test.gd`: `COLS` 12, `ROWS` 10, `START_ROWS` `[0, 2, 4, 5, 7, 9]`, `CAMERA_CLOSE` 0.904 (те же 26,4 м).

### 2026-11-04 Задача 94: ровные контуры

- `game/scenes/battle_test.gd`: `_build_lines()` рисует каждое ребро один раз по середине границы; `LINE_WIDTH` в метрах, 0.03.

### 2026-11-04 Задача 95: поле по центру и крупнее

- `game/scenes/battle_test.gd`: `CAMERA_SHIFT_X` 0.26, `CAMERA_CLOSE` 0.853 (около 25 м).

### 2026-11-04 Задача 93: строка состояния

- `game/scenes/battle_test.gd`: `status` в правом нижнем углу с обводкой, `_status_text()` короче, `queue_bar.offset_top` 8.

### 2026-11-04 Задача 96: шкала веером

- `game/scenes/battle_test.gd`: `_queue_slot(c, current, shown)` отводит только видимую часть, карта уходит под предыдущую, `z_index` убывает по очереди; `_add_stack()`; `QUEUE_NOW`, `QUEUE_NEXT`, `QUEUE_GAP`, `QUEUE_MARGIN` 1.

### 2026-11-04 Задача 97: раскрытие карты

- `game/scenes/battle_test.gd`: `QUEUE_NOW` 2/3, `_hover_queue()` в `_process`, `QUEUE_HOVER` 18.

### 2026-11-04 Задача 98: сдвиг камеры при изменении окна

- `game/scenes/battle_test.gd`: `CAMERA_LOOK`; `_place_camera()` начинает с него, сдвиг больше не копится.
- Проверка: временный автозапуск-зонд разворачивал окно и печатал положение камеры; после проверки удалён.

### 2026-11-04 Задача 99: масштаб интерфейса

- `game/project.godot`: `window/stretch/mode="canvas_items"`, `window/stretch/aspect="expand"`.
- Проверка: временный зонд разворачивал окно и сверял все гексы с курсором, 120 из 120; после проверки удалён.

### 2026-11-04 Задача 100: текстура земли

- `pipelines/ground-fal/`: `generate.py`, `make_tile.gd`, README; `game/assets/ground/grass.png`.
- `game/scenes/battle_test.gd`: `_build_grass()` на шейдере: текстура с повтором 6 м, большие пятна шума, `GRASS_TINT`.

### 2026-11-04 Задача 101: преграды

- `pipelines/obstacle-fal/`; `obstacles/generations/{boulder,dead-tree,acid-barrel}/`; `game/assets/obstacles/*.glb`.
- `game/scenes/battle_test.gd`: `OBSTACLES`, `obstacles`, `_build_obstacles()`, `_bounds()`, `_tint()`; `_paths_from()` не пускает на преграды.

### 2026-11-04 Задача 102: без бочек

- `game/scenes/battle_test.gd`: в `OBSTACLES` пень и валун вместо бочек; модель `acid-barrel` удалена.

### 2026-11-04 Задача 103: преграды разного размера

- `game/scenes/battle_test.gd`: у `OBSTACLES` список `cells`; модель растягивается по занятым гексам; `OBSTACLE_OVER`.

### 2026-11-04 Задача 104: новые преграды

- Новые модели `rock-ridge`, `dead-tree-v2`, старые удалены; `game/scenes/battle_test.gd`: масштаб одинаковый по осям, `sink`, `_tint()` убран.

### 2026-11-04 Задача 105: `.gitignore`

- `.gitignore` по разделам, добавлены `.mono/`, `data_*/`, `mono_crash.*`, `.env.*`, `*.tmp`; `game/.gitignore` удалён; `game/scenes/action_icon.gd.uid` добавлен в git.

### 2026-11-04 Задача 106: поле 13×10

- `game/scenes/battle_test.gd`: `COLS` 13, `CAMERA_CLOSE` 0.920 (26,9 м), `cells` преград сдвинуты на колонку.

### 2026-11-04 Задача 107: поле 12×9, камера по полю

- `game/scenes/battle_test.gd`: `ROWS` 9, `START_ROWS`, `cells` преград; `_place_camera()` ищет наименьшее расстояние, при котором поле и головы дальнего ряда в кадре, и смотрит в середину допустимого; `CAMERA_SIDE`, `CAMERA_HEAD`, `CAMERA_SHIFT_X` -0.26, `_aim_camera()`; `CAMERA_CLOSE`, `CAMERA_SHIFT`, `CAMERA_LOOK` убраны.

### 2026-11-04 Задача 110: новая витрина

- `game/scenes/showcase.gd` переписана: круг анимаций существа, стрелки и клик меняют существо; `game/assets/showcase/` и `pipelines/creature/build_showcase.sh` удалены; `SCENES.md`.

### 2026-11-04 Задача 111: витрина списком

- `game/scenes/showcase.gd`: все существа на одной сцене по два в ряд, подписи над головами, прокрутка колесом, двумя пальцами и стрелками; `SCENES.md`.

### 2026-11-04 Задача 112: витрина квадратами

- `game/scenes/showcase.gd`, `showcase.tscn`: корень Control; у каждого существа SubViewport со своим миром в рамке, сетка в два столбца в ScrollContainer.
- `pipelines/creature-quadruped/model.py`: модель через Tripo API с лимитом 20 000.

### 2026-11-04 Задача 108: собака, скелеты

- `pipelines/creature-quadruped/`: `concept.py`, `model.py`, `rig.py`, `bones.py`, `joints.py`, README; строка в `pipelines/README.md`.
- `creatures/hound/`: концепт, модели, риги API и Studio, журнал `README.md`.
- Команды: `.venv/bin/python pipelines/creature-quadruped/model.py hound creatures/hound/concept/v1.png`, `.venv/bin/python pipelines/creature-quadruped/rig.py hound`.

### 2026-11-04 Задача 113: лаборатория собаки

- `game/scenes/hound_lab.gd`, `hound_lab.tscn`: наследует витрину, варианты в `VARIANTS`; `showcase.gd` разбит на `_build_page()`, `_finish()`, `_make_frame()`, `_make_label()`, собака из общей витрины убрана; `pipelines/creature-quadruped/presets.py`.

### 2026-11-04 Задача 115: привязка к скелету донора

- `pipelines/creature-quadruped/bind_donor.py`: подгонка костей, веса на сшитой копии с переносом; `creatures/hound/donors/fox/`; варианты в `game/scenes/hound_lab.gd`.
- Команда: `blender -b --python pipelines/creature-quadruped/bind_donor.py -- creatures/hound/donors/fox/fox.glb creatures/hound/tripo/hound-small.glb creatures/hound/donors/fox/hound-on-fox-welded.glb`.

### 2026-11-04 Лаборатория: замирание клипов

- `game/scenes/hound_lab.gd`: `_play_all` включает повтор клипа, иначе он стоял на последнем кадре до следующего запуска.

### 2026-11-04 Витрина: только видимые квадраты

- `game/scenes/showcase.gd`: `_process` выключает отрисовку квадратов за кадром, сглаживание убрано, в режиме `--shot` печатается FPS. Действует и на лабораторию.
- Замер в скрытом окне: 60 до и после, с `--disable-vsync` тоже; разницу показать не удалось.

### 2026-11-04 Задача 116: донор хаски

- `creatures/hound/donors/husky/`; `game/assets/creatures/hound/lab/hound-on-husky.glb`; `game/scenes/hound_lab.gd`: варианты хаски, размер сетки со скелетом без трансформа узла.
- Команда: `blender -b --python pipelines/creature-quadruped/bind_donor.py -- creatures/hound/donors/husky/husky.glb creatures/hound/tripo/hound-small.glb creatures/hound/donors/husky/hound-on-husky.glb`.

### 2026-11-04 Задача 117: клипы собаки

- `pipelines/creature-quadruped/name_clips.py`, `contact_sheet.gd`; `game/assets/creatures/hound/hound.glb`; `game/scenes/showcase.gd`: первый квадрат — собака, все клипы по кругу с подписями.

### 2026-11-04 Витрина собаки

- `game/scenes/hound_lab.gd`: 8 квадратов из `hound.glb`, 4 столбца; `showcase.gd`: собака убрана, `columns`, `cell_size`.

### 2026-11-04 Задача 109: псарь

- `creatures/houndmaster/`; `game/assets/creatures/houndmaster/houndmaster.glb`; `game/scenes/showcase.gd`: `NEW_CREATURES`.
- Команда: `.venv/bin/python pipelines/creature/stage2_tripo.py houndmaster` (65 кредитов API).

### 2026-11-05 Task 119: local Mixamo catalogue

- Added `catalogs/mixamo/catalog.json`: names, descriptions, types from 26 pages; 2484 entries, preserving variants.
- Added `catalogs/mixamo/catalog.md` and `README.md`: alphabetical table, search links, collection date and scope.
- Added `pipelines/mixamo-catalog/build.py`, `README.md` and index entry: validation, table generation and update instructions.
- Updated `TASKS.md` and `journals/SESSION.md`.
- Command: `python3 pipelines/mixamo-catalog/build.py` — 26 pages, 2484 entries; checks page sequence, row counts, required fields and duplicate whole pages.

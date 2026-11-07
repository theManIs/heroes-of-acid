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

### 2026-11-05 Задача 120: подбор клипов псаря

- Добавлен `creatures/houndmaster/mixamo/SELECTION.md`: восемь кандидатов, исходные описания, ключи снимка каталога, ссылки и ограничения применения.
- `creatures/houndmaster/README.md`: ссылка на подборку; `TASKS.md`: задача 120 выполнена, кандидаты ожидают принятия.
- Подбор по `catalogs/mixamo/catalog.json` через Python и `rg`; риг, игровые файлы и FBX не менялись.

### 2026-11-05 Задача 121: Mixamo на псаре

- `pipelines/creature-tripo-mixamo/rig_existing.py`: риг для существующей оплаченной модели, отдельное состояние, сохранение ID задачи до ожидания. Новый риг `creatures/houndmaster/tripo/rig.glb`: 65 костей, 25 кредитов; исходный Tripo-риг сохранён.
- `build_clips.py`: опция `keep_left_fingers` для обычной кисти; прежние значения по умолчанию фонарщика сохранены.
- `creatures/houndmaster/mixamo/`: 8 FBX, конфигурация `clips.json`, обновлённая подборка. `grip: 0`, пальцы включены, у бега `hip_scale: 0`.
- `game/assets/creatures/houndmaster/`: модель заменена новым ригом, 8 перенесённых GLB в `anims/`.
- `game/scenes/showcase.gd`: псарь показывает команду, бег и отклик в дополнение к остальным клипам, бег зациклен.
- `game/tools/pose_sheet.gd`: поддержаны существа, находящиеся пока только на витрине.
- Обновлены SCENES, TASKS (121 выполнена), журнал существа и пайплайн/индекс; по команде пользователя вход на сайты выполняет агент.
- Команды: `.venv/bin/python pipelines/creature-tripo-mixamo/rig_existing.py houndmaster`; `.venv/bin/python pipelines/creature-tripo-mixamo/build_clips.py houndmaster`; `godot --headless --path game --import`; лист поз `res://tools/pose_sheet.tscn -- --id=houndmaster`; витрина `res://scenes/showcase.tscn -- --shot=...`. Импорт успешен; просмотрены лист поз, исправленный бег и кадр витрины; FPS кадра 60. `git diff --check` — успешно.

### 2026-11-05 Завершение работы над существом

- `pipelines/README.md`: отдельная витрина конкретного существа обязательна в конце работы; ссылки из creature, creature-tripo-mixamo, creature-quadruped и creature-fal-mixamo.
- `TASKS.md`: задача 122 на отдельную витрину псаря, отложена по просьбе пользователя. Изменения только в документации.

### 2026-11-05 Задача 122: отдельная витрина псаря

- Добавлены `game/scenes/houndmaster_showcase.gd`, `.tscn`: наследует оформление витрины, сетка 4×2 с восемью клипами, циклические проигрываются постоянно, разовые повторяются через стойку; смерть включает `dead` для прижатия к земле.
- Обновлены SCENES, TASKS и README псаря.
- Команды: `godot --headless --path game --import`; `godot --path game --position 10000,10000 res://scenes/houndmaster_showcase.tscn -- --shot=...`; `git diff --check`. Импорт без ошибок, кадр с восемью квадратами просмотрен, FPS кадра 60.

### 2026-11-05 Задача 123: исходная поза ног в переносе Mixamo

- `build_clips.py`: qbetween, опция `_match_leg_rest`, согласование направлений бёдер/голеней/стоп до переноса отклонений, компенсация высоты таза. Опция выключена по умолчанию.
- `creatures/houndmaster/mixamo/clips.json`: опция включена; пересобраны восемь GLB в `game/assets/creatures/houndmaster/anims/`. Риг и геометрия сохранены.
- Обновлены TASKS, README существа, SELECTION, инструкция Mixamo и ARTIFACTS (60).
- Команды: `.venv/bin/python pipelines/creature-tripo-mixamo/build_clips.py houndmaster`; `godot --headless --path game --import`; `godot --path game --position 10000,10000 res://scenes/houndmaster_showcase.tscn -- --shot=...`; `git diff --check`. Импорт успешен, кадр восьми клипов просмотрен.

### 2026-11-05 Задача 124: три набора на витрине

- `game/scenes/houndmaster_showcase.gd`: три раздела по восемь квадратов, заголовки и прокрутка; готовая собака из HOUND_LAB, отдельные и парные повторы.
- Парные циклы с общим периодом, укус после 35 % команды, общие начала реакции/защиты/смерти. При поглаживании собака стоит, правая рука плавно направляется к голове через SkeletonIK3D с небольшим движением вдоль головы. Исходные клипы и риги не менялись.
- Камеры для падений/пары и запас плоскости земли; аргумент `--section=master|hound|pair` для кадров и просмотра.
- `pipelines/creature-pair-showcase/README.md` и индекс: рецепт; обновлены SCENES, TASKS, README псаря и собаки.
- Команды: `godot --headless --path game --import`; `godot --path game --position 10000,10000 res://scenes/houndmaster_showcase.tscn -- --section=... --shot=...` для трёх разделов; `git diff --check`. Кадры просмотрены, обрезание падений исправлено, ошибок импорта/скрипта нет, FPS кадра 60.

### 2026-11-05 Задача 125: бегство собаки после гибели псаря

- `game/scenes/houndmaster_showcase.gd`: парная смерть выделена в `_repeat_death_escape`, подпись «Гибель и бегство». Собака поворачивается от псаря, бежит на 5,5 м за край кадра, затем восстанавливается её исходный transform и стойка; псарь падает и остаётся лежать до сброса цикла.
- `ESCAPE_HOLD`: 2 с для просмотра павшего псаря после завершения падения. Готовый run зациклен, новые файлы анимаций не нужны.
- Обновлены пайплайн creature-pair-showcase и индекс, SCENES, TASKS и README псаря.
- Команды: `godot --path game --position 10000,10000 res://scenes/houndmaster_showcase.tscn -- --section=pair --shot=...`; `git diff --check`. Кадр просмотрен: собаки в квадрате гибели нет, псарь лежит; ошибок скрипта нет, FPS кадра 60.

### 2026-11-05 Задача 126: положение ладони при поглаживании

- `game/scenes/houndmaster_showcase.gd`: включён `override_tip_basis`, ориентация кисти строится по костям Hand/Middle1/Index1/Pinky1. Пальцы вдоль головы, ладонь вниз; цель запястья учитывает середину ладони, высота снижена до 0,035 м над Head, ход поглаживания ±0,045 м.
- Обновлены TASKS, README псаря, пайплайн creature-pair-showcase и индекс.
- Команды: `godot --path game --position 10000,10000 res://scenes/houndmaster_showcase.tscn -- --section=pair --shot=...`; `git diff --check`. Кадр просмотрен, кисть горизонтальна у макушки, запуск без ошибок, FPS кадра 60.

### 2026-11-05 Задача 128: переключаемая витрина

- `showcase.tscn` → `creature_gallery.gd`, выбор одной записи и соседние записи стрелками. `creature_gallery_page.gd` создаёт отдельные миры для всех выбранных игровых действий, включая дополнительные режимы стрельбы; сетка вписывается в окно. Псарь, собака и пара используют прежние согласованные ячейки.
- При переключении освобождается страница с мирами, IK и повторами. `--creature=<id>` задаёт начальную запись. Обновлены TASKS, SCENES и пайплайн.
- Команды: `godot --headless --path game --editor --import`, `godot --path game res://scenes/showcase.tscn`. Интерактивное принятие — пользователь.

### 2026-11-05 Задача 127: парный отряд в арене

- `houndmaster_config.gd`: общие файлы и клипы псаря для витрины и теста. `houndmaster_unit.gd`: подкласс Creature, собака в нижней части строя, общая ходьба, команда → укус с выпадом, реакции и защита, смерть псаря → бегство собаки. Единое здоровье, сброс клипов/твинов и отложенных действий.
- `creature_test.gd`: локальный реестр с парой, `--creature=houndmaster-pair`, фиксированная фигура из трёх гексов, проверка всей фигуры в BFS и при выборе атаки, подсветка и выбор обеих моделей; прокрутка реестра. Версия боя отменяет устаревшие переходы после сброса.
- Обводка собаки учитывает полный масштаб mesh (Armature донора ×100). В большом battle_test отряд не добавлялся.
- Обновлены TASKS (109, 127), SCENES и новый пайплайн creature-pair-gameplay. Команды: `godot --headless --path game --editor --import --quit`; запуск арены с `--creature=houndmaster-pair`; запрос текущего кадра через `screens/.shot`. Тесты не запускались; интерактивное принятие — пользователь.

### 2026-11-05 Задача 129: сначала собака, затем псарь

- `game/scenes/houndmaster_unit.gd`: `MovePhase` и две очереди маршрута. Переопределён `walk_path`: псарь ждёт в idle, собака проходит мировые точки нижних гексов. `_physics_process` сначала поворачивает собаку на месте по направлению очередного сегмента, затем двигает с walk; после маршрута запускает базовое движение псаря.
- `_process`: следование собаки за корнем и разворот вдоль строя действуют только вне фаз перемещения; собака остаётся в конце пути, пока псарь подходит. Общий arrived сохраняется после прибытия псаря; смерть и сброс очищают очереди и фазу.
- Обновлены задача 129 и пайплайн creature-pair-gameplay. Интерактивное принятие — пользователь; тесты не добавлялись и не запускались.
- Команды: `git diff --check`; перезапуск `godot --path game res://scenes/creature_test.tscn -- --creature=houndmaster-pair`. Сцена открыта для пользователя, ошибок загрузки в выводе нет.

### 2026-11-05 Задача 130: самостоятельная вылазка собаки

- `creature_test.gd`: отдельный BFS для двух нижних гексов собаки, до MOVE шагов; свой псарь и фигура противника блокируют путь. Клик по врагу выбирает доступную вылазку, подсветка показывает две клетки; атака не меняет позицию отряда. Клик по земле выполняет обычное перемещение без автоматического удара. ИИ атакует той же механикой, а при недоступной цели переставляет отряд.
- `houndmaster_unit.gd`: фазы RAID_HOLD/OUT/BACK, ожидание завершения маршрута собаки; команда 0,85 с, пробежка run, поворот, bite_lunge, попадание через 0,45 с, возврат по обращённому маршруту. Арена ждёт coroutine `raid`, а не фиксированное время удара. Смерть/сброс прерывают ожидание пути и задержки по версии состояния; твины выпада отменяются при сбросе.
- Обновлены TASKS, SCENES, creature-pair-gameplay и индекс, решения в game-aspects и SESSION, статус псаря. Тесты не добавлялись и не запускались; интерактивное принятие — пользователь.
- Команды: `git diff --check`; перезапуск `godot --path game res://scenes/creature_test.tscn -- --creature=houndmaster-pair`. Сцена открылась без ошибок загрузки в выводе.

### 2026-11-05 Задача 131: ограничить выпад при укусе

- `houndmaster_unit.gd`: BITE_STEP = 0,08 м и BITE_GAP = 0,04 м. Вместо сдвига корпуса до фиксированных 0,85 м от центра клетки цели — ограниченный шаг с вычетом выноса морды и полутолщины цели.
- `_measure_bite_reach`: при создании отряда передний край сетки привязывается к Head; по 33 позам bite_lunge определяется максимальный вынос в игровых метрах с учётом масштаба рига. После замера восстанавливаются idle и режим AnimationPlayer. Последняя точка подхода отодвигается, если клип уже достаёт до цели; изменённая точка включена в обратный маршрут.
- Обновлены TASKS, README псаря и creature-pair-gameplay с индексом. Тесты не добавлялись и не запускались, интерактивное принятие — пользователь.
- Команды: чтение AABB и translation-каналов GLB через Python; `git diff --check`; перезапуск `godot --path game res://scenes/creature_test.tscn -- --creature=houndmaster-pair`. В выводе запуска ошибок нет.

### 2026-11-05 Задача 132: пара в большой сцене боя, вылазка на всё поле

- `houndmaster_paths.gd`: общие фигуры (одна клетка, отряд из трёх, собака из двух), расстояние между фигурами, BFS без ограничения дальности вылазки. Тест существа использует тот же поиск; ошибочный лимит MOVE для атаки удалён.
- `battle_test.gd`: пара добавлена обеим армиям с прежней дальностью обычного перемещения; старт в дополнительной колонке у своей стороны, ряд 6. Проверка всей фигуры для перемещения, занятости, соседства, выбора и подсветки; препятствия и живые отряды блокируют все свои клетки. Собака атакует через `raid`, cells[who] не меняется; ИИ выбирает доступную вылазку, очередь ждёт её завершения и обновляется сигналом попадания.
- `Creature.melee_point` и реализация пары: обычные ближние атаки направлены к ближайшей модели составного отряда. Собака масштабируется вместе с псарём в бою; ограниченный шаг и измерение выноса морды сохранены.
- Общая запись пары в `houndmaster_config.gd`; icon_shot поддерживает парный портрет, создан `game/assets/creatures/houndmaster/icon.png` (256×256) и импортирован. Обновлены TASKS, SCENES, решения игры, README и пайплайн с индексом.
- Команды: `godot --path game --position 10000,10000 res://tools/icon_shot.tscn -- --id=houndmaster-pair`; `godot --headless --path game --editor --import --quit`; `godot --path game res://scenes/battle_test.tscn`; `git diff --check`. Тесты и --auto не запускались. Ошибок загрузки сцены в выводе нет. Интерактивный просмотр выполнен пользователем, результат принят.

### 2026-11-05 Задача 133, этап концепта молотобойца

- Сохранён референс пользователя `references/hammerer/character-sheet.jpg`, строка использования в references/README. В creatures/hammerer/concept — description.md, prompt.md, front-v1.png и generation.json; создан README существа.
- Концепт через ChatGPT в Chrome/CUA по исходному листу: техническая T-поза, свободные руки, сохранены шлем, сталь и синие акценты. Получен исходный PNG 1122×1402 через «Сохранить изображение как» прямо в проект. Просмотрен локальный файл. Чат генерации архивирован, после перезагрузки отсутствует в недавних и открыт home.
- TASKS 133 остаётся открытой до следующих этапов и принятия; уточнены pipeline creature-tripo-mixamo и индекс. ARTIFACTS 61 документирует native CUA ввод и обход ошибки DOM-управления. Встроенный image_gen не вызывался: использован Chrome по выбранному пайплайну.
- Команды: подготовка файлов через Python; `file creatures/hammerer/concept/front-v1.png`; `git diff --check`. Модель, риг и анимации не заказывались, игровые файлы не менялись.

### 2026-11-05 Generation chat archival timing

- Updated AGENTS, creature and creature-tripo-mixamo READMEs, ARTIFACTS 39: archive after the entire task, retain the chat for intermediate revisions and views.
- Copied AGENTS to /Users/artem/Documents/projects/AGENTS.md as required. Game files unchanged.

### 2026-11-05 12:40 — Hammerer concept v2 (133)

- Added concept/front-v2.png and exact prompt-v2.md through ChatGPT in Chrome native CUA.
- Updated generation.json: latest revision, conversation available for further work.
- Updated TASKS and SESSION; no game code changed.
- Commands: view_image front-v2.png; Python metadata and journal update; git add; git commit. No tests run.

### 2026-11-05 12:53 — Hammerer turnaround views (133)

- Canonical concept/front.png copied from accepted front-v2.png.
- Added views/left.png, back.png, right.png and exact prompts from the same ChatGPT conversation; source front attached to every request through native CUA.
- Updated metadata, description, README and task stage; user acceptance pending, no paid 3D jobs submitted.
- Commands: mkdir, cp, view_image for each PNG, Python metadata/journal updates, git add and git commit. No tests run.

### 2026-11-05 13:14 — Hammerer model, weapon and Mixamo showcase (133)

- Added Tripo body/model/rig sources and task states; paid IDs persisted before waiting. stage2.py now resumes an already submitted task.
- Generated isolated hammer reference in the same Chrome ChatGPT conversation, saved exact prompt and reference index. weapon.py creates the static weapon; prepare_weapon.py aligns Blender Z-up for GLTF Y-up, centers shaft and normalizes length.
- Downloaded Great Sword Pack through Chrome; selected eight FBXs and retained ZIP provenance. prepare_pack.py converts in one Blender session; build_clips.py applies ordinary hand settings, leg rest correction, horizontal hip pinning.
- pack_model.py repacks textures to 1024 px without changing rig, bindings or geometry.
- Added hammerer.tscn and hammer_grip.gd: dynamically instantiated weapon after body fitting, two palm centers define the rigid shaft, right wrist holds weapon when left hand releases.
- Added hammerer_config.gd; gallery discovers pending showcase creatures from NEW_CREATURES; larger camera envelope for pole weapon. Battle and creature arena integration remain after showcase acceptance.
- Updated task stage, README, pipeline index, SCENES and generation metadata.
- Commands: stage2.py hammerer; weapon.py hammerer; Blender prepare_pack.py and prepare_weapon.py; build_clips.py hammerer; pack_model.py for body and hammer; Godot asset import, pose_sheet authoring renders, showcase launch with --creature=hammerer and snapshot. No automated tests run; manual acceptance is the user.
- Result: body 19,938 triangles, 65 Mixamo bones, weapon 7,552 triangles; 105 Tripo credits (760 to 655); eight chosen clips, walk cadence measured 1.18 m/s.

### 2026-11-05 15:57 — Hammerer showcase metal lighting (133)

- showcase.gd: added optional neutral procedural Sky for reflections with the existing flat backdrop, plus a cool fill light (0.75 energy).
- hammerer_config.gd opts in; creature_gallery_page.gd applies the option per cell. Documented in the pipeline.
- Commands: Godot launch/snapshot; local Environment enum introspection to correct REFLECTION_SOURCE_SKY; updated showcase launch. No automated tests run.

### 2026-11-05 17:08 - Hammerer melee modes and arena integration (133, 134)

- Creature: configure/select/cycle melee modes independently of ranged shots; animation, impact timing and reach per mode. strike accepts collateral recipients using the same hit delay. Houndmaster override signature kept compatible.
- melee_area.gd: shared three-cell forward arc, all three cells adjacent to attacker; precision returns only target cell. Both arenas filter map edges and deduplicate squads by footprint, including friendly squads.
- Creature and battle arenas: mode buttons, area preview, friendly-fire warning, AI precision when allies would be hit. Hammerer added to roster, battle move range 3 and an additional starting row (8 squads per side).
- Gallery: two distinct attack cells, 9 clips in a 3x3 grid. Added Mixamo great sword attack source and retargeted attack_point.glb. Added icon.
- metal_lighting.gd: reused approved neutral lighting for the hammerer in creature arena and icon; original environment restored for other selections.
- User feedback correction: removed target-centered transverse line; replaced ternary untyped empty arrays with typed Array[Vector2i] initialization to prevent aborted paint calls. Added explicit hover reset on window mouse exit in both arenas.
- Commands: prepare_pack.py, build_clips.py, Godot asset import and icon generation, point-attack authoring render, creature arena launches, runtime-log inspection, screenshot request. No automated tests run; user performs interactive acceptance.
- Updated TASKS, SCENES, pipeline and creature documentation.

### 2026-11-05 17:35 — Precision hammer strike (136)

- Replaced rejected sword attack with a reproducible 1.1 s two-handed thrust derived from Mixamo idle. author_point.py solves both arms against palm targets; same rig, stationary feet/pelvis, short windup and recovery.
- build_clips.py handles _point_strike; point impact 0.48, weapon reach 1.45. Shared config applies to gallery and both arenas.
- Auditioned slash (4)/(5) and downloaded Bayonet Stab through Chrome/CUA; wide cuts and reversed shaft grip unsuitable. Preserved Bayonet source, excluded from runtime.
- Commands: Blender conversion, build_clips.py, Godot import, pose_sheet authoring renders. No automated tests; manual acceptance remains with user.

### 2026-11-05 17:36 — Visible hammerer fidget (137)

- Replaced subtle idle (2) with idle (3), 3.6 s weapon-lowering/hand-on-hip gesture. Preserved chosen FBX and rebuilt fidget.glb; gallery uses the same clip.
- Added hammerer-only Fidget button to creature arena: full clip at normal speed, no turn consumed, busy guard, reset cancellation through round ID. Other roster entries retain existing controls.
- Commands: build_clips.py, Blender conversion of three idle candidates, pose_sheet authoring render, Godot import and normal scene launch. No automated tests; manual acceptance by user.

### 2026-11-05 17:44 — Overhead precision strike correction (136)

- User rejected the invented thrust. Removed author_point.py and _point_strike path. Precision now uses the existing Mixamo overhead great sword slash (3), with identical hit timing/reach to area; damage stays single-target.
- Added per-source aliases in build_clips.py to preserve a separately named attack_point animation and gallery cell from the same source. Rebuilt clips; updated selection and pipeline.
- Command: .venv/bin/python pipelines/creature-tripo-mixamo/build_clips.py hammerer. No tests run; manual acceptance by user.

### 2026-11-05 17:47 — Hover response correction (137)

- Existing task 114 defines fidget as a decorative response when hovering an idle creature. Previous implementation incorrectly added a button; no arena hover trigger existed. Removed button and busy/turn-lock preview.
- Creature.set_fidget_hovered starts the configured fidget once per cursor entry, only from idle while alive, stationary and not defending. Normal gameplay animations interrupt it; no combat turn consumed. Hammerer opts in; other creatures remain under pending 114.
- Creature arena detects hover over either model; battle uses existing inspected unit. Gallery retains the same visible fidget clip. Updated scene and pipeline documentation.
- Commands: build_clips.py, Godot import and pose_sheet asset authoring render, normal showcase/arena launch. No automated tests or manual gameplay acceptance performed.

### 2026-11-05 18:04 — Allied-only hover fidget (137)

- Creature arena no longer invokes enemy hover fidget. Battle arena only invokes it for sides[0]. Shared animation and idle guard unchanged. Updated scene and pipeline descriptions. No tests run.

### 2026-11-05 18:08 — Hammer recovery correction (138)

- Added per-clip recovery in build_clips.py: keep original keys through 28/30 s, then smooth quaternion/hip interpolation to idle over 0.7 s. Removed the original post-contact upward sword recovery. Final length 1.6333 s; impact 0.56122449 preserves contact at 0.9167 s, reach unchanged.
- Rebuilt attack and its temporary attack_point alias. 136 explicitly remains unfinished: alias is rejected by user, not a distinct vertical attack. Updated source selection and pipeline, including background-only browser requirement.
- Commands: build_clips.py, Godot asset import, pose_sheet asset authoring render. No tests run; visual/manual acceptance is the user’s.

### 2026-11-05 18:39 — Separate Mixamo downward precision strike (136)

- User authorized active-tab Chrome after background failure and explicitly rejected invented animation. Abandoned the unconnected local authoring draft; no authored attack code or asset retained.
- Downloaded original Bash, Standing Melee Attack Downward and Great Sword Slash / Great Sword Downward Slash through Chrome/CUA; preserved FBXs. Bash and axe clip are one-handed, excluded. Chosen exact Downward result renamed Great Sword Downward Slash.fbx for provenance.
- Removed area alias. build_clips.py supports trim_start and time_scale: chosen source starts at 0.5 s to exclude lateral windup, time stretched x1.5 without pose changes. Final duration 1.15 s, hit 0.25 s, impact 0.2173913 and reach 1.6. Shared config used by both arenas and gallery.
- Commands: build_clips.py with Blender FBX conversion, Godot asset import, pose_sheet authoring renders, normal showcase and arena launch. No automated tests run; user performs interactive acceptance.

### 2026-11-05 18:48 — Full hammer follow-through (138)

- Extended preserved source sweep through 35/30 s instead of 28/30; 0.7 s recovery begins after follow-through. Clip length 1.8667 s; impact 0.49107143 preserves contact at 0.9167 s.
- Added full_clip melee option; hammer area opts in, so play_once does not cut at hit + 0.3 s. Animation returns to idle on completion. Other attacks retain existing timing.
- Command: build_clips.py hammerer. No tests run; manual acceptance remains with user.

### 2026-11-05 18:49 — Pair footprint tint (135)

- Removed creature-arena pair-only permanent blue/red footprint tint. Other creatures never had it; reachable-anchor and action footprint painting/path checks preserved. No tests run.

### 2026-11-05 18:50 — Dog hurt before escape (140)

- Lethal pair hit starts master fall and dog hurt_head_left together. Escape turn waits for actual dog hurt clip duration instead of 0.55 s. Updated paired gallery death sequence too. No dog death clip used; reset cancellation preserved. No tests run.

### 2026-11-05 18:51 — Pair hover comparison and response (141)

- Compared config and hover code: only hammerer opted into arena fidget; pair had petting clip and contact IK only in showcase. Other creatures remain under open 114. Enabled existing pair fidget, allied-only through existing arena guards.
- Ported accepted showcase palm/head IK into HoundmasterUnit, targeting actual dog head and smoothly enabling only during petting. Combat/movement disable the modifier; dog stays standing. No new source motion generated; no tests run.

### 2026-11-05 18:52 — Wait for complete master command (142)

- Removed fixed 0.85 s launch lead. Pair command plays full clip without Creature attack cutoff; raid waits until actual command playback ends, checking epoch/death/target cancellation every frame. Dog then runs, bites and returns as before.
- Paired gallery now also waits full command before dog action. hit_delay compatibility derives command duration and playback speed. No tests run.

### 2026-11-05 18:57 — Correct simultaneous pair launch (142)

- User explicitly clarified simultaneous start. Removed newly introduced command-completion wait from raid and paired gallery. Master command continues while dog starts its route immediately; bite contact and return unchanged. hit_delay compatibility has no command lead. Supersedes previous 142 interpretation.
- Updated pair pipeline and scene guide, plus hammer follow-through documentation. Imported Godot assets and opened normal showcases; no automated tests run.

### 2026-11-05 — задачи 145 и 144

`game/scenes/battle_test.gd`, `game/scenes/creature_test.gd`: свободный достижимый гекс важнее рамки тела пары.

```diff
+		var over_body := _over_body(c, screen) and not (_is_pair(c) and _free_step(hex))
+func _over_enemy(screen: Vector2) -> bool:
```

`game/scenes/houndmaster_unit.gd`: вылазка шагом или бегом, скорость по клипу.

```diff
-		var running := _move_phase in [MovePhase.RAID_OUT, MovePhase.RAID_BACK]
-		_dog_play("run" if running else "walk", walk_rate)
-		var speed := walk_speed * walk_rate * (2.0 if running else 1.0)
+		var raiding := _move_phase in [MovePhase.RAID_OUT, MovePhase.RAID_BACK]
+		var clip := _raid_clip if raiding else "walk"
+		var rate := walk_rate if clip == "walk" else 1.0
+		var speed: float = (_gait_speed[clip] if raiding else walk_speed) * rate
+	_raid_clip = "run" if points.size() >= RAID_RUN_FROM else "walk"
```

Проверка: скрипт без окна в песочнице сессии, сцена `creature_test` и вылазки на 1 и 4 гекса.

### 2026-11-05 — задача 144, уточнение

`game/scenes/houndmaster_unit.gd`: ускорение боя применяется и к бегу, исключение убрано.

```diff
-		var rate := walk_rate if clip == "walk" else 1.0
-		_dog_play(clip, rate)
+		_dog_play(clip, walk_rate)
```

### 2026-11-05 — задача 146

`game/scenes/houndmaster_paths.gd`: `cover`, `anchor_for`. `game/scenes/creature_test.gd`, `game/scenes/battle_test.gd`: `_move_anchor`, подсветка и клик по всей фигуре.

```diff
-	if reachable.has(h) and h != _hex_of(player):
-		_move_and_maybe_strike(player, enemy, reachable[h], _start_enemy_turn)
+	var anchor := _move_anchor(h)
+	if anchor != NO_HEX:
+		_move_and_maybe_strike(player, enemy, reachable[anchor], _start_enemy_turn)
```

### 2026-11-05 — задача 147

`game/scenes/creature.gd`, `game/scenes/houndmaster_unit.gd`: поворот к противнику отдельным методом.

```diff
-	target.face(position)
+	target.face_foe(position)
+func face_foe(point: Vector3) -> void:
+	super.face(point)
+	var to := point - (get_parent() as Node3D).to_local(_dog.global_position)
+	to.y = 0.0
+	if to.length() > 0.01:
+		_dog_yaw = atan2(to.x, to.z)
```

### 2026-11-05 — задача 148

`game/scenes/houndmaster_unit.gd`: собака не смотрит прямо вверх на своего псаря.

```diff
+const UP_TILT := deg_to_rad(35.0)
+	var from_up := wrapf(yaw - PI, -PI, PI)
+	if absf(from_up) < UP_TILT:
+		var side := signf(from_up) if absf(from_up) > 0.001 else (-1.0 if sin(_dog_yaw) >= 0.0 else 1.0)
+		yaw = PI + side * UP_TILT
```

### 2026-11-05 — задача 149

`game/scenes/houndmaster_unit.gd`: `_update_petting`, поворот и наклон псаря, подход собаки.

```diff
-	_pet_ik.root_bone = &"mixamorig_RightArm"
+	_pet_ik.root_bone = &"mixamorig_Spine1"
-		var forward := (_dog.global_position - global_position).normalized()
+	var look := rotation.y - FRONT_YAW
+	var forward := Vector3(sin(look), 0.0, cos(look))
+		_yaw = atan2(to.x, to.z) - PET_HEAD_ANGLE
+	_pet_shift = pull.normalized() * gap * weight
```

Проверка: кадры в скрытом окне, сбоку, спереди и с боевой камеры, обе стороны.

### 2026-11-05 — задача 150

Поглаживание убрано: `houndmaster_unit.gd` без IK и `_update_petting`, `houndmaster_showcase.gd` без `_add_petting_target`.
Новый клип: `creatures/houndmaster/mixamo/Neck Stretching.fbx` → `game/assets/creatures/houndmaster/anims/fidget_neck.glb`.

```diff
-	"fidget": "fidget_pet"
+	"fidget": "fidget_neck"
+func set_fidget_hovered(hovered: bool) -> void:
+	var entered := hovered and not _fidget_hovered
+	super.set_fidget_hovered(hovered)
+	if entered and ... _dog_anim.current_animation == DOG_IDLE:
+		_dog_play(DOG_FIDGET)
```

Команды: `.venv/bin/python pipelines/creature-tripo-mixamo/build_clips.py houndmaster`, `godot --headless --path game --import`.

### 2026-11-05 — задача 151

`creatures/houndmaster/mixamo/Standing Block React Large.fbx` → `game/assets/creatures/houndmaster/anims/defend_block.glb`.

```diff
-	"defend": "defend",
+	"defend": "defend_block",
-	["Защита", "defend", false]
+	["Защита", "defend_block", false]
```

### 2026-11-05 — задача 152

`game/scenes/houndmaster_unit.gd`: защита собаки с середины клипа.

```diff
+const DOG_DEFEND_FROM := 0.8
-			_dog_play("defend_lower_head")
+			_dog_play("defend_lower_head", 1.0, DOG_DEFEND_FROM)
+		if from > 0.0:
+			_dog_anim.seek(from, true)
```

### 2026-11-05 — задача 153

`game/scenes/hammer_grip.gd`: боёк по ходу взмаха в ударе по площади.

```diff
+	var length_now := 1.5 * _unit.height / 1.9
+	frame = _face_target(frame, axis, right + axis * length_now * 0.75, delta)
+func _face_target(frame: Basis, axis: Vector3, head: Vector3, delta: float) -> Basis:
+	var across := velocity - axis * velocity.dot(axis)
+	var strike := Basis(axis.cross(z).normalized(), axis, z)
```

### 2026-11-05 — задача 153, переделка

`game/scenes/hammer_grip.gd`: поворот во время клипа (`_face_target`) убран, вместо него постоянный поворот в хвате.

```diff
+const HEAD_ROLL := deg_to_rad(-80.0)
+	frame = frame * Basis(Vector3.UP, HEAD_ROLL)
```

### 2026-11-05 — задача 154

`game/scenes/creature.gd`, `game/scenes/hammerer_config.gd`: без отхода назад в точечном ударе.

```diff
+var no_backstep := false
+	no_backstep = cfg.get("no_backstep", false)
+	if no_backstep:
+		lunge = maxf(lunge, 0.0)
-"impact": 0.2173913, "reach": 1.6},
+"impact": 0.2173913, "reach": 1.6, "no_backstep": true},
```

### 2026-11-05 — задача 154, удар по площади

`game/scenes/hammerer_config.gd`: `"no_backstep": true` и у режима `area`.

### 2026-11-05 — задача 156 и проба 155

`game/scenes/creature_gallery_page.gd`: квадраты по ширине окна с прокруткой (`CELL_TARGET` 460); `showcase_extra` — пробные клипы на витрине.
`game/scenes/hammerer_config.gd`: `shoulder_equip.glb` в `extra`, ячейка «Проба: на плечо».

### 2026-11-05 — задача 157, макет всадника

Новое: `game/scenes/rider_lab.gd/.tscn`, `creatures/rider/` (README, `mixamo/clips.json`, FBX, копия рига), `game/assets/creatures/rider/anims/ride_idle.glb`.
Команды: `.venv/bin/python pipelines/creature-tripo-mixamo/build_clips.py rider`, `godot --headless --path game --import`.

### 2026-11-06 — задача 157, витрина макета

Новое: `game/scenes/rider_mock.gd` (конь, бёдра, посадка), `game/scenes/rider_showcase.gd/.tscn`; `rider_lab.gd` переведён на общий макет. Шесть новых FBX в `creatures/rider/mixamo/`, клипы `game/assets/creatures/rider/anims/`.

### 2026-11-06 — задача 158

Новое: `game/scenes/rider_search.gd/.tscn`, `creatures/rider/mixamo/search/` (17 FBX), клипы `s_*` в `game/assets/creatures/rider/anims/`.
`rider_showcase.gd`: обрезка «с какой секунды» в `_make_fidget_cell`, заморозка правой руки и в квадратах езды; `rider_mock.gd`: новые клипы в `ALL_CLIPS`.

### 2026-11-06 — задача 160, конь

Команды: `python3 -I pipelines/creature-quadruped/concept.py horse v1 "<запрос>"`; `.venv/bin/python pipelines/creature-quadruped/model.py horse creatures/horse/concept/v1.png`;
`blender -b --python pipelines/creature-quadruped/bind_donor.py -- creatures/horse/donors/quaternius-horse/horse.glb creatures/horse/tripo/horse.glb creatures/horse/donors/quaternius-horse/horse-on-donor.glb`;
`python3 -I pipelines/creature-quadruped/name_clips.py … game/assets/creatures/horse/horse.glb Idle=idle_breathe …`.
Новое: `game/scenes/horse_lab.gd/.tscn`.

### 2026-11-06 — задачи 162–163, копьё и всадник

Команды: `python3 -I pipelines/creature-quadruped/concept.py rider lance "<запрос>"`; `.venv/bin/python weapon.py rider ../../creatures/rider/concept/lance.png lance.glb`;
`blender -b --python pipelines/creature-tripo-mixamo/prepare_weapon.py -- creatures/rider/weapon/lance.glb game/assets/creatures/rider/lance.glb`;
`.venv/bin/python pipelines/creature-tripo-mixamo/stage2.py rider`; `pack_model.py creatures/rider/tripo/rig.glb game/assets/creatures/rider/body.glb`; `build_clips.py rider`.
Код: `rider_mock.gd` — `set_lance`, `tip`, модель копья, `RIDER` на `body.glb`; `rider_pair.gd` — `metal_lighting` в каждом квадрате; `weapon.py` — картинка и имя файла аргументами, создание папки.

### 2026-11-06 — задача 164

`game/scenes/showcase.gd`: `cell_zoom`, `_zoom_grid`, `_input` — щипок (`InputEventMagnifyGesture`) и Ctrl/Cmd+колесо. `rider_pair.gd`, `horse_lab.gd`, `rider_showcase.gd`, `rider_search.gd`: размер квадрата `CELL_TARGET * cell_zoom`.

### 2026-11-06 08:56

- `rider_mock.gd`: + `arm_out` (постоянный поворот плеча в клипе), + `palm` (центр ладони); `place_lance` хватает по ладони.
- `rider_pair.gd`: `ARM_OUT −50`, `ARM_UP 25`, `LANCE_YAW −8`; плечо отводится в `ride_still` после заморозки руки.
- Проверка: скрытые замеры зазоров (scratchpad lancebody.gd, lancemesh.gd), крупный рендер.

### 2026-11-06 09:12

- `rider_mock.gd`: + `_clip_global`, `_turn_bone`, `grip_bones`, `grip_hand`, `fist`; `place_lance` берёт центр кулака; `LANCE_GRIP` 0,62 → 0,605.
- `rider_pair.gd`: `GRIP_CURL 45`, хват в `ride_still`, кисть и пальцы в `pin_to` замороженных клипов.
- Проверка: рендеры кисти с четырёх сторон (scratchpad hand.gd), замеры lancebody.gd / lancemesh.gd.

### 2026-11-06 09:15

- + `game/scenes/rider_hand.gd/.tscn`: витрина одного рыцаря (поза стойки с хватом из витрины пары), 4 вида: целиком и кисть сбоку, сверху, спереди.

### 2026-11-06 09:17

- `rider_mock.gd`: `curl_fingers` выделен из `grip_hand` (только сгиб пальцев), + `fist_axis` (канал кулака: мизинец → указательный).
- `rider_hand.gd`: кисть без поворота, пальцы в кулак, тонкая палка через центр кулака по его каналу.

### 2026-11-06 09:20

- `rider_mock.gd`: + `aim_bone` (кость на направление, кратчайший поворот), + `roll_fist` (поворот предплечья вокруг своей оси: канал кулака к копью, запястье не гнётся).
- `rider_hand.gd`: копьё вдоль тела — `ARM_DIR` (0.1, −1, 0.8), `FOREARM_DIR` (1, −0.8, 0.5), `LANCE_DIR` (1, 0, 0.15); пробы ниже упирали палку в бедро и колено.

### 2026-11-06 09:28

- `rider_mock.gd`: канал кулака наискось (указательный → пяточка ладони, `HEEL 0.6`), + `bend_wrist` (довод запястья к мизинцу, не больше предела).
- `rider_hand.gd`: хват для укола — `ARM_DIR` (−0.1, −1, 0.75), `FOREARM_DIR` (1, 0.1, 0.3), `LANCE_DIR` (1, −0.15, 0.15), `WRIST_LIMIT 30`. Замер (scratchpad handaxis.gd): остриё 10° вниз, 9° наружу, промах 1,4°, зазор до костей ног и корпуса 0,23 м.

### 2026-11-06 09:35

- `rider_mock.gd`: + `pour` (поворот предплечья вокруг своей оси, как при выливании воды).
- `rider_hand.gd`: переделан — рука как в витрине пары (`arm_out`), кулак, палка по кулаку; квадраты с поворотом −60°, −70°, −80°. Перебор −60…80° по кадрам, замер (scratchpad pouraxis.gd): остриё 6°/10°/13° вниз, внутрь 11°/8°/4°, зазор до костей ≥0,26 м.

### 2026-11-06 09:57

- `rider_mock.gd`: + `place_fist_lance` (копьё по каналу кулака), + `LanceKeeper` (модификатор: разворот плеча и предплечья, точное решение угла), канал кулака наискось; удалены `grip_hand`, `level_lance`, `fist_pitch`, `_clip_global_at`, `bend_wrist`, `roll_fist`, `aim_bone`, `palm`, параметр `turn_out`.
- `rider_pair.gd`: `POUR −70`, `LANCE_PITCH −8`, `LANCE_YAW 3`, хранитель копья в каждой паре, выключен в смерти; убраны `LANCE_YAW −8` (старый), `ARM_TURN`, `LEVEL_SLACK`.
- Проверка (scratchpad): keep.gd (наклон и разворот копья по кадрам), lancemesh.gd (зазор до шеи/головы покадрово + кадр худшего момента), lancebody.gd, closecell.gd (кисть вблизи).

### 2026-11-06 10:03

- `rider_pair.gd`: `ARM_OUT` −50 → −35, `ARM_UP` 25 → 0 — кулак ниже на 14 см. Замер: тело 0,20 м, шея/голова коня 0,31–0,52 м.

### 2026-11-06 10:22

- + `game/scenes/rider_unit.gd`, `game/scenes/rider_config.gd`, `game/assets/creatures/rider/rider_unit.tscn`.
- `rider_pair.gd`: подготовка руки вынесена в `prepare_lancer`, хранитель — в `add_keeper`; «idle» рыцаря заменён стойкой с копьём.
- `creature_test.gd`: «rider» в списке существ, `RIDER_UNIT`.
- Проверка: `--shot` (арена, удар), scratchpad riderct.gd (шаг, реакция, защита, отклик, смерть), riderdbg.gd (копьё −8° у обоих).

### 2026-11-06 10:31

- `rider_unit.gd`: `body_shift`, `center()`, `face()` только ±X (на ходу — по движению), `_center_on_hip` отключён, сдвиг тела и рывка в `_process` с учётом `jolt`.
- `creature_test.gd`: `_footprint` всадника — якорь и сосед справа; `body_shift` = полшага гекса.
- Проверка: scratchpad rider2.gd (подход, удар, ответ), hlen.gd (длина коня 2,90 м).

### 2026-11-06 10:40

- `rider_unit.gd`: `SCALE 0.85` (рыцарь, копьё, свисание ног), `face()` на ходу — по движению, `_on_arrived` — вдоль ряда.
- `rider_mock.gd`: `make_rider(size)`, `set_lance`/`place_fist_lance` с масштабом.
- `rider_config.gd`: рост коня 1,615.
- Проверка: scratchpad rider2.gd (зазор вплотную), rider3.gd (поворот на ходу и после).

### 2026-11-06 10:42

- `rider_unit.gd`: свой `strike` без твина модели (двойной сдвиг: ездил взад-вперёд и рывком возвращался), `melee_point` — середина пары, `STEP_BACK` × 0,85. Проверка: scratchpad rider4.gd — сдвиг модели по кадрам.

### 2026-11-06 10:48

- `rider_unit.gd`: `STAND_TURN` 12° — стоя всадник повёрнут от копья (влево), `_stand_face`. Замер (scratchpad rider5.gd): лицом к лицу головы коней в 0,59 м (поперёк 0,35 м).

### 2026-11-06 10:54

- `battle_test.gd`: «rider» в составе, `RIDER_UNIT`, `RIDER_SHAPE`, `_shape()`, `RIDER_ROW`, `_single_index` (строки одиночных без пары и всадника), ход 5, `body_shift` по `RADIUS`.
- `rider_unit.gd`: `scale_k` = рост коня / 1,9 вместо постоянного `SCALE`.
- `tools/icon_shot.gd`: всадник (вполоборота, рыцарь и голова коня); `rider_config.gd`: `icon`, `icon_dist`.
- + `game/assets/creatures/rider/icon.png`.
- Проверка: scratchpad battle.gd (`--auto`, бой до конца, всадники ходят, бьют, гибнут), rider5.gd (тест существа без изменений).

### 2026-11-06 11:01

- `rider_mock.gd`: `LANCE_LENGTH` 3,2 → 2,6 (толщина прежняя), хвост за обмоткой сжат (`_short_tail`: от 0,68 до торца ×0,45), `LANCE_BACK` по новой форме. Замер: остриё впереди 2,51 → 2,20 м; зазоры до коня 0,38–0,52 м.

### 2026-11-06 11:04

- `rider_mock.gd`: хвост копья не сжат, а вырезан (`CUT_FROM` 0,70, `CUT_LEN` 0,21: торец сдвинут целиком), `LANCE_GRIP` 0,605 → 0,565 — кулак у гарды.
- `rider_unit.gd`: обводка выбора и на копье (обводка рыцаря закрывала древко у кулака).
- Проверка: scratchpad lanceview.gd (копьё до/после), draw.gd (кисть у гарды).

### 2026-11-06 14:28

- + `creatures/hammerer/mixamo/search/*.fbx` (13), записи `search/…` в `clips.json`, `game/assets/creatures/hammerer/anims/c_*.glb`.
- `hammer_grip.gd`: `right_at` (по умолчанию 0,2 — без изменений для текущих клипов).
- + `game/scenes/hammerer_search.gd/.tscn`; `SCENES.md`.
- Команды: Chrome/Mixamo (Without Skin, In Place), `build_clips.py hammerer`, `godot --import`; рендер scratchpad hsshot.gd.

### 2026-11-06 14:38

- `build_clips.py`: `file`, `arms_from`, `arms_from()`.
- `clips.json`: записи `round2/c2_*`; + `anims/c2_*.glb`.
- `hammerer_search.gd`: `_cells()`, `_idle_clip()`; + `hammerer_set.gd/.tscn`; `SCENES.md`.

### 2026-11-06 14:40

- + `game/scenes/hammerer_overlay.gd/.tscn` (только c2_* + стойка и удар); `SCENES.md`.

### 2026-11-06 14:47

- `hammerer_overlay.gd`: `_cells()`; + `hammerer_rest.gd/.tscn` (стойка, два блока, Smash, две смерти); `SCENES.md`.

### 2026-11-06 15:07

- `clips.json`: `round2/c2_defend`, `round2/c2_fall` (прежние блок и смерть, руки из стойки); + `anims/c2_defend.glb`, `c2_fall.glb`.
- `hammerer_overlay.gd`: ячейки защиты и смерти; `hammerer_search.gd`: `c2_fall` лежит до повтора.

### 2026-11-06 15:14

- `hammerer_search.gd`: `RIGHT_AT` 0,8 → 0,62 (руки ближе к середине рукояти).

### 2026-11-06 15:16

- `hammer_grip.gd`: `rigid_clips` — в этих клипах молот жёстко в правой кисти с хватом стойки (калибровка первым кадром), переход плавный.
- `hammerer_search.gd`: прежний `attack_point` в жёстком режиме; `hammerer_overlay.gd`: ячейка точечного удара.

### 2026-11-06 15:29

- `clips.json`: прежние → `old_*`, `aliases` новых, `round2/attack` (взмах, `trim_start` 1,0), `hip_scale` 0 у стойки, взмаха, отклика.
- `hammer_grip.gd`: `right_at` 0,62, `rigid_clips`, `HEAD_ROLL` 59°.
- `hammerer_config.gd`: попадание и вынос площадного удара, точечный 0,333.
- Проверка: scratchpad hamimpact.gd (попадание и боёк), hamct.gd (тест существа), battle.gd (автобой).

## 2026-11-06 23:20 — задача 168: новая модель молотобойца

- `creatures/hammerer2/concept/views/{left,back,right}.png` + промпты; `tripo/` (model.glb, rig.glb, state).
- `creatures/hammerer2/mixamo/clips.json`: 9 записей набора 167 с `file: ../../hammerer/mixamo/...`.
- `game/assets/creatures/hammerer2/`: body.glb, anims/*, hammerer.tscn (копия прежней с новым body), icon.png.
- `game/scenes/hammerer_config.gd`: icon/scene/extra → hammerer2; `size 1.9→2.3`, `walk_speed 1.18→1.43`, `showcase_size 2.7→3.2`.
- Команды: `stage2.py hammerer2`; `pack_model.py creatures/hammerer2/tripo/rig.glb game/assets/creatures/hammerer2/body.glb`; `build_clips.py hammerer2`; Godot `--import`; `icon_shot.tscn -- --id=hammerer`; снимок витрины `--shot`; headless battle_test/creature_test (ошибка idle у всадника — была и до изменений).

## 2026-11-06 23:35 — задача 170: раскраска молотобойца «светлая сталь»

- `pipelines/creature-recolor/recolor_by_pair.py` (новый) + строка в README пайплайна.
- `creatures/hammerer2/concept/views-final/*`, `tripo/generations/silver/*`.
- `game/assets/creatures/hammerer2/generations/silver/{albedo.jpg,normal.jpg,orm.png}` + .import (mode 2, limit 2048, mipmaps, normal_map 0); `icon.png` перерисован.
- `game/scenes/hammerer_config.gd`: `variants` [бронза, светлая сталь].
- Команды: `recolor_by_pair.py`; `retexture.py hammerer2 creatures/hammerer2/concept/views-final silver`; проверка позиций+UV (5D, 0 расхождений); `extract_textures.py hammerer2 silver`; Godot `--import`; `icon_shot`; снимок витрины.

## 2026-11-06 23:45 — задача 171: боёк молота от владельца

- `game/scenes/hammer_grip.gd`: `HEAD_ROLL` 59° → −38°, комментарий обновлён.
- Замер: скрипт в scratchpad (`face_out.gd`), угол между −Z молота и направлением от груди (Spine2) к бойку поперёк рукояти; в стойке было −97°, стало ±8°. Снимок витрины до/после.

## 2026-11-06 23:55 — задача 169: ошибка idle у всадника

- `game/scenes/creature.gd` (setup, подмена idle): `remove_animation("idle")` только при `has_animation("idle")` — у коня всадника своего idle нет. Поведение прежнее: idle добавлялся и раньше.
- Проверка: headless `battle_test.tscn --quit-after 600` и `creature_test.tscn --quit-after 300` — 0 строк с error.
- Архивирован чат ChatGPT молотобойца (`creatures/hammerer2/concept/generation.json`: archived true).

## 2026-11-07 00:30 — задача 118: бег дальше половины хода

- `game/scenes/creature.gd`: `LOOPED` + "run"; `GAIT_FEET`; `move_range`, `run_ratio`, `_gait`; в `setup` замер `_measure_step_speed("walk"/"run")` (скорость носка/лапы на опоре, медиана); `wants_run(steps)` — `steps * 2 > move_range`; `walk_path` выбирает аллюр; `walk_to` играет `_gait`; `_play` — `walk_rate` и для run; движение `gait_speed()`; по прибытии `_gait = "walk"`.
- `game/scenes/houndmaster_unit.gd`: `walk_path` выбирает `_gait`; собака в обычном ходе играет `_gait`, бег — `walk_speed × run/walk` лап собаки.
- `game/scenes/battle_test.gd`: `c.move_range = MOVES[id]`; `creature_test.gd`: `c.move_range = MOVE`.
- Проверка: headless скрипт — молотобоец, всадник, пара: 1 гекс шагом, 3 гекса бегом; фонарщик без клипа бега — шагом. battle_test/creature_test headless без ошибок.

## 2026-11-07 00:50 — задача 172: иконка альтернативного огня

- `game/scenes/battle_test.gd`: убрана текстовая `melee_mode_button`; `mode_button` («Альтернативный огонь», иконка FIRE_MODE, вид постоянный) видна в каждый ход игрока; `_alternative_text(unit)` — режим удара (молотобоец) или огня (стрелок); пусто — кнопка неактивна (0,4). `_switch_mode` прежний.
- Задача 173 (удар всадника с разбега) заведена, не начата.
- Проверка: headless battle_test без ошибок.

## 2026-11-07 01:05 — задача 173: удар всадника с разбега

- `game/scenes/rider_unit.gd`: `_bake_attack(parts)` — части параметром; новый клип `attack_charge` (run 0,3 с + idle 0,5 с); `CHARGE_IMPACT 0.12`, `CHARGE_PUSH 0.35 × scale_k`, `_charge_shift` (синус: вперёд и обратно); `_arrived_frame` по сигналу `arrived`; `strike` — пришёл в этом же кадре (≤2) → `attack_charge`, иначе прежний `attack`; `impact` по выбранному клипу; RIDER_CLIPS + attack_charge.
- Проверка: headless скрипт — после пути `attack_charge`, hit_delay 0,12; стоя `attack`, 0,95; battle_test/creature_test без ошибок.

## 2026-11-07 01:25 — задача 174: дальность всадника по всей фигуре

- `game/scenes/houndmaster_paths.gd`: `cover(moves, from, shape = PAIR)`; новый `head_anchor(cell, moves, from, none, shape)` — клетка = голова по ходу движения (вправо — правая клетка фигуры, влево — левая), иначе другая клетка фигуры.
- `game/scenes/battle_test.gd`: `_anchor_of(c, hex, moves)` (пара / всадник / одиночный) для клика и наведения; подсветка всадника — `cover` с `RIDER_SHAPE`.
- `game/scenes/creature_test.gd`: `RIDER_SHAPE`, `_move_anchor` и подсветка для всадника так же; `_footprint` через форму.
- Проверка: скрипт — при ходе 5 голова вправо до x=6, влево до −5; клик (6,0)→якорь (5,0), (−5,0)→(−5,0); обе арены headless без ошибок.

## 2026-11-07 01:40 — 173, правка: всадник влетает в цель

- `game/scenes/rider_unit.gd`: `attack_charge` = run 0,4 с + walk задом 0,6 с + idle 0,4 с; `_charge_shift` — вперёд на `CHARGE_PUSH 0.8 × scale_k` с торможением, попадание в упоре (impact = 0,4 с), назад smoothstep; убраны `CHARGE_RUN`, `CHARGE_IMPACT`.
- Проверка: headless скрипт — после пути `attack_charge`, hit_delay 0,4; стоя прежний `attack`.

## 2026-11-07 — 175: молотобоец 85 %

`game/scenes/hammerer_config.gd`
```diff
-	"size": 2.3, "walk_speed": 1.43,  # 168: …
+	"size": 1.955, "walk_speed": 1.2155,  # 175: 85 % от 2,3 — вмещается в свой гекс; шаг в той же доле
```

## 2026-11-07 — 175: ещё −10 %

`game/scenes/hammerer_config.gd`
```diff
-	"size": 1.955, "walk_speed": 1.2155,  # 175: 85 % от 2,3 …
+	"size": 1.76, "walk_speed": 1.094,  # 175: 85 % от 2,3, ещё −10 % …
```

## 2026-11-07 — 176: клетки под фигурой не подсвечиваются

```diff
diff --git a/game/scenes/battle_test.gd b/game/scenes/battle_test.gd
index d719adb..b91e25a 100644
--- a/game/scenes/battle_test.gd
+++ b/game/scenes/battle_test.gd
@@ -1109,9 +1109,10 @@ func _paint() -> void:
 	var hover_anchor := NO_HEX
 	if preview:
 		hover_anchor = _anchor_of(preview, _hovered, shown)
+	var own: Array[Vector2i] = _footprint(preview) if preview else []  # 176: все клетки под фигурой — не ход
 	for h: Vector2i in tiles:
 		var color := Color(tint, 0.0)
-		if area.has(h) and h != center:
+		if area.has(h) and not own.has(h):
 			color.a = RANGE_ALPHA
 			if h == _hovered:
 				color.a = lerpf(RANGE_ALPHA, 1.0, 0.5)
diff --git a/game/scenes/creature_test.gd b/game/scenes/creature_test.gd
index d2912df..f001113 100644
--- a/game/scenes/creature_test.gd
+++ b/game/scenes/creature_test.gd
@@ -917,10 +917,11 @@ func _paint() -> void:
 		zone = _impact_cells(player, enemy, _attack_from)
 	var area: Dictionary = PAIR_PATHS.cover(reachable, _hex_of(player)) if tested == "houndmaster-pair" else PAIR_PATHS.cover(reachable, _hex_of(player), RIDER_SHAPE) if tested == "rider" else reachable
 	var anchor := _move_anchor(_hovered)
+	var own := _footprint(_hex_of(player))  # 176: все клетки под фигурой — не ход
 	for h: Vector2i in tiles:
 		var mat: StandardMaterial3D = tiles[h].material_override
 		var color: Color = tiles[h].get_meta("base")
-		if area.has(h) and h != _hex_of(player):
+		if area.has(h) and not own.has(h):
 			color = color.lerp(PLAYER_TURN, 0.25)
 			if h == _hovered:
 				color = color.lerp(PLAYER_TURN, 0.35)
```

## 2026-11-07 — 177: псарь −10 %, собака +10 %

```diff
diff --git a/game/scenes/houndmaster_config.gd b/game/scenes/houndmaster_config.gd
index 068474c..58dbcf3 100644
--- a/game/scenes/houndmaster_config.gd
+++ b/game/scenes/houndmaster_config.gd
@@ -2,12 +2,12 @@ extends RefCounted
 ## Общая запись псаря: витрина и тест отряда используют одни файлы.
 const ANIMS := "res://assets/creatures/houndmaster/anims/"
 const MASTER := {
-	"name": "Псарь", "scene": "res://assets/creatures/houndmaster/houndmaster.glb", "size": 2.0,
+	"name": "Псарь", "scene": "res://assets/creatures/houndmaster/houndmaster.glb", "size": 1.8,  # 177: −10 % от 2,0
 	"extra": [ANIMS + "idle.glb", ANIMS + "walk.glb", ANIMS + "run.glb", ANIMS + "command_attack.glb",
 		ANIMS + "hurt.glb", ANIMS + "defend_block.glb", ANIMS + "fall.glb", ANIMS + "fidget_neck.glb"],
 	"attack": "command_attack", "attack_label": "команда «фас»", "attack_from": 0.0,
 	"hurt": "hurt", "hurt_len": 0.0, "idle": "idle", "defend": "defend_block", "defend_from": 0.0,
-	"defend_len": 0.0, "defend_lead": 0.3, "run": "run", "fidget": "fidget_neck", "walk_speed": 1.2,
+	"defend_len": 0.0, "defend_lead": 0.3, "run": "run", "fidget": "fidget_neck", "walk_speed": 1.08,  # 177: шаг в той же доле
 }
 
 
diff --git a/game/scenes/houndmaster_unit.gd b/game/scenes/houndmaster_unit.gd
index 9251cff..470a0cf 100644
--- a/game/scenes/houndmaster_unit.gd
+++ b/game/scenes/houndmaster_unit.gd
@@ -5,7 +5,7 @@ const DOG_SCENE := preload("res://assets/creatures/hound/hound.glb")
 const DOG_IDLE := "idle_breathe"
 const DOG_DEFEND_FROM := 0.8  # с; в клипе голова уходит вниз с 0,6 до 1,2 с из 4
 const DOG_FIDGET := "fidget_sniff_ground"  # свой отклик собаки, без касания псаря
-const DOG_HEIGHT := 1.05
+const DOG_HEIGHT := 1.2833  # 177: при псаре 1,8 собака 1,155 — +10 % к прежним 1,05
 const BITE_IMPACT := 0.45
 const BITE_STEP := 0.08  # короткий шаг корпуса, основной выпад уже есть в клипе
 const BITE_GAP := 0.04
```

## 2026-11-07 — 178: стрела фонарщика вдвое быстрее

```diff
diff --git a/game/scenes/creature_test.gd b/game/scenes/creature_test.gd
index f001113..d362aff 100644
--- a/game/scenes/creature_test.gd
+++ b/game/scenes/creature_test.gd
@@ -26,7 +26,7 @@ const CREATURES := {
 		# Дальний бой: стреляет с места. kind — снаряд, hand — откуда летит, release — доля клипа в момент выпуска,
 		# title — подпись режима огня, no_adjacent — нельзя с врагом вплотную, rate — скорость клипа, speed — скорость снаряда, м/с, arc — высота дуги, доля расстояния до цели.
 		"shots": {
-			"arrow": {"title": "лук", "no_adjacent": true, "anim": "shoot", "hand": "LeftHand", "release": 0.42, "rate": 0.55, "speed": 11.0, "arc": 0.12},
+			"arrow": {"title": "лук", "no_adjacent": true, "anim": "shoot", "hand": "LeftHand", "release": 0.42, "rate": 0.55, "speed": 22.0, "arc": 0.12},  # 178: вдвое быстрее
 			"lantern": {"title": "фонарь", "anim": "throw", "hand": "RightHand", "release": 0.37, "rate": 1.0, "speed": 5.0, "arc": 0.14},
 		},
 	},
```

## 2026-11-07 — 179: тетива фонарщика кодом

Новые: `game/scenes/bow_string.gd`, `game/assets/creatures/lantern-archer/lantern-archer.tscn`.

```diff
diff --git a/game/scenes/creature_test.gd b/game/scenes/creature_test.gd
index d362aff..6f04ca1 100644
--- a/game/scenes/creature_test.gd
+++ b/game/scenes/creature_test.gd
@@ -13,7 +13,7 @@ const CREATURES := {
 		# Генерации: цифры в этой сцене, для просмотра. Последняя — финальная, она идёт в сцену боя и на пиктограмму.
 		"variants": [{"title": "первая, зелёный плащ"}, {"title": "финальный концепт", "textures": {"albedo": "res://assets/creatures/lantern-archer/generations/final-v1/albedo.jpg", "normal": "res://assets/creatures/lantern-archer/generations/final-v1/normal.jpg", "orm": "res://assets/creatures/lantern-archer/generations/final-v1/orm.png", "emission": "res://assets/creatures/lantern-archer/generations/final-v1/emission.png"},
 			"glow": {"bone": "mixamorig_RightUpLeg", "point": Vector3(0.0741, 0.4916, 0.1013), "color": Color(1.0, 0.55, 0.15), "energy": 0.8, "range": 1.2}}],
-		"scene": "res://assets/creatures/lantern-archer/lantern-archer.glb",  # риг Tripo со spec: mixamo, анимации Mixamo (пайплайн creature-tripo-mixamo)
+		"scene": "res://assets/creatures/lantern-archer/lantern-archer.tscn",  # 179: обёртка с тетивой; риг Tripo со spec: mixamo, анимации Mixamo (пайплайн creature-tripo-mixamo)
 		"extra": ["res://assets/creatures/lantern-archer/anims/idle.glb", "res://assets/creatures/lantern-archer/anims/walk.glb",
 			"res://assets/creatures/lantern-archer/anims/fall.glb", "res://assets/creatures/lantern-archer/anims/hurt.glb",
 			"res://assets/creatures/lantern-archer/anims/shoot.glb", "res://assets/creatures/lantern-archer/anims/throw.glb",
```

Проверка: кадры idle/shoot отрисованы скрытым Godot (screens/lantern-archer-bowstring.png).

## 2026-11-07 — 179 отменена

Удалены `game/scenes/bow_string.gd`, `lantern-archer.tscn`; в `creature_test.gd` сцена фонарщика снова `lantern-archer.glb`.

## 2026-11-07 — 180: главный экран

Новые: `game/scenes/hub.gd`, `hub.tscn`, `hub_back.gd`, `game/assets/ui/hub/{creature_test,battle_test,showcase}.jpg`.

```diff
diff --git a/game/project.godot b/game/project.godot
index 7bee79d..9a38579 100644
--- a/game/project.godot
+++ b/game/project.godot
@@ -5,7 +5,7 @@ config_version=5
 [application]
 
 config/name="Heroes of Acid"
-run/main_scene="res://scenes/creature_test.tscn"
+run/main_scene="res://scenes/hub.tscn"
 config/features=PackedStringArray("4.7")
 
 [display]
diff --git a/game/scenes/battle_test.gd b/game/scenes/battle_test.gd
index b91e25a..b328106 100644
--- a/game/scenes/battle_test.gd
+++ b/game/scenes/battle_test.gd
@@ -5,6 +5,7 @@ extends Node3D
 ## Запуск: godot --path game res://scenes/battle_test.tscn
 ## Отладка: -- --auto — обе стороны играют сами, ускоренно; -- --shot=<префикс> — кадры <префикс>-start.png, -end.png.
 
+const HUB_BACK := preload("res://scenes/hub_back.gd")  # 180: кнопка «Назад» на главный экран
 const ARENA := preload("res://scenes/creature_test.gd")  # записи существ — там
 const HOUNDMASTER_UNIT := preload("res://scenes/houndmaster_unit.gd")
 const PAIR_PATHS := preload("res://scenes/houndmaster_paths.gd")
@@ -133,6 +134,7 @@ func _ready() -> void:
 	_build_world()
 	_build_board()
 	_build_hud()
+	HUB_BACK.add(self)  # 180
 	_place_camera()
 	get_viewport().size_changed.connect(_place_camera)
 	_reset()
diff --git a/game/scenes/creature_gallery.gd b/game/scenes/creature_gallery.gd
index 8ffb8bd..f6f22fe 100644
--- a/game/scenes/creature_gallery.gd
+++ b/game/scenes/creature_gallery.gd
@@ -3,6 +3,7 @@ extends Control
 
 const PAGE := preload("res://scenes/creature_gallery_page.gd")
 const ARENA := preload("res://scenes/creature_test.gd")
+const HUB_BACK := preload("res://scenes/hub_back.gd")  # 180: кнопка «Назад» на главный экран
 var _ids: Array = []
 var _selector := OptionButton.new()
 var _page: Control
@@ -45,6 +46,7 @@ func _ready() -> void:
 			selected = _ids.find(arg.trim_prefix("--creature="))
 	_selector.select(selected)
 	_select(selected)
+	HUB_BACK.add(self)  # 180
 
 
 func _select(index: int) -> void:
diff --git a/game/scenes/creature_test.gd b/game/scenes/creature_test.gd
index d362aff..299d131 100644
--- a/game/scenes/creature_test.gd
+++ b/game/scenes/creature_test.gd
@@ -6,6 +6,7 @@ extends Node3D
 ## Снимок идущей игры: создать файл screens/.shot — игра запишет кадр в screens/current/arena.png и удалит файл.
 
 # Проверяемое существо: оба бойца — оно. Новое существо — добавить запись в CREATURES; выбор — пиктограммы слева.
+const HUB_BACK := preload("res://scenes/hub_back.gd")  # 180: кнопка «Назад» на главный экран
 const TESTED := "lantern-archer"  # с кого начинать
 const CREATURES := {
 	"lantern-archer": {
@@ -161,6 +162,7 @@ func _ready() -> void:
 	_build_board()
 	_build_hud()
 	_reset()
+	HUB_BACK.add(self)  # 180
 	get_window().mouse_exited.connect(_clear_hover)
 	get_window().mouse_entered.connect(func(): _pointer_inside = true)
 	for arg in OS.get_cmdline_user_args():
```

Проверка: скрытый прогон hub → каждая сцена → «Назад» → hub, темп 1,0 после боя.

## 2026-11-07 — 180: заголовок главного экрана

```diff
diff --git a/game/scenes/hub.gd b/game/scenes/hub.gd
index c775505..ff51b3a 100644
--- a/game/scenes/hub.gd
+++ b/game/scenes/hub.gd
@@ -25,7 +25,7 @@ func _ready() -> void:
 	column.add_theme_constant_override("separation", GAP)
 	center.add_child(column)
 	var title := Label.new()
-	title.text = "Heroes of Acid — проверки"
+	title.text = "Heroes of Acid — прогоны механик"
 	title.add_theme_font_size_override("font_size", 34)
 	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 	column.add_child(title)
```

## 2026-11-07 — 183: четвероногие — основной

```diff
diff --git a/pipelines/README.md b/pipelines/README.md
index 426a8ed..8b1be96 100644
--- a/pipelines/README.md
+++ b/pipelines/README.md
@@ -34,7 +34,7 @@
 | [`creature-recolor`](creature-recolor/README.md) | новая раскраска готового существа, модель и риг прежние | не меняется | не меняется | не меняются | кредиты Tripo, 20 за текстуру | основной |
 | [`ground-fal`](ground-fal/README.md) | текстура земли | gpt-image через fal | не нужен | не нужны | счёт fal | проба, задача 100 |
 | [`obstacle-fal`](obstacle-fal/README.md) | преграда на поле боя, статичная модель | Meshy через fal | не нужен | не нужны | счёт fal | проба, задача 101 |
-| [`creature-quadruped`](creature-quadruped/README.md) | существо на четырёх лапах | Tripo API | скелет донора Quaternius, привязка в Blender | донора | кредиты Tripo, только модель | проба, задача 108 |
+| [`creature-quadruped`](creature-quadruped/README.md) | существо на четырёх лапах | Tripo API | скелет донора Quaternius, привязка в Blender | донора | кредиты Tripo, только модель | основной, задачи 108, 159; зафиксирован 183 |
 | [`3d-model`](3d-model/README.md) | то же, что `creature`, для других проектов | Tripo | Tripo | пресеты Tripo | кредиты Tripo | копия |
 | [`mixamo-catalog`](mixamo-catalog/README.md) | локальный каталог названий и описаний | — | — | метаданные Mixamo через Chrome/CUA; сборка таблицы Python | — | проба, задача 119 |
 | [`creature-pair-showcase`](creature-pair-showcase/README.md) | витрина псаря, собаки и пары | готовые игровые модели | готовые риги | готовые клипы, синхронизация, контакт руки и бегство собаки в Godot | — | проба, задачи 124–126, 128 |
diff --git a/pipelines/creature-quadruped/README.md b/pipelines/creature-quadruped/README.md
index c8130fe..6b5ffe8 100644
--- a/pipelines/creature-quadruped/README.md
+++ b/pipelines/creature-quadruped/README.md
@@ -1,6 +1,10 @@
-# Пайплайн: существо на четырёх лапах (проба, задача 108)
+# Пайплайн: существо на четырёх лапах (основной, задача 183)
 
-Не завершён. Подробности, цены и находки по первой собаке: [creatures/hound/README.md](../../creatures/hound/README.md).
+Зафиксирован пользователем 2026-11-07: «всё получилось». Пройден дважды — собака псаря (108)
+и конь всадника (159). Шаги ниже менять только по решению пользователя.
+
+Журналы: собака — [creatures/hound/README.md](../../creatures/hound/README.md),
+конь — [creatures/horse/README.md](../../creatures/horse/README.md).
 
 **Проверено:**
 
@@ -11,7 +15,10 @@
 
 5. Привязка к скелету донора с анимациями: `blender -b --python pipelines/creature-quadruped/bind_donor.py -- <донор.glb> <наша.glb> <выход.glb>`. Метод проверен на лисице.
 
-**Источник анимаций:** донор Quaternius (хаски, CC0) через `bind_donor.py`. Даёт стойку, укус, ходьбу, бег, реакцию, смерть.
+**Источник анимаций:** донор Quaternius (CC0, poly.pizza) через `bind_donor.py`: хаски для собаки,
+Horse для коня. Даёт стойку, удар, ходьбу, бег, реакцию, смерть, отклик.
+
+6. Игровой файл с понятными именами клипов: `name_clips.py`, затем отдельная витрина существа.
 
 **Не сработало:** Text to Motion в Studio генерирует движение человека и к собаке не применяется. Общие пресеты API на риге `quadruped` отклоняются. Бесплатная выгрузка из Studio анимаций не содержит. Риг Tripo в этом пути не нужен.
 
```

## 2026-11-07 — 182: каталог ошибок и автопроверка

Новые: `pipelines/creature-mixamo-first/{ERRORS.md,check_clips.gd,check.sh}`.

```diff
diff --git a/game/scenes/hammerer_config.gd b/game/scenes/hammerer_config.gd
index 90de881..2272bcf 100644
--- a/game/scenes/hammerer_config.gd
+++ b/game/scenes/hammerer_config.gd
@@ -10,6 +10,7 @@ const UNIT := {
 	"attack": "attack", "attack_from": 0.0, "hurt": "hurt", "hurt_len": 0.0,
 	"idle": "idle", "run": "run", "fidget": "fidget", "defend": "defend",
 	"fidget_on_hover": true,
+	"weapon_face": {"axis": Vector3(0, 0, -1), "idle": "out"},  # 182: плоский боёк молота (−Z модели) от владельца — проверка пайплайна
 	"defend_from": 0.0, "defend_len": 0.0, "defend_lead": 0.3,
 	"size": 1.76, "walk_speed": 1.094,  # 175: 85 % от 2,3, ещё −10 % — вмещается в свой гекс; шаг в той же доле
 	"variants": [{"title": "бронза"}, {"title": "светлая сталь", "textures": {"albedo": "res://assets/creatures/hammerer2/generations/silver/albedo.jpg", "normal": "res://assets/creatures/hammerer2/generations/silver/normal.jpg", "orm": "res://assets/creatures/hammerer2/generations/silver/orm.png"}}],  # 170
```

Прогоны: check.sh hammerer — 0 провалов; lantern-archer — нет отклика (верно); houndmaster — бёдра 19° (верно); c_club_combo/shoulder_equip/old_attack — пойманы E05/E06/E09/E10.

## 2026-11-07 — 181: пайплайн creature-mixamo-first

Новые: `pipelines/creature-mixamo-first/README.md`, `game/scenes/weapon_grip.gd`, `game/scenes/mannequin_search.{gd,tscn}`; `check_clips.gd` — режим `--set`, `_moving`. Таблица пайплайнов: новая строка основной, `creature` и `creature-tripo-mixamo` — старые.

Проверка: витрина манекена с заглушками топора и щита отрисована скрытым окном; check.sh hammerer — 0 провалов.

## 2026-11-07 — 184: кандидаты на манекене

Новое: `creatures/militiaman2/` (риг манекена, наборы Mixamo, `clips.json` 45, `candidates.json` 33), `game/assets/creatures/militiaman2/anims/`. `mannequin_search.gd` — своя стойка у квадрата, `check_clips.gd` — то же.

Команды: build_clips.py militiaman2; check_clips.gd --set=militiaman2.

## 2026-11-07 — 185: манекен X Bot

Новое: `pipelines/creature-mixamo-first/mannequin.py`, `game/assets/mannequin/xbot.glb`, `creatures/militiaman2/tripo/{xbot.fbx,rig.glb,rig-mannequin.glb}`. `mannequin_search.gd` и `check_clips.gd` — тело по умолчанию X Bot; кадр 1,15 роста. Кандидаты пересобраны build_clips.py militiaman2.

## 2026-11-07 — 184/186: набор ополченца и стойка со щитом

Новое: `game/scenes/militiaman2_config.gd`; `creatures/militiaman2/mixamo/inplace/*.fbx`; клипы ролей в `game/assets/creatures/militiaman2/anims/`.

```diff
diff --git a/game/scenes/creature.gd b/game/scenes/creature.gd
index 361adc9..55032f2 100644
--- a/game/scenes/creature.gd
+++ b/game/scenes/creature.gd
@@ -67,6 +67,12 @@ var melee_modes := {}
 var melee_mode := ""
 var fidget_anim := ""  # декоративный отклик при наведении на бездействующее существо
 var _fidget_hovered := false
+## 186: альтернативная стойка (ополченец — щит перед собой). Свои стойка, шаг и реакция на удар,
+## ход короче; атака выводит из стойки. {"title", "enter", "idle", "walk", "hurt", "exit", "move"}
+var stance := {}
+var in_stance := false
+var _base := {}  # обычные стойка, шаг, реакция и бег на время стойки
+var _stance_walk_speed := 0.0
 
 var _model_base := Vector3.ZERO
 var _target := Vector3.ZERO
@@ -194,6 +200,10 @@ func _align_hips() -> void:
 				anchor += a.track_get_key_value(t, k)
 			anchor /= a.track_get_key_count(t)
 		var shift := home - anchor
+		if skeleton.get_bone_name(_hip()) == "mixamorig_Hips":
+			# 184: клипы Mixamo стоят на земле сами; высоту таза не трогаем, иначе низкая стойка
+			# (топор) опускает шаг на 8 см и стопа уходит в землю (E07).
+			shift.y = 0.0
 		for k in a.track_get_key_count(t):
 			a.track_set_key_value(t, k, a.track_get_key_value(t, k) + shift)
 
@@ -372,13 +382,66 @@ func walk_path(points: Array[Vector3]) -> void:
 	walk_to(_path.pop_front())
 
 
+## 186: стойка настраивается после setup: клипы стойки уже подмешаны из extra.
+func configure_stance(cfg: Dictionary) -> void:
+	stance = cfg if cfg.has("idle") and anim.has_animation(cfg.idle) else {}
+	if stance.has("walk") and anim.has_animation(stance.walk) and anim.has_animation("walk"):
+		var base := _measure_step_speed("walk")
+		_stance_walk_speed = walk_speed * _measure_step_speed(stance.walk) / base if base > 0.0 else walk_speed
+		anim.play("idle")
+		anim.advance(0.0)
+
+
+## Ход за ход с учётом стойки: в стойке — доля move от обычного, не меньше гекса.
+func moves(base: int) -> int:
+	return maxi(1, int(base * stance.get("move", 1.0))) if in_stance else base
+
+
+## Войти в стойку или выйти из неё. animate — сыграть подъём или опускание щита.
+func set_stance(on: bool, animate := true) -> void:
+	if stance.is_empty() or on == in_stance:
+		return
+	in_stance = on
+	var library := anim.get_animation_library(&"")
+	if on:
+		_base = {"idle": library.get_animation("idle"), "walk": library.get_animation("walk") if library.has_animation("walk") else null,
+			"hurt": hurt_anim, "run_ratio": run_ratio}
+		_swap(library, "idle", anim.get_animation(stance.idle))
+		if stance.has("walk") and anim.has_animation(stance.walk):
+			_swap(library, "walk", anim.get_animation(stance.walk))
+		hurt_anim = stance.get("hurt", hurt_anim)
+		run_ratio = 0.0  # со щитом перед собой не бегает
+	else:
+		_swap(library, "idle", _base.idle)
+		if _base.walk != null:
+			_swap(library, "walk", _base.walk)
+		hurt_anim = _base.hurt
+		run_ratio = _base.run_ratio
+	if dead or walking:
+		return
+	var clip: String = stance.get("enter" if on else "exit", "")
+	if animate and anim.has_animation(clip):
+		anim.play(clip, BLEND, 1.0)  # по окончании — новая стойка (_on_animation_finished)
+		anim.seek(0.0, true)
+	else:
+		anim.play("idle", BLEND)
+
+
+func _swap(library: AnimationLibrary, anim_name: String, source: Animation) -> void:
+	var copy := source.duplicate()
+	copy.loop_mode = Animation.LOOP_LINEAR
+	library.remove_animation(anim_name)
+	library.add_animation(anim_name, copy)
+
+
 ## Бежать ли по пути из steps гексов: дальше половины своего хода и есть клип бега.
 func wants_run(steps: int) -> bool:
 	return run_ratio > 0.0 and move_range > 0 and steps * 2 > move_range
 
 
 func gait_speed() -> float:
-	return walk_speed * (run_ratio if _gait == "run" else 1.0) * walk_rate
+	var step := _stance_walk_speed if in_stance and _stance_walk_speed > 0.0 else walk_speed
+	return step * (run_ratio if _gait == "run" else 1.0) * walk_rate
 
 
 ## Скорость стопы на опоре в клипе (без направления: клипы на месте), для отношения бег/шаг.
@@ -467,7 +530,7 @@ func play_once(anim_name: String) -> void:
 func set_fidget_hovered(hovered: bool) -> void:
 	var entered := hovered and not _fidget_hovered
 	_fidget_hovered = hovered
-	if not entered or dead or walking or defending or fidget_anim.is_empty():
+	if not entered or dead or walking or defending or in_stance or fidget_anim.is_empty():
 		return
 	if anim.current_animation != "idle" or not anim.has_animation(fidget_anim):
 		return
@@ -683,6 +746,7 @@ func melee_point(_from: Vector3) -> Vector3:
 
 ## Кулак не достаёт до выбранной части цели — выпад вперёд, затем возврат.
 func strike(target: Creature, _distance: float, overlap: float, collateral: Array[Creature] = []) -> void:
+	set_stance(false, false)  # 186: атака опускает щит, удар идёт из стойки со щитом
 	var contact := target.melee_point(position)
 	face(contact)
 	target.face_foe(position)
@@ -782,6 +846,7 @@ func die() -> void:
 
 func revive() -> void:
 	hits = 0
+	set_stance(false, false)
 	if dead:
 		dead = false
 		model.position = _model_base  # _pin_hip держал таз падающего над гексом и сдвинул модель
```

Также: creature_test.gd и battle_test.gd — props, configure_stance, _fill_reachable/_moves, кнопка альтернативы; creature_gallery_page.gd — props и клипы стойки; check_clips.gd — уклон и манекен.

Проверки: check.sh militiaman2 — 0 провалов; check_clips hammerer/houndmaster/lantern-archer — как раньше; скрытый тест стойки (ход 3→1, shield_hurt, атака выходит из стойки).

## 2026-11-07 — 184/186: правки после просмотра

mannequin.py — поворот на +X; clips.json — u_idle/u_walk/u_run/u_look1 вместо боевых; militiaman2_config.gd — reach 1,0, walk_speed 0,97; arenas — cfg.reach; creature.gd — defend_anim в стойке = удар в щит.

Замеры (тест существа): стойка 10° к цели, шаг 1° к ходу, удар без захода (0,03 м); стойка держится после удара и «Защиты».

## 2026-11-07 — 186: атака не снимает стойку

```diff
diff --git a/game/scenes/creature.gd b/game/scenes/creature.gd
index 2337482..9c211d0 100644
--- a/game/scenes/creature.gd
+++ b/game/scenes/creature.gd
@@ -68,7 +68,7 @@ var melee_mode := ""
 var fidget_anim := ""  # декоративный отклик при наведении на бездействующее существо
 var _fidget_hovered := false
 ## 186: альтернативная стойка (ополченец — щит перед собой). Свои стойка, шаг и реакция на удар,
-## ход короче; атака выводит из стойки. {"title", "enter", "idle", "walk", "hurt", "exit", "move"}
+## ход короче; после атаки возвращается в стойку (стойку снимает только кнопка). {"title", "enter", "idle", "walk", "hurt", "exit", "move"}
 var stance := {}
 var in_stance := false
 var _base := {}  # обычные стойка, шаг, реакция и бег на время стойки
@@ -748,7 +748,6 @@ func melee_point(_from: Vector3) -> Vector3:
 
 ## Кулак не достаёт до выбранной части цели — выпад вперёд, затем возврат.
 func strike(target: Creature, _distance: float, overlap: float, collateral: Array[Creature] = []) -> void:
-	set_stance(false, false)  # 186: атака опускает щит, удар идёт из стойки со щитом
 	var contact := target.melee_point(position)
 	face(contact)
 	target.face_foe(position)
diff --git a/game/scenes/militiaman2_config.gd b/game/scenes/militiaman2_config.gd
index 11095a5..5b2d51c 100644
--- a/game/scenes/militiaman2_config.gd
+++ b/game/scenes/militiaman2_config.gd
@@ -18,7 +18,7 @@ const UNIT := {
 	# Отдельные топор и щит (weapon_grip.gd); пока заглушки, потом модели Tripo.
 	"props": [{"hand": "Right", "mode": "fist", "shape": "axe", "length": 0.42, "grip_at": 0.12},
 		{"hand": "Left", "mode": "forearm", "shape": "shield", "length": 0.34, "width": 0.26}],
-	# 186: стойка со щитом — кнопка альтернативы; ход вдвое меньше; удар принимает в щит; атака выводит из стойки.
+	# 186: стойка со щитом — кнопка альтернативы; ход вдвое меньше; удар принимает в щит; после атаки снова в стойке.
 	"stance": {"title": "Щит перед собой", "enter": "shield_up", "idle": "shield_idle", "walk": "shield_walk",
 		"hurt": "shield_hurt", "exit": "shield_down", "move": 0.5},
 }
```

## 2026-11-07 — 187: защита щитом

```diff
diff --git a/game/scenes/militiaman2_config.gd b/game/scenes/militiaman2_config.gd
index 5b2d51c..57dce83 100644
--- a/game/scenes/militiaman2_config.gd
+++ b/game/scenes/militiaman2_config.gd
@@ -7,10 +7,12 @@ const UNIT := {
 	"name": "Ополченец (манекен)", "icon": "res://assets/creatures/militiaman/icon.png",
 	"scene": "res://assets/mannequin/xbot.glb",
 	"extra": [ANIMS + "idle.glb", ANIMS + "walk.glb", ANIMS + "run.glb", ANIMS + "attack.glb", ANIMS + "hurt.glb",
-		ANIMS + "defend.glb", ANIMS + "fall.glb", ANIMS + "fidget.glb", ANIMS + "shield_up.glb", ANIMS + "shield_idle.glb",
+		ANIMS + "fall.glb", ANIMS + "fidget.glb", ANIMS + "shield_up.glb", ANIMS + "shield_idle.glb",
 		ANIMS + "shield_walk.glb", ANIMS + "shield_hurt.glb", ANIMS + "shield_down.glb"],
 	"attack": "attack", "attack_from": 0.0, "hurt": "hurt", "hurt_len": 0.0, "idle": "idle", "run": "run",
-	"defend": "defend", "defend_from": 0.0, "defend_len": 0.0, "defend_lead": 0.3,
+	# 187: защита — удар в поднятый щит (тот же клип, что в стойке), а не «закрывается руками»;
+	# старт на 0,35 с раньше удара: щит поднимается к попаданию.
+	"defend": "shield_hurt", "defend_from": 0.0, "defend_len": 0.0, "defend_lead": 0.35,
 	"fidget": "fidget", "fidget_on_hover": true,
 	"size": 1.8, "walk_speed": 0.97,  # замер стопы в клипе шага (unarmed walk forward)
 	"reach": 1.0,  # кисть 0,28 + топор ≈ 0,67 при росте 1,8 (×рост/1,9); без него удар заходит в цель на 0,7 м
```
Удалён anims/defend.glb; в clips.json у a_block_react снят alias.

## 2026-11-07 — 188: защита в стойке без клипа

```diff
diff --git a/game/scenes/creature.gd b/game/scenes/creature.gd
index 9c211d0..4f22d57 100644
--- a/game/scenes/creature.gd
+++ b/game/scenes/creature.gd
@@ -410,7 +410,7 @@ func set_stance(on: bool, animate := true) -> void:
 		if stance.has("walk") and anim.has_animation(stance.walk):
 			_swap(library, "walk", anim.get_animation(stance.walk))
 		hurt_anim = stance.get("hurt", hurt_anim)
-		defend_anim = stance.get("hurt", defend_anim)  # и «Защита» в стойке — удар в щит, щит не опускается
+		defend_anim = stance.get("defend", stance.get("hurt", defend_anim))  # «Защита» в стойке; "" — без клипа, только толчок
 		run_ratio = 0.0  # со щитом перед собой не бегает
 	else:
 		_swap(library, "idle", _base.idle)
diff --git a/game/scenes/militiaman2_config.gd b/game/scenes/militiaman2_config.gd
index 57dce83..846121e 100644
--- a/game/scenes/militiaman2_config.gd
+++ b/game/scenes/militiaman2_config.gd
@@ -22,5 +22,6 @@ const UNIT := {
 		{"hand": "Left", "mode": "forearm", "shape": "shield", "length": 0.34, "width": 0.26}],
 	# 186: стойка со щитом — кнопка альтернативы; ход вдвое меньше; удар принимает в щит; после атаки снова в стойке.
 	"stance": {"title": "Щит перед собой", "enter": "shield_up", "idle": "shield_idle", "walk": "shield_walk",
-		"hurt": "shield_hurt", "exit": "shield_down", "move": 0.5},
+		"hurt": "shield_hurt", "exit": "shield_down", "move": 0.5,
+		"defend": ""},  # «Защита» в стойке: щит неподвижен, от удара только толчок назад — не тот же клип, что получение удара
 }
```

## 2026-11-07 — 188: защита в стойке — присед за щит

clips.json: s_cblock2 → shield_brace (и ещё 6 приседаний набора как кандидаты); militiaman2_config.gd: stance.defend = shield_brace, extra + shield_brace.glb.

## 2026-11-07 — 189: щит не залезает в соседа

weapon_grip.gd — forward_limit, _bake_limit, _solve, _item_points; militiaman2_config.gd — forward_limit 0,35; clips.json — шаг со щитом без arms_from; check_clips.gd — E15 (боком), E16 (за свой гекс); ERRORS.md — E15, E16, M13–M15.

Замеры вынос щита (м): стойка 0,64, подъём 0,64, удар в щит 0,64, присед 0,73 (было 0,84), реакция 0,72 (0,77), атака 0,66 (0,81).

## 2026-11-07 — 190: витрина ударов; квадраты по ширине окна

mannequin_search.gd — столбцы по ширине окна (_fit_cells), перенос длинных подписей; candidates.json — 4 удара (all_cells хранит прежний список).

## 2026-11-07 — 191: свой удар в стойке

creature.gd — set_stance меняет attack_anim/attack_from/impact, reach из записи; militiaman2_config.gd — stance.attack; clips.json — s_attack4 → shield_attack; creature_gallery_page.gd — клетки «Стойка: атака/защита».
Проверка: обычная — attack 0,72 с; со щитом — shield_attack 0,42 с, стойка сохраняется; снова обычная — attack.

## 2026-11-07 — 192: рука со щитом в реакции и смерти

militiaman2_config.gd — SHIELD_ARM, hurt_calm/fall_calm 0,25; creature_test.gd, battle_test.gd, creature_gallery_page.gd — scale_bones("fall", fall_calm).

## 2026-11-07 — 193: щит в атаке

weapon_grip.gd — общий для существа выбор сторон поворота, TURN_MAX_ATTACK 90°, _front/_solve, полушарие кватерниона; creature.gd — scale_bones(reference), configure_stance калмит удар стойки; arenas/gallery — attack_calm; militiaman2_config.gd — forward_limit 0,29, attack_calm.
Замер (overlap.gd): стойка −0,49/−0,31; атака −0,24/−0,20; стойка со щитом −0,28/−0,11; атака со щитом −0,02/−0,01.

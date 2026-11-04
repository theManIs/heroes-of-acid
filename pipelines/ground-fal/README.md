# Пайплайн: текстура земли, fal (основной путь проверен на задаче 100)

Ключ: `FAL_KEY` в `.env`, значение нигде не печатать. Запуск из корня проекта.

1. Сгенерировать: `python3 -I pipelines/ground-fal/generate.py <name> 0 "<запрос>" gpt`. Модель `fal-ai/gpt-image-1.5`, 1024×1024, около 40 секунд. Результат: `ground/generations/<name>/`.
2. Сделать бесшовной: `godot --headless --path game --script "$PWD/pipelines/ground-fal/make_tile.gd" -- "$PWD/ground/generations/<name>/raw.png" "$PWD/game/assets/ground/<файл>.png"`.
3. `godot --headless --path game --import`, в `.import` поставить `mipmaps/generate=true`, импортировать ещё раз.
4. Проверять только на кадре из игры, под камерой боя. Цвет подбирать через `GRASS_TINT`, не перегенерацией.

**Запрос, который сработал (`grass-v5`):** см. `ground/generations/grass-v5/request.json`.

**Что не сработало:** `fal-ai/flux/dev` (параметр `gpt` не указан). Запрос про игровую текстуру вид сверху дал готовую карту с рамкой из кустов и цветами, запрос про сплошную траву дал фото поля в перспективе. ChatGPT в браузере приложения не залогинен, поэтому модель OpenAI вызывается через fal.

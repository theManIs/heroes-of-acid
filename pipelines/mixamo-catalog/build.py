"""Проверить сохранённые страницы Mixamo и собрать читаемую таблицу."""
import json
from collections import Counter
from pathlib import Path
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "catalogs" / "mixamo"


def build():
    data = json.loads((OUT / "catalog.json").read_text(encoding="utf-8"))
    pages = data["pages"]
    if [p["page"] for p in pages] != list(range(1, len(pages) + 1)):
        raise ValueError("Пропущены или повторены номера страниц")
    rows = []
    signatures = set()
    for page in pages:
        entries = page["entries"]
        expected = min(96, data["total"] - (page["page"] - 1) * 96)
        if len(entries) != expected:
            raise ValueError(f"Неполная страница {page['page']}")
        signature = json.dumps(entries, sort_keys=True)
        if signature in signatures:
            raise ValueError("Повторена целая страница")
        signatures.add(signature)
        for index, row in enumerate(entries, 1):
            if not row["name"] or not row["description"] or row["type"] not in ("animation", "pack"):
                raise ValueError("Неполная запись")
            rows.append({**row, "key": f"p{page['page']:02d}-{index:02d}"})
    if len(rows) != data["total"]:
        raise ValueError("Количество не совпадает со счётчиком сайта")
    counts = Counter(row["type"] for row in rows)
    escape = lambda value: value.replace("|", "\\|").replace("\n", " ")
    lines = ["# Каталог Mixamo", "",
             f"Сбор (UTC): {data['collected_at']}. Всего {len(rows)} записей: "
             f"{counts['animation']} анимаций, {counts['pack']} пакетов.", "",
             "Имена и описания взяты из каталога. Совпадающие названия сохранены отдельно. "
             "Ключ — позиция в этом снимке, не идентификатор Mixamo. Ссылка открывает поиск по имени.", "",
             "| Ключ | Тип | Название | Описание Mixamo |", "|---|---|---|---|"]
    for row in sorted(rows, key=lambda r: (r["name"].casefold(), r["key"])):
        url = "https://www.mixamo.com/#/?page=1&query=" + quote(row["name"], safe="")
        kind = "пакет" if row["type"] == "pack" else "анимация"
        lines.append(f"| {row['key']} | {kind} | [{escape(row['name'])}]({url}) | {escape(row['description'])} |")
    (OUT / "catalog.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(pages)} страниц, {len(rows)} записей; {dict(counts)}")


if __name__ == "__main__":
    build()

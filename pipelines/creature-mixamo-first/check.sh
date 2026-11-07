#!/bin/bash
# Полная автопроверка существа (задача 182): клипы и кости (check_clips.gd) + сцены без окна на ошибки в логе.
# Запуск из корня репозитория: pipelines/creature-mixamo-first/check.sh <id>
# Код выхода 0 — провалов нет. «ВНИМАНИЕ» — смотреть кадр по ERRORS.md, решать по смыслу.
set -u
ID="$1"
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STATUS=0
LOG="$(mktemp -d)"

echo "### клипы и кости"
"$GODOT" --headless --path "$ROOT/game" --script "$ROOT/pipelines/creature-mixamo-first/check_clips.gd" -- --id="$ID" >"$LOG/clips.txt" 2>&1 || STATUS=1
grep -E "^(ОК|ПРОВАЛ|ВНИМАНИЕ|==)|SCRIPT ERROR" "$LOG/clips.txt"

# E14: сцены с существом без ошибок в логе (169 — «Animation not found», 55 — SCRIPT ERROR молча ломает клик).
echo "### сцены"
"$GODOT" --headless --path "$ROOT/game" res://scenes/creature_test.tscn --quit-after 600 -- --creature="$ID" >"$LOG/test.txt" 2>&1
"$GODOT" --headless --path "$ROOT/game" res://scenes/battle_test.tscn --quit-after 3000 -- --auto >"$LOG/battle.txt" 2>&1
"$GODOT" --headless --path "$ROOT/game" res://scenes/showcase.tscn --quit-after 300 -- --creature="$ID" >"$LOG/showcase.txt" 2>&1
for f in test battle showcase; do
  ERR=$(grep -E "SCRIPT ERROR|ERROR:|Animation not found|couldn't resolve track" "$LOG/$f.txt" | grep -v -E "PagedAllocator|Pages in use" | sort | uniq -c | head -5)
  if [ -n "$ERR" ]; then echo "ПРОВАЛ  [E14] $f: ошибки в логе"; echo "$ERR"; STATUS=1; else echo "ОК  [E14] $f: лог чистый"; fi
done
rm -rf "$LOG"
exit $STATUS

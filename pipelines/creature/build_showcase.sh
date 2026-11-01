#!/bin/sh
# Уровни детализации для витрины: game/assets/showcase/<id>-<треугольников>.glb, без текстур.
set -e
OUT=game/assets/showcase
mkdir -p "$OUT"
make() {
	src=$1; id=$2; shift 2
	for n in "$@"; do
		blender -b --python pipelines/creature/decimate.py -- "$src" "$OUT/$id-$n.glb" "$n" noimages | grep DECIMATED
	done
}
make creatures/flesh-golem/tripo/flesh-golem.glb flesh-golem 1436104 200000 50000 20000 10000 5000 2500
make creatures/militiaman/tripo/multiview/rigged.glb militiaman 19816 10000 5000 2500 1250

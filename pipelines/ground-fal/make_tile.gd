extends SceneTree
## Делает картинку бесшовной: у краёв подмешивает её же, сдвинутую на половину, там края уже непрерывны.
## Запуск из корня проекта: godot --headless --path game --script ../pipelines/ground-fal/make_tile.gd -- <вход.png> <выход.png>

const BAND := 0.2  # доля стороны, на которой идёт смешивание


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var src := Image.load_from_file(args[0])
	src.convert(Image.FORMAT_RGB8)
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var edge := minf(minf(x, w - 1 - x) / float(w), minf(y, h - 1 - y) / float(h))
			var k := smoothstep(0.0, BAND, edge)
			out.set_pixel(x, y, src.get_pixel((x + w / 2) % w, (y + h / 2) % h).lerp(src.get_pixel(x, y), k))
	out.save_png(args[1])
	quit()

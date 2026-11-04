extends SceneTree
## Rysuje ikonę aplikacji 512x512 (Google Play) i zapisuje assets/icon.png oraz build/store/icon_512.png.
## Uruchomienie (wymaga ekranu, np. xvfb-run):
##   godot --path . --resolution 512x512 --script res://tools/store_icon.gd

class Icon extends Node2D:
	func _draw() -> void:
		var S := 512.0
		# Tło: pełny kwadrat z gradientem stali (Google Play sam zaokrągla rogi; bez przezroczystości).
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(S, 0), Vector2(S, S), Vector2(0, S)]),
			PackedColorArray([Color("#33506b"), Color("#2c4560"), Color("#141d26"), Color("#18232e")]))
		# Szyna suwnicy.
		draw_rect(Rect2(36, 92, S - 72, 30), Color("#8d98a6"))
		for x in range(40, int(S) - 40, 38):
			draw_line(Vector2(x, 92), Vector2(x + 20, 122), Color("#5d6773"), 5)
		# Wózek robota.
		var cart := Rect2(186, 70, 140, 66)
		var c := StyleBoxFlat.new()
		c.bg_color = Color("#ff9f1c")
		c.border_color = Color("#b86a00")
		c.set_border_width_all(5)
		c.set_corner_radius_all(16)
		draw_style_box(c, cart)
		for k in 4:
			draw_circle(Vector2(222 + k * 23, 118), 6, Color("#3ddc84"))
		draw_rect(Rect2(246, 44, 20, 26), Color("#ff5a36"))
		# Kolumna i chwytak.
		draw_rect(Rect2(244, 136, 24, 80), Color("#a9b3bf"))
		draw_rect(Rect2(170, 210, 172, 22), Color("#e08900"))
		draw_rect(Rect2(170, 226, 16, 58), Color("#3a414b"))
		draw_rect(Rect2(326, 226, 16, 58), Color("#3a414b"))
		# Trzymany karton (czerwony, symbol koła).
		_box(Rect2(190, 232, 132, 92), Color("#e6394b"), 0)
		# Paleta z kartonami na dole.
		_box(Rect2(70, 372, 132, 76), Color("#3cb44b"), 1)
		_box(Rect2(310, 372, 132, 76), Color("#4363d8"), 2)
		draw_rect(Rect2(52, 448, 408, 18), Color("#b07a43"))
		for b in 4:
			draw_rect(Rect2(62 + b * 122, 466, 34, 14), Color("#6e4a2a"))

	func _box(r: Rect2, col: Color, icon: int) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.border_color = col.darkened(0.45)
		sb.set_border_width_all(6)
		sb.set_corner_radius_all(12)
		sb.shadow_color = Color(0, 0, 0, 0.4)
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 6)
		draw_style_box(sb, r)
		draw_rect(Rect2(r.get_center().x - 9, r.position.y + 6, 18, r.size.y - 12), col.lightened(0.25))
		var ctr := r.get_center()
		var s := 24.0
		match icon:
			0:
				draw_circle(ctr, s, Color.WHITE)
			1:
				draw_rect(Rect2(ctr - Vector2(s, s) * 0.85, Vector2(s, s) * 1.7), Color.WHITE)
			2:
				draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -s), ctr + Vector2(s, s * 0.8), ctr + Vector2(-s, s * 0.8)]), Color.WHITE)


func _init() -> void:
	await process_frame
	root.transparent_bg = false
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED  # bez skalowania projektu 720x1280
	get_root().size = Vector2i(512, 512)
	var n := Icon.new()
	root.add_child(n)
	for i in 4:
		await process_frame
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)  # bez kanału przezroczystości
	img.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	img.save_png("res://assets/icon.png")
	DirAccess.make_dir_recursive_absolute("res://build/store")
	img.save_png("res://build/store/icon_512.png")
	print("zapisano ikonę")
	quit()

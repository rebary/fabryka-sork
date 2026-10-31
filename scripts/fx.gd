extends Node2D
## Efekty wizualne: iskry, konfetti i unoszące się napisy (rysowane nad planszą).

var parts: Array = []  # {p, v, life, max, col, size, spin}
var texts: Array = []  # {text, p, life, max, col}


func burst(pos: Vector2, col: Color, count: int = 22) -> void:
	for i in count:
		var dir := Vector2.from_angle(randf() * TAU)
		parts.append({"p": pos, "v": dir * randf_range(120, 380) + Vector2(0, -120), "life": 0.0,
			"max": randf_range(0.4, 0.8), "col": col.lightened(randf() * 0.4), "size": randf_range(3, 7)})


func confetti(width: float) -> void:
	var cols := [Color("#ffd23f"), Color("#3ddc84"), Color("#4fd1ff"), Color("#ff6b6b"), Color("#c77dff")]
	for i in 90:
		parts.append({"p": Vector2(randf() * width, randf_range(-60, -10)), "v": Vector2(randf_range(-60, 60), randf_range(150, 380)),
			"life": 0.0, "max": randf_range(1.6, 2.6), "col": cols[i % cols.size()], "size": randf_range(6, 11), "spin": true})


func float_text(text: String, pos: Vector2, col: Color) -> void:
	texts.append({"text": text, "p": pos, "life": 0.0, "max": 1.4, "col": col})


func _process(delta: float) -> void:
	if parts.is_empty() and texts.is_empty():
		return
	for q in parts:
		q["life"] += delta
		if not q.has("spin"):
			q["v"].y += 700 * delta  # grawitacja iskier
		q["p"] += q["v"] * delta
	parts = parts.filter(func(q): return q["life"] < q["max"])
	for q in texts:
		q["life"] += delta
		q["p"].y -= 50 * delta
	texts = texts.filter(func(q): return q["life"] < q["max"])
	queue_redraw()


func _draw() -> void:
	for q in parts:
		var a: float = 1.0 - q["life"] / q["max"]
		var c: Color = q["col"]
		c.a = a
		var s: float = q["size"]
		if q.has("spin"):
			var w := s * absf(sin(q["life"] * 9.0 + q["p"].x))
			draw_rect(Rect2(q["p"] - Vector2(w, s) / 2.0, Vector2(maxf(w, 1.0), s)), c)
		else:
			draw_rect(Rect2(q["p"] - Vector2(s, s) / 2.0, Vector2(s, s)), c)
	var font := ThemeDB.fallback_font
	for q in texts:
		var c: Color = q["col"]
		c.a = clampf(2.0 * (1.0 - q["life"] / q["max"]), 0.0, 1.0)
		draw_string_outline(font, q["p"] - Vector2(200, 0), q["text"], HORIZONTAL_ALIGNMENT_CENTER, 400, 34, 8, Color(0, 0, 0, c.a))
		draw_string(font, q["p"] - Vector2(200, 0), q["text"], HORIZONTAL_ALIGNMENT_CENTER, 400, 34, c)

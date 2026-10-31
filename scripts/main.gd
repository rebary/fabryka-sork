extends Node2D
## Główna scena gry: rysowanie hali, palet, paczek i robota-suwnicy,
## obsługa dotyku, cofania, podpowiedzi, wygranej i zapisu postępu.
## Grafika jest rysowana kodem (_draw), więc prototyp nie potrzebuje plików graficznych.

const SAVE_PATH := "user://save.cfg"
const ANIM_TIME := 0.45  # czas ruchu robota w sekundach
const HINT_TIME := 2.5

# Kolory produktów + kształt ikony (kształt pomaga osobom z zaburzeniami widzenia barw).
const PRODUCT_COLORS := [
	Color("#e6194b"), Color("#3cb44b"), Color("#4363d8"), Color("#f58231"),
	Color("#911eb4"), Color("#29b6c8"), Color("#f032e6"), Color("#9bbf2a"),
]
const COL_BG := Color("#262b33")
const COL_FLOOR := Color("#2f353f")
const COL_RAIL := Color("#6b7380")
const COL_RACK := Color("#4a515c")
const COL_PALLET := Color("#9a6b3f")
const COL_PALLET_DARK := Color("#6e4a2a")
const COL_SELECT := Color("#4fd1ff")
const COL_HINT := Color("#ffd23f")
const COL_DONE := Color("#3ddc84")
const COL_ROBOT := Color("#ff9f1c")

var level := 1
var board: Board
var start_board: Board
var history: Array = []  # lista ruchów [from, to, n] do cofania
var selected := -1
var anim := {}  # trwająca animacja ruchu (pusty słownik = brak)
var hint := {}  # podświetlona podpowiedź
var gripper_x := 0.0

# Układ ekranu (przeliczany przy zmianie rozmiaru okna).
var stack_rects: Array = []
var box_size := Vector2.ZERO
var pallet_h := 18.0
var rail_y := 190.0

# Interfejs.
var lbl_title: Label
var lbl_moves: Label
var lbl_msg: Label
var win_layer: ColorRect
var lbl_win: Label
var msg_timer := 0.0


func _ready() -> void:
	_load_progress()
	_build_ui()
	get_viewport().size_changed.connect(_on_resize)
	_start_level(level)


# ---------------------------------------------------------------- poziomy

func _start_level(n: int) -> void:
	level = n
	board = LevelGenerator.generate(level)
	start_board = board.clone()
	_reset_state()


func _restart_level() -> void:
	if not anim.is_empty():
		return
	board = start_board.clone()
	_reset_state()


func _reset_state() -> void:
	history.clear()
	selected = -1
	anim = {}
	hint = {}
	win_layer.visible = false
	_layout()
	gripper_x = get_viewport_rect().size.x / 2.0
	_show_msg("")
	_update_hud()
	queue_redraw()


# ---------------------------------------------------------------- ruchy

func _try_move(from: int, to: int) -> bool:
	var n := board.move_count(from, to)
	if n == 0:
		return false
	var src_size: int = board.stacks[from].size()
	var dst_size: int = board.stacks[to].size()
	var items: Array = board.stacks[from].slice(src_size - n)
	var src_top := _box_rect(from, src_size - 1).position
	var dst_top := _box_rect(to, dst_size + n - 1).position
	board.apply_move(from, to)
	history.append([from, to, n])
	anim = {"to": to, "n": n, "items": items, "t": 0.0, "s": src_top, "d": dst_top}
	_update_hud()
	return true


func _after_move() -> void:
	if board.is_solved():
		_on_level_complete()
	elif not board.has_any_move():
		_show_msg("Brak ruchów – cofnij albo zacznij od nowa", 4.0)


func _on_level_complete() -> void:
	_save_progress(level + 1)
	lbl_win.text = "Zlecenie %d wykonane!\nRuchy: %d" % [level, history.size()]
	win_layer.visible = true


func _on_undo() -> void:
	if not anim.is_empty() or history.is_empty():
		return
	var m: Array = history.pop_back()
	board.undo_move(m[0], m[1], m[2])
	selected = -1
	hint = {}
	_show_msg("")
	_update_hud()
	queue_redraw()


func _on_hint() -> void:
	if not anim.is_empty():
		return
	hint = {}
	var r := Solver.solve(board)
	if r.ok and not r.moves.is_empty():
		hint = {"from": r.moves[0][0], "to": r.moves[0][1], "time": HINT_TIME}
		selected = -1
		_show_msg("Podpowiedź: przenieś z palety Z na paletę NA", HINT_TIME)
	else:
		var k := _undos_needed()
		if k > 0:
			_show_msg("Ślepy zaułek – cofnij %d %s" % [k, _plural_moves(k)], 4.0)
		else:
			_show_msg("Ślepy zaułek – zacznij od nowa", 4.0)
	queue_redraw()


## Ile ruchów trzeba cofnąć, żeby znowu istniało rozwiązanie (0 = nie znaleziono).
func _undos_needed() -> int:
	var b := board.clone()
	for k in range(history.size()):
		var m: Array = history[history.size() - 1 - k]
		b.undo_move(m[0], m[1], m[2])
		if Solver.solve(b).ok:
			return k + 1
	return 0


func _plural_moves(k: int) -> String:
	if k == 1:
		return "ruch"
	if k % 10 >= 2 and k % 10 <= 4 and (k % 100 < 10 or k % 100 >= 20):
		return "ruchy"
	return "ruchów"


func _on_next() -> void:
	_start_level(level + 1)


# ---------------------------------------------------------------- dotyk

func _unhandled_input(event: InputEvent) -> void:
	# Godot domyślnie zamienia dotyk na kliknięcie myszą, więc to działa na telefonie i PC.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tap(event.position)


func _on_tap(pos: Vector2) -> void:
	if not anim.is_empty() or win_layer.visible:
		return
	var i := _stack_at(pos)
	hint = {}
	if i < 0:
		selected = -1
	elif selected == -1:
		selected = i if _can_pick(i) else -1
	elif selected == i:
		selected = -1
	elif _try_move(selected, i):
		selected = -1
	else:
		selected = i if _can_pick(i) else -1
	queue_redraw()


func _can_pick(i: int) -> bool:
	return not board.stacks[i].is_empty() and not board.is_stack_complete(i)


func _stack_at(pos: Vector2) -> int:
	for i in stack_rects.size():
		var r: Rect2 = stack_rects[i]
		if r.grow_individual(12, 40, 12, 12).has_point(pos):
			return i
	return -1


# ---------------------------------------------------------------- pętla

func _process(delta: float) -> void:
	var redraw := false
	if not anim.is_empty():
		anim["t"] += delta / ANIM_TIME
		if anim["t"] >= 1.0:
			gripper_x = anim["d"].x + box_size.x / 2.0
			anim = {}
			_after_move()
		redraw = true
	if not hint.is_empty():
		hint["time"] -= delta
		if hint["time"] <= 0.0:
			hint = {}
		redraw = true
	if msg_timer > 0.0:
		msg_timer -= delta
		if msg_timer <= 0.0:
			lbl_msg.text = ""
	if redraw:
		queue_redraw()


# ---------------------------------------------------------------- układ ekranu

func _on_resize() -> void:
	_layout()
	queue_redraw()


func _layout() -> void:
	if board == null:
		return
	var vs := get_viewport_rect().size
	var n := board.stacks.size()
	var rows := 1 if n <= 5 else 2
	var per_row := ceili(n / float(rows))
	var margin := 24.0
	var gap := 18.0
	var col_w := minf(130.0, (vs.x - 2.0 * margin - gap * (per_row - 1)) / per_row)
	var top := 240.0
	var bottom := vs.y - 170.0
	var row_gap := 60.0
	var avail_h := (bottom - top - row_gap * (rows - 1)) / rows - pallet_h
	var box_h := minf(col_w * 0.62, avail_h / board.capacity)
	box_size = Vector2(col_w, box_h)
	var stack_h := box_h * board.capacity + pallet_h
	var total_h := stack_h * rows + row_gap * (rows - 1)
	var y0 := top + (bottom - top - total_h) / 2.0
	rail_y = top - 50.0
	stack_rects.clear()
	for i in n:
		var r := floori(i / float(per_row))
		var c := i % per_row
		var in_row := per_row if r < rows - 1 else n - per_row * (rows - 1)
		var row_w := in_row * col_w + (in_row - 1) * gap
		var x0 := (vs.x - row_w) / 2.0
		stack_rects.append(Rect2(x0 + c * (col_w + gap), y0 + r * (stack_h + row_gap), col_w, stack_h))


## Prostokąt k-tej paczki (0 = najniżej) na palecie i.
func _box_rect(i: int, k: int) -> Rect2:
	var r: Rect2 = stack_rects[i]
	var y := r.position.y + (board.capacity - 1 - k) * box_size.y
	return Rect2(Vector2(r.position.x, y), box_size)


# ---------------------------------------------------------------- rysowanie

func _draw() -> void:
	if board == null:
		return
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), COL_BG)
	draw_rect(Rect2(0, vs.y - 160, vs.x, 160), COL_FLOOR)
	# Szyna suwnicy.
	draw_rect(Rect2(0, rail_y - 8, vs.x, 16), COL_RAIL)
	for x in range(0, int(vs.x), 40):
		draw_line(Vector2(x, rail_y - 8), Vector2(x + 20, rail_y + 8), COL_RACK, 3)
	for i in board.stacks.size():
		_draw_stack(i)
	_draw_robot()


func _draw_stack(i: int) -> void:
	var r: Rect2 = stack_rects[i]
	var stack: Array = board.stacks[i]
	var complete := board.is_stack_complete(i)
	# Tło stanowiska i słupki regału.
	var slot := Rect2(r.position, Vector2(r.size.x, r.size.y - pallet_h))
	draw_rect(slot, Color(COL_DONE, 0.12) if complete else Color(1, 1, 1, 0.04))
	draw_rect(Rect2(r.position.x - 6, r.position.y, 5, r.size.y), COL_RACK)
	draw_rect(Rect2(r.end.x + 1, r.position.y, 5, r.size.y), COL_RACK)
	# Paczki (podczas animacji ukrywamy te, które dopiero "lecą" na tę paletę).
	var hidden: int = anim["n"] if not anim.is_empty() and anim["to"] == i else 0
	var visible_count := stack.size() - hidden
	var lift_from := stack.size() - board.top_run(i) if selected == i else 9999
	for k in visible_count:
		var br := _box_rect(i, k)
		if k >= lift_from:
			br.position.y -= 22.0
		_draw_box(br, stack[k])
	# Paleta.
	var pr := Rect2(r.position.x - 6, r.end.y - pallet_h, r.size.x + 12, pallet_h)
	draw_rect(pr, COL_PALLET)
	for b in 3:
		var bx := pr.position.x + 4 + b * (pr.size.x - 28) / 2.0
		draw_rect(Rect2(bx, pr.position.y + pallet_h * 0.55, 20, pallet_h * 0.45), COL_PALLET_DARK)
	# Obramowania: zaznaczenie, podpowiedź, skompletowane.
	if selected == i:
		draw_rect(r.grow(8), COL_SELECT, false, 4.0)
	if not hint.is_empty() and (hint["from"] == i or hint["to"] == i):
		var a := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 120.0)
		draw_rect(r.grow(10), Color(COL_HINT, 0.18 * a))
		draw_rect(r.grow(10), Color(COL_HINT, a), false, 6.0)
		var label := "Z" if hint["from"] == i else "NA"
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(r.position.x, r.position.y - 14), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28, COL_HINT)
	if complete:
		var c := Vector2(r.get_center().x, r.position.y - 22)
		draw_circle(c, 16, COL_DONE)
		draw_polyline(PackedVector2Array([c + Vector2(-8, 0), c + Vector2(-2, 6), c + Vector2(8, -6)]), Color.WHITE, 4.0)


func _draw_box(rect: Rect2, type: int) -> void:
	var col: Color = PRODUCT_COLORS[type % PRODUCT_COLORS.size()]
	var inner := rect.grow(-3)
	draw_rect(inner, col.darkened(0.35))
	draw_rect(inner.grow(-3), col)
	# Taśma na kartonie.
	draw_rect(Rect2(inner.get_center().x - 4, inner.position.y + 3, 8, inner.size.y - 6), col.lightened(0.25))
	_draw_icon(type, inner.get_center(), minf(inner.size.x, inner.size.y) * 0.26, Color.WHITE)


func _draw_icon(type: int, c: Vector2, s: float, col: Color) -> void:
	match type % 8:
		0:
			draw_circle(c, s, col)
		1:
			draw_rect(Rect2(c - Vector2(s, s) * 0.85, Vector2(s, s) * 1.7), col)
		2:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, s * 0.8), c + Vector2(-s, s * 0.8)]), col)
		3:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), col)
		4:
			draw_rect(Rect2(c.x - s, c.y - s * 0.3, s * 2, s * 0.6), col)
			draw_rect(Rect2(c.x - s * 0.3, c.y - s, s * 0.6, s * 2), col)
		5:
			draw_arc(c, s * 0.75, 0, TAU, 24, col, s * 0.45)
		6:
			var pts := PackedVector2Array()
			for k in 6:
				pts.append(c + Vector2.from_angle(TAU * k / 6.0) * s)
			draw_colored_polygon(pts, col)
		7:
			draw_rect(Rect2(c.x - s, c.y - s * 0.8, s * 2, s * 0.5), col)
			draw_rect(Rect2(c.x - s, c.y + s * 0.3, s * 2, s * 0.5), col)


## Robot-suwnica: wózek na szynie, linka i chwytak. Podczas ruchu niesie paczki.
func _draw_robot() -> void:
	var grip_pos: Vector2  # środek górnej krawędzi trzymanej paczki / chwytaka
	if anim.is_empty():
		grip_pos = Vector2(gripper_x, rail_y + 40)
	else:
		var top_left := _anim_path(anim["s"], anim["d"], anim["t"])
		var n: int = anim["n"]
		for j in n:
			# Paczka j (0 = najniżej) leży pod górną o (n - 1 - j) wysokości.
			var p := top_left + Vector2(0, (n - 1 - j) * box_size.y)
			_draw_box(Rect2(p, box_size), anim["items"][j])
		grip_pos = top_left + Vector2(box_size.x / 2.0, 0)
	var w := box_size.x * 0.7
	# Wózek na szynie.
	draw_rect(Rect2(grip_pos.x - 30, rail_y - 14, 60, 28), COL_ROBOT)
	draw_circle(Vector2(grip_pos.x - 18, rail_y), 6, COL_RACK)
	draw_circle(Vector2(grip_pos.x + 18, rail_y), 6, COL_RACK)
	# Linka/kolumna i głowica chwytaka.
	draw_rect(Rect2(grip_pos.x - 4, rail_y + 14, 8, grip_pos.y - rail_y - 26), COL_RAIL)
	draw_rect(Rect2(grip_pos.x - w / 2.0, grip_pos.y - 14, w, 12), COL_ROBOT)
	draw_rect(Rect2(grip_pos.x - w / 2.0, grip_pos.y - 4, 6, 18), COL_ROBOT.darkened(0.3))
	draw_rect(Rect2(grip_pos.x + w / 2.0 - 6, grip_pos.y - 4, 6, 18), COL_ROBOT.darkened(0.3))


## Tor paczki: podniesienie -> przejazd pod szyną -> opuszczenie.
func _anim_path(s: Vector2, d: Vector2, t: float) -> Vector2:
	var lift_y := rail_y + 40
	if t < 0.3:
		return s.lerp(Vector2(s.x, lift_y), smoothstep(0.0, 1.0, t / 0.3))
	if t < 0.7:
		return Vector2(s.x, lift_y).lerp(Vector2(d.x, lift_y), smoothstep(0.0, 1.0, (t - 0.3) / 0.4))
	return Vector2(d.x, lift_y).lerp(d, smoothstep(0.0, 1.0, minf((t - 0.7) / 0.3, 1.0)))


# ---------------------------------------------------------------- interfejs

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	lbl_title = _make_label(44)
	lbl_title.position = Vector2(24, 24)
	root.add_child(lbl_title)
	lbl_moves = _make_label(30)
	lbl_moves.position = Vector2(24, 86)
	root.add_child(lbl_moves)
	lbl_msg = _make_label(24)
	lbl_msg.add_theme_color_override("font_color", COL_HINT)
	lbl_msg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	lbl_msg.offset_top = 132
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(lbl_msg)

	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 24
	bar.offset_right = -24
	bar.offset_top = -140
	bar.offset_bottom = -36
	bar.add_theme_constant_override("separation", 16)
	root.add_child(bar)
	bar.add_child(_make_button("Cofnij", _on_undo))
	bar.add_child(_make_button("Od nowa", _restart_level))
	bar.add_child(_make_button("Podpowiedź", _on_hint))

	win_layer = ColorRect.new()
	win_layer.color = Color(0, 0, 0, 0.75)
	win_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	win_layer.visible = false
	root.add_child(win_layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_layer.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 40)
	center.add_child(vbox)
	lbl_win = _make_label(44)
	lbl_win.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_win)
	var next := _make_button("Następne zlecenie", _on_next)
	next.custom_minimum_size = Vector2(420, 110)
	vbox.add_child(next)


func _make_label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	return l


func _make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 100)  # duży cel dotyku
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(cb)
	return b


func _update_hud() -> void:
	lbl_title.text = "Zlecenie %d" % level
	lbl_moves.text = "Ruchy: %d" % history.size()


func _show_msg(text: String, seconds: float = 0.0) -> void:
	lbl_msg.text = text
	msg_timer = seconds


# ---------------------------------------------------------------- zapis

func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		level = maxi(1, int(cfg.get_value("progress", "level", 1)))


func _save_progress(next_level: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "level", next_level)
	cfg.save(SAVE_PATH)

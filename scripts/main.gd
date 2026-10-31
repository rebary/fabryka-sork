extends Node2D
## Główna scena gry: rysowanie hali, palet, paczek i robota-suwnicy, obsługa dotyku,
## ruchów, cofania, podpowiedzi, utrudnień, wygranej. Grafika jest rysowana kodem.
## Interfejs (przyciski, okna) jest w hud.gd, efekty cząsteczkowe w fx.gd.

const TRAVEL_SPEED := 2200.0  # px/s - dojazd robota nad paletę źródłową
const CARRY_TIME := 0.62  # s - chwyt, przeniesienie i odstawienie
const HINT_TIME := 3.0
## Szansa na znalezienie darmowej podpowiedzi przy podnoszeniu paczki (0.003 = 0,3%).
## Najwyżej raz na zlecenie i tylko przy "nowych" ruchach (cofanie nie pomaga).
const FIND_HINT_CHANCE := 0.003

const PRODUCT_COLORS := [
	Color("#e6394b"), Color("#3cb44b"), Color("#4363d8"), Color("#f58231"),
	Color("#9b3fc4"), Color("#29b6c8"), Color("#e8559c"), Color("#9bbf2a"),
]
const COL_WALL_TOP := Color("#1b2027")
const COL_WALL_BOTTOM := Color("#2c333d")
const COL_FLOOR := Color("#252a31")
const COL_RAIL := Color("#6b7380")
const COL_STEEL := Color("#4a525e")
const COL_STEEL_DARK := Color("#343a43")
const COL_PALLET := Color("#a8743f")
const COL_PALLET_DARK := Color("#6e4a2a")
const COL_SELECT := Color("#4fd1ff")
const COL_HINT := Color("#ffd23f")
const COL_DONE := Color("#3ddc84")
const COL_ROBOT := Color("#ff9f1c")

const INTROS := {
	"folia": ["Nowość: folia stretch", "Niektóre paczki są owinięte folią – nie widać, co jest w środku.\nPaczka odsłoni się, gdy znajdzie się na górze palety."],
	"limit": ["Nowość: limit ruchów", "Zlecenie trzeba wykonać w podanej liczbie ruchów.\nCofnięcie zwraca ruch, więc zawsze możesz spróbować inaczej."],
	"cap5": ["Nowość: palety na 5", "Na tych paletach mieszczą się 5 paczek.\nPaleta jest gotowa, gdy ma 5 paczek tego samego produktu."],
}

var hud: CanvasLayer
var fx: Node2D

# Stan zlecenia.
var level := 0
var board: Board
var start_board: Board
var params := {}
var move_limit := 0
var history: Array = []  # zapisy ruchów z Board.do_move
var selected := -1
var anim := {}
var hint := {}
var found_hint_this_level := false
var max_progress := 0  # najdłuższa historia w tym zleceniu (ochrona przed "farmieniem")
var gripper_x := 360.0
var bounce := {}  # paleta -> czas efektu odstawienia
var shake := {}  # paleta -> czas potrząśnięcia (ruch niedozwolony)
var time := 0.0

# Generowanie zleceń w tle.
var gen_thread: Thread
var gen_level := 0
var pending_level := 0
var cache := {}

# Układ ekranu.
var stack_rects: Array = []
var box_size := Vector2.ZERO
var pallet_h := 18.0
var rail_y := 196.0
var box_styles := {}


func _ready() -> void:
	randomize()
	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	fx = preload("res://scripts/fx.gd").new()
	add_child(fx)
	hud.undo_pressed.connect(_on_undo)
	hud.restart_pressed.connect(_restart_level)
	hud.hint_pressed.connect(_on_hint)
	hud.next_pressed.connect(func(): _request_level(level + 1))
	hud.sound_toggled.connect(_on_sound_toggled)
	hud.buy_pressed.connect(_on_buy)
	hud.ad_pressed.connect(_on_ad)
	Store.purchase_finished.connect(_on_purchase_finished)
	Store.ad_finished.connect(_on_ad_finished)
	get_viewport().size_changed.connect(_on_resize)
	_request_level(Save.level)


func _exit_tree() -> void:
	if gen_thread != null:
		gen_thread.wait_to_finish()


# ---------------------------------------------------------------- zlecenia

func _request_level(n: int) -> void:
	hud.hide_win()
	pending_level = n
	if not cache.has(n):
		hud.show_busy("Przygotowuję zlecenie %d…" % n)
	_pump_generation()


## Pilnuje wątku generującego: odbiera gotowe zlecenia i od razu liczy następne.
func _pump_generation() -> void:
	if gen_thread != null and not gen_thread.is_alive():
		cache[gen_level] = gen_thread.wait_to_finish()
		gen_thread = null
	if pending_level > 0 and cache.has(pending_level):
		var n := pending_level
		pending_level = 0
		hud.hide_busy()
		_apply_level(cache[n])
		cache.erase(n)
	if gen_thread == null:
		var want := pending_level if pending_level > 0 else level + 1
		if want > 0 and not cache.has(want):
			gen_level = want
			gen_thread = Thread.new()
			gen_thread.start(_generate_job.bind(want))


func _generate_job(n: int) -> Dictionary:
	return LevelGenerator.generate(n)


func _apply_level(g: Dictionary) -> void:
	params = g["params"]
	level = params["level"]
	board = g["board"]
	start_board = board.clone()
	move_limit = g["move_limit"]
	found_hint_this_level = false
	max_progress = 0
	_reset_state()
	var intro: String = params["intro"]
	if intro != "" and not Save.seen_intros.has(intro):
		Save.seen_intros.append(intro)
		Save.save()
		hud.show_intro(INTROS[intro][0], INTROS[intro][1])


func _restart_level() -> void:
	if not anim.is_empty() or board == null:
		return
	board = start_board.clone()
	_reset_state()


func _reset_state() -> void:
	history.clear()
	selected = -1
	anim = {}
	hint = {}
	bounce.clear()
	shake.clear()
	_layout()
	gripper_x = get_viewport_rect().size.x / 2.0
	_update_hud()
	queue_redraw()


func _limit_left() -> int:
	return move_limit - history.size() if move_limit > 0 else 9999


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
	var rec := board.do_move(from, to)
	history.append(rec)
	var new_ground := history.size() > max_progress
	max_progress = maxi(max_progress, history.size())
	var travel := absf(src_top.x + box_size.x / 2.0 - gripper_x) / TRAVEL_SPEED + 0.05
	anim = {"from": from, "to": to, "n": n, "items": items, "reveals": rec[3], "s": src_top, "d": dst_top,
		"gx0": gripper_x, "travel": travel, "e": 0.0, "picked": false, "dropped": false,
		"revealed": false, "lucky": new_ground and not found_hint_this_level and randf() < FIND_HINT_CHANCE}
	_update_hud()
	return true


func _on_anim_event(u: float) -> void:
	if not anim["picked"] and u >= 0.15:
		anim["picked"] = true
		Sfx.play("pick", randf_range(0.95, 1.05))
		if anim["lucky"]:
			found_hint_this_level = true
			Save.wallet.add(1)
			Save.save()
			fx.burst(Vector2(anim["s"].x + box_size.x / 2.0, anim["s"].y), COL_HINT, 30)
			fx.float_text("Znaleziona podpowiedź! +1", anim["s"] + Vector2(box_size.x / 2.0, -20), COL_HINT)
			Sfx.play("reward")
			_update_hud()
	if not anim["revealed"] and u >= 0.4:
		anim["revealed"] = true
		for r in anim["reveals"]:
			if r[0] == anim["from"]:
				var br := _box_rect(r[0], r[1])
				fx.burst(br.get_center(), Color(0.9, 0.95, 1.0), 14)
	if not anim["dropped"] and u >= 0.9:
		anim["dropped"] = true
		Sfx.play("drop", randf_range(0.9, 1.1))
		bounce[anim["to"]] = 1.0


func _after_move(to: int) -> void:
	if board.is_stack_complete(to):
		var r: Rect2 = stack_rects[to]
		fx.burst(Vector2(r.get_center().x, r.position.y), COL_DONE, 34)
		Sfx.play("complete")
	if board.is_solved():
		_on_level_complete()
	elif not board.has_any_move():
		hud.show_msg("Brak ruchów – cofnij albo zacznij od nowa", 4.0)
	elif _limit_left() <= 0:
		hud.show_msg("Limit ruchów wyczerpany – cofnij ruch albo zacznij od nowa", 4.0)


func _on_level_complete() -> void:
	var bonus: int = Save.wallet.on_level_completed()
	Save.level = level + 1
	Save.save()
	_update_hud()
	fx.confetti(get_viewport_rect().size.x)
	Sfx.play("win")
	var text := "Zlecenie %d wykonane!\nRuchy: %d" % [level, history.size()]
	if bonus > 0:
		text += "\n\n+1 podpowiedź za 3 zlecenia"
	await get_tree().create_timer(0.6).timeout
	hud.show_win(text)


func _on_undo() -> void:
	if not anim.is_empty() or history.is_empty() or hud.is_modal_open():
		return
	board.undo(history.pop_back())
	selected = -1
	hint = {}
	_update_hud()
	queue_redraw()


# ---------------------------------------------------------------- podpowiedzi i sklep

func _on_hint() -> void:
	if not anim.is_empty() or board == null or hud.is_modal_open():
		return
	if not Save.wallet.can_use():
		hud.show_shop()
		return
	hint = {}
	selected = -1
	var r := Solver.solve(board, 40000, _limit_left() if move_limit > 0 else -1)
	if r.ok and not r.moves.is_empty():
		Save.wallet.use()
		hint = {"from": r.moves[0][0], "to": r.moves[0][1], "time": HINT_TIME}
		Sfx.play("hint")
		hud.show_msg("Przenieś z palety Z na paletę NA", HINT_TIME)
	else:
		var k := _undos_needed()
		if k > 0:
			Save.wallet.use()
			Sfx.play("hint")
			hud.show_msg("Ślepy zaułek – cofnij %d %s" % [k, _plural_moves(k)], 4.0)
		else:
			hud.show_msg("Najlepiej zacząć od nowa (podpowiedź nie została zużyta)", 4.0)
	Save.save()
	_update_hud()
	queue_redraw()


## Ile ruchów trzeba cofnąć, żeby znowu istniało rozwiązanie (0 = nie znaleziono).
func _undos_needed() -> int:
	var b := board.clone()
	for k in history.size():
		b.undo(history[history.size() - 1 - k])
		var used := history.size() - k - 1
		var depth := move_limit - used if move_limit > 0 else -1
		if Solver.solve(b, 15000, depth).ok:
			return k + 1
	return 0


func _plural_moves(k: int) -> String:
	if k == 1:
		return "ruch"
	if k % 10 >= 2 and k % 10 <= 4 and (k % 100 < 10 or k % 100 >= 20):
		return "ruchy"
	return "ruchów"


func _on_buy(product_id: String) -> void:
	hud.show_busy("Przetwarzanie zakupu (test)…")
	Store.purchase(product_id)


func _on_purchase_finished(product_id: String, success: bool) -> void:
	hud.hide_busy()
	if not success:
		hud.show_msg("Zakup nie został zrealizowany", 3.0)
		return
	var n: int = Store.PRODUCTS[product_id]["hints"]
	Save.wallet.add(n)
	Save.save()
	Sfx.play("reward")
	hud.show_msg("Dodano %d podpowiedzi" % n, 3.0)
	_update_hud()


func _on_ad() -> void:
	hud.show_busy("Reklama (tryb testowy)…")
	Store.show_rewarded_ad()


func _on_ad_finished(rewarded: bool) -> void:
	hud.hide_busy()
	if rewarded:
		Save.wallet.add(1)
		Save.save()
		Sfx.play("reward")
		hud.show_msg("+1 podpowiedź", 3.0)
		_update_hud()


func _on_sound_toggled() -> void:
	Save.sound_on = not Save.sound_on
	Save.save()
	_update_hud()


func _update_hud() -> void:
	if board == null:
		return
	hud.set_status(level, history.size(), move_limit, params.get("mods", []), Save.wallet.hints, Save.sound_on)


# ---------------------------------------------------------------- dotyk

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tap(event.position)


func _on_tap(pos: Vector2) -> void:
	if board == null or not anim.is_empty() or hud.is_modal_open():
		return
	var i := _stack_at(pos)
	hint = {}
	if i < 0:
		selected = -1
	elif selected == -1:
		if _can_pick(i):
			selected = i
			Sfx.play("click")
		elif not board.stacks[i].is_empty() and not board.is_stack_complete(i):
			_reject(i)
	elif selected == i:
		selected = -1
	elif _limit_left() <= 0 and board.move_count(selected, i) > 0:
		_reject(i)
		hud.show_msg("Limit ruchów wyczerpany – cofnij ruch albo zacznij od nowa", 3.0)
	elif _try_move(selected, i):
		selected = -1
	elif _can_pick(i):
		selected = i
		Sfx.play("click")
	else:
		_reject(i)
		selected = -1
	queue_redraw()


func _reject(i: int) -> void:
	shake[i] = 0.3
	Sfx.play("error")


func _can_pick(i: int) -> bool:
	var s: Array = board.stacks[i]
	return not s.is_empty() and s.back() >= 0 and not board.is_stack_complete(i)


func _stack_at(pos: Vector2) -> int:
	for i in stack_rects.size():
		var r: Rect2 = stack_rects[i]
		if r.grow_individual(12, 40, 12, 12).has_point(pos):
			return i
	return -1


# ---------------------------------------------------------------- pętla

func _process(delta: float) -> void:
	time += delta
	_pump_generation()
	if not anim.is_empty():
		anim["e"] += delta
		var u: float = (anim["e"] - anim["travel"]) / CARRY_TIME
		if u >= 0.0:
			_on_anim_event(u)
		if u >= 1.0:
			var to: int = anim["to"]
			gripper_x = anim["d"].x + box_size.x / 2.0
			anim = {}
			_after_move(to)
	_decay(bounce, delta * 3.0)
	_decay(shake, delta)
	if not hint.is_empty():
		hint["time"] -= delta
		if hint["time"] <= 0.0:
			hint = {}
	queue_redraw()  # tło (taśmociąg, lampki) jest animowane cały czas


func _decay(d: Dictionary, amount: float) -> void:
	for k in d.keys():
		d[k] -= amount
		if d[k] <= 0.0:
			d.erase(k)


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
	var margin := 26.0
	var gap := 20.0
	var col_w := minf(128.0, (vs.x - 2.0 * margin - gap * (per_row - 1)) / per_row)
	var top := 250.0
	var bottom := vs.y - 200.0
	var row_gap := 64.0
	var avail_h := (bottom - top - row_gap * (rows - 1)) / rows - pallet_h
	var box_h := minf(col_w * 0.62, avail_h / board.capacity)
	box_size = Vector2(col_w, box_h)
	var stack_h := box_h * board.capacity + pallet_h
	var total_h := stack_h * rows + row_gap * (rows - 1)
	var y0 := top + (bottom - top - total_h) / 2.0
	rail_y = 196.0
	stack_rects.clear()
	for i in n:
		var r := floori(i / float(per_row))
		var c := i % per_row
		var in_row := per_row if r < rows - 1 else n - per_row * (rows - 1)
		var row_w := in_row * col_w + (in_row - 1) * gap
		var x0 := (vs.x - row_w) / 2.0
		stack_rects.append(Rect2(x0 + c * (col_w + gap), y0 + r * (stack_h + row_gap), col_w, stack_h))


func _box_rect(i: int, k: int) -> Rect2:
	var r: Rect2 = stack_rects[i]
	var y := r.position.y + (board.capacity - 1 - k) * box_size.y
	return Rect2(Vector2(r.position.x, y), box_size)


# ---------------------------------------------------------------- rysowanie

func _draw() -> void:
	var vs := get_viewport_rect().size
	_draw_hall(vs)
	if board == null:
		return
	for i in board.stacks.size():
		_draw_stack(i)
	_draw_robot()


func _draw_hall(vs: Vector2) -> void:
	# Ściana hali z gradientem i panelami.
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(0, vs.y)]),
		PackedColorArray([COL_WALL_TOP, COL_WALL_TOP, COL_WALL_BOTTOM, COL_WALL_BOTTOM]))
	for x in range(60, int(vs.x), 120):
		draw_line(Vector2(x, 0), Vector2(x, vs.y - 190), Color(1, 1, 1, 0.025), 2)
	# Posadzka z pasem ostrzegawczym.
	var floor_y := vs.y - 190.0
	draw_rect(Rect2(0, floor_y, vs.x, vs.y - floor_y), COL_FLOOR)
	for x in range(-20, int(vs.x) + 20, 28):
		draw_colored_polygon(PackedVector2Array([Vector2(x, floor_y), Vector2(x + 14, floor_y), Vector2(x + 4, floor_y + 10), Vector2(x - 10, floor_y + 10)]), Color("#e0b000"))
	# Taśmociąg w tle z przejeżdżającymi kartonami.
	var belt_y := floor_y + 22.0
	draw_rect(Rect2(0, belt_y, vs.x, 18), COL_STEEL_DARK)
	var off := fmod(time * 60.0, 24.0)
	for x in range(-24, int(vs.x) + 24, 24):
		draw_line(Vector2(x + off, belt_y + 3), Vector2(x + off + 8, belt_y + 15), COL_STEEL, 2)
	for k in 3:
		var bx := fmod(time * 60.0 + k * vs.x / 3.0, vs.x + 80.0) - 40.0
		var col: Color = PRODUCT_COLORS[(k * 3 + 1) % PRODUCT_COLORS.size()].darkened(0.35)
		draw_rect(Rect2(bx, belt_y - 20, 36, 22), col)
		draw_rect(Rect2(bx + 15, belt_y - 20, 6, 22), col.lightened(0.2))
	# Szyna suwnicy z kratownicą.
	draw_rect(Rect2(0, rail_y - 10, vs.x, 20), COL_RAIL)
	draw_rect(Rect2(0, rail_y + 6, vs.x, 4), COL_STEEL_DARK)
	for x in range(0, int(vs.x), 36):
		draw_line(Vector2(x, rail_y - 10), Vector2(x + 18, rail_y + 6), COL_STEEL, 3)


func _draw_stack(i: int) -> void:
	var r: Rect2 = stack_rects[i]
	var stack: Array = board.stacks[i]
	var complete := board.is_stack_complete(i)
	var sx: float = sin(time * 60.0) * 7.0 * (shake.get(i, 0.0) / 0.3)
	var by := sin(bounce.get(i, 0.0) * PI) * 5.0
	var base := r.position + Vector2(sx, 0)
	# Regał: tło, słupki z otworami, belka górna z lampką.
	var slot := Rect2(base, Vector2(r.size.x, r.size.y - pallet_h))
	draw_rect(slot, Color(COL_DONE, 0.10) if complete else Color(1, 1, 1, 0.035))
	for px in [base.x - 8, base.x + r.size.x + 2]:
		draw_rect(Rect2(px, base.y - 14, 6, r.size.y + 14), COL_STEEL)
		for hy in range(int(base.y), int(base.y + r.size.y), 18):
			draw_rect(Rect2(px + 2, hy, 2, 6), COL_STEEL_DARK)
	draw_rect(Rect2(base.x - 8, base.y - 18, r.size.x + 16, 6), COL_STEEL)
	var lamp := Vector2(base.x + r.size.x / 2.0, base.y - 15)
	var lamp_col := Color("#3a4048")
	if complete:
		lamp_col = COL_DONE
	elif not hint.is_empty() and (hint["from"] == i or hint["to"] == i):
		lamp_col = COL_HINT.lerp(Color("#3a4048"), 0.5 + 0.5 * sin(time * 12.0))
	if lamp_col != Color("#3a4048"):
		draw_circle(lamp, 16, Color(lamp_col, 0.25))
	if complete:
		# Gotowa paleta: zielona lampka ze znaczkiem.
		draw_circle(lamp, 12, COL_DONE)
		draw_polyline(PackedVector2Array([lamp + Vector2(-6, 0), lamp + Vector2(-2, 5), lamp + Vector2(6, -5)]), Color.WHITE, 3.0)
	else:
		draw_circle(lamp, 6, lamp_col)
	# Paczki.
	var hidden: int = anim["n"] if not anim.is_empty() and anim["to"] == i else 0
	var visible_count := stack.size() - hidden
	var lift_from := stack.size() - board.top_run(i) if selected == i else 9999
	for k in visible_count:
		var br := _box_rect(i, k)
		br.position.x += sx
		br.position.y += by * (k + 1) / float(maxi(1, visible_count))
		if k >= lift_from:
			br.position.y -= 24.0 + sin(time * 7.0) * 3.0
		_draw_box(br, stack[k], _wrapped_during_anim(i, k))
	# Paleta drewniana.
	var pr := Rect2(base.x - 6, base.y + r.size.y - pallet_h, r.size.x + 12, pallet_h)
	draw_rect(Rect2(pr.position, Vector2(pr.size.x, pallet_h * 0.4)), COL_PALLET)
	for b in 3:
		var bx := pr.position.x + 2 + b * (pr.size.x - 24) / 2.0
		draw_rect(Rect2(bx, pr.position.y + pallet_h * 0.4, 20, pallet_h * 0.6), COL_PALLET_DARK)
	draw_rect(Rect2(pr.position.x, pr.end.y - 3, pr.size.x, 3), COL_PALLET)
	# Zaznaczenie i podpowiedź.
	if selected == i:
		draw_rect(Rect2(base, r.size).grow(8), COL_SELECT, false, 4.0)
	if not hint.is_empty() and (hint["from"] == i or hint["to"] == i):
		var a := 0.7 + 0.3 * sin(time * 8.0)
		var hr := Rect2(base, r.size).grow(10)
		draw_rect(hr, Color(COL_HINT, 0.15 * a))
		draw_rect(hr, Color(COL_HINT, a), false, 6.0)
		var label := "Z" if hint["from"] == i else "NA"
		draw_string(ThemeDB.fallback_font, Vector2(base.x, base.y - 30), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, COL_HINT)


## Odsłonięta paczka na palecie źródłowej pozostaje "w folii", dopóki robot nie podniesie ładunku.
func _wrapped_during_anim(i: int, k: int) -> bool:
	if anim.is_empty() or anim["revealed"]:
		return false
	for r in anim["reveals"]:
		if r[0] == i and r[1] == k and i == anim["from"]:
			return true
	return false


func _box_style(type: int) -> StyleBoxFlat:
	if not box_styles.has(type):
		var col: Color = PRODUCT_COLORS[type % PRODUCT_COLORS.size()]
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.border_color = col.darkened(0.4)
		sb.set_border_width_all(3)
		sb.border_width_bottom = 5
		sb.set_corner_radius_all(7)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 4
		sb.shadow_offset = Vector2(0, 3)
		box_styles[type] = sb
	return box_styles[type]


func _draw_box(rect: Rect2, v: int, force_wrapped: bool = false) -> void:
	var inner := rect.grow(-3)
	if v < 0 or force_wrapped:
		_draw_wrapped(inner)
		return
	var col: Color = PRODUCT_COLORS[v % PRODUCT_COLORS.size()]
	draw_style_box(_box_style(v), inner)
	draw_rect(Rect2(inner.position + Vector2(6, 4), Vector2(inner.size.x - 12, 4)), col.lightened(0.3))
	draw_rect(Rect2(inner.get_center().x - 4, inner.position.y + 3, 8, inner.size.y - 8), col.lightened(0.18))
	_draw_icon(v, inner.get_center(), minf(inner.size.x, inner.size.y) * 0.25, Color.WHITE)


func _draw_wrapped(inner: Rect2) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#b9c4d0")
	sb.border_color = Color("#8592a0")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(9)
	draw_style_box(sb, inner)
	for k in 3:
		var y := inner.position.y + inner.size.y * (0.25 + 0.25 * k)
		draw_line(Vector2(inner.position.x + 6, y), Vector2(inner.end.x - 6, y + 4), Color(1, 1, 1, 0.55), 2)
	draw_string(ThemeDB.fallback_font, Vector2(inner.position.x, inner.get_center().y + 12), "?", HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 34, Color("#55606d"))


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


## Stan robota w danej chwili: pozycja chwytaka, pozycja ładunku, czy chwytak zaciśnięty.
func _robot_state() -> Dictionary:
	var idle_y := rail_y + 44.0
	if anim.is_empty():
		return {"grip": Vector2(gripper_x, idle_y + sin(time * 2.0) * 2.0), "load": null, "closed": false}
	var s: Vector2 = anim["s"]
	var d: Vector2 = anim["d"]
	var half := box_size.x / 2.0
	var e: float = anim["e"]
	if e < anim["travel"]:
		var k := smoothstep(0.0, 1.0, e / anim["travel"])
		return {"grip": Vector2(lerpf(anim["gx0"], s.x + half, k), idle_y), "load": s, "closed": false}
	var u: float = (e - anim["travel"]) / CARRY_TIME
	var lift_y := rail_y + 44.0
	var load: Vector2
	var closed := true
	var grip_y := -1.0
	if u < 0.15:
		load = s
		closed = false
		grip_y = lerpf(idle_y, s.y, smoothstep(0.0, 1.0, u / 0.15))
	elif u < 0.4:
		load = s.lerp(Vector2(s.x, lift_y), smoothstep(0.0, 1.0, (u - 0.15) / 0.25))
	elif u < 0.7:
		load = Vector2(s.x, lift_y).lerp(Vector2(d.x, lift_y), smoothstep(0.0, 1.0, (u - 0.4) / 0.3))
	elif u < 0.9:
		load = Vector2(d.x, lift_y).lerp(d, smoothstep(0.0, 1.0, (u - 0.7) / 0.2))
	else:
		load = d
		closed = false
		grip_y = lerpf(d.y, idle_y, smoothstep(0.0, 1.0, minf((u - 0.9) / 0.1, 1.0)))
	if grip_y < 0.0:
		grip_y = load.y
	return {"grip": Vector2(load.x + half, grip_y), "load": load, "closed": closed}


func _draw_robot() -> void:
	var st := _robot_state()
	var grip: Vector2 = st["grip"]
	# Ładunek (przenoszone paczki).
	if st["load"] != null:
		var top_left: Vector2 = st["load"]
		var n: int = anim["n"]
		for j in n:
			var p := top_left + Vector2(0, (n - 1 - j) * box_size.y)
			_draw_box(Rect2(p, box_size), anim["items"][j])
	var w := box_size.x
	# Wózek na szynie.
	var cart := Rect2(grip.x - 36, rail_y - 18, 72, 34)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_ROBOT
	sb.border_color = COL_ROBOT.darkened(0.35)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	draw_style_box(sb, cart)
	draw_rect(Rect2(cart.position.x + 8, cart.position.y + 8, cart.size.x - 16, 6), Color(0, 0, 0, 0.25))
	for wx in [-22, 0, 22]:
		draw_circle(Vector2(grip.x + wx, rail_y - 12), 5, COL_STEEL_DARK)
	# Lampa ostrzegawcza (miga w ruchu).
	var lamp_on := not anim.is_empty() and fmod(time, 0.4) < 0.2
	draw_rect(Rect2(grip.x - 7, rail_y - 30, 14, 12), Color("#ff5a36") if lamp_on else Color("#7a3a2a"))
	if lamp_on:
		draw_circle(Vector2(grip.x, rail_y - 24), 16, Color(1, 0.35, 0.2, 0.25))
	# Kolumna teleskopowa.
	var head_y := grip.y - 16.0
	draw_rect(Rect2(grip.x - 9, rail_y + 16, 18, 26), COL_STEEL)
	draw_rect(Rect2(grip.x - 5, rail_y + 16, 10, maxf(0.0, head_y - rail_y - 16)), COL_RAIL)
	# Głowica i szczęki chwytaka.
	var open := 0.0 if st["closed"] else 10.0
	draw_rect(Rect2(grip.x - w / 2.0 - 10 - open, head_y, w + 20 + open * 2.0, 12), COL_ROBOT.darkened(0.15))
	var jaw_h := 22.0 if st["closed"] else 16.0
	for side in [-1.0, 1.0]:
		var jx: float = grip.x + side * (w / 2.0 + 4 + open) - 4
		draw_rect(Rect2(jx, head_y + 8, 8, jaw_h), COL_STEEL_DARK)

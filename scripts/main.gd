extends Node2D
## Główna scena gry. Dwa tryby:
##  - "campaign": zlecenia - gracz steruje robotem ruch po ruchu;
##  - "program":  programowanie robota - gracz układa listę kroków, START uruchamia program.
## Tu jest rysowanie hali (z ozdobami), palet, paczek i robota, dotyk, animacje
## i logika rozgrywki. Interfejs (przyciski, okna) jest w hud.gd, efekty w fx.gd.

const TRAVEL_SPEED := 2200.0  # px/s - dojazd robota nad paletę źródłową
const CARRY_TIME := 0.62  # s - chwyt, przeniesienie i odstawienie
const HINT_TIME := 3.0
## Szansa na znalezienie darmowej podpowiedzi przy podnoszeniu paczki (0.003 = 0,3%).
## Najwyżej raz na zlecenie i tylko przy "nowych" ruchach (cofanie nie pomaga).
const FIND_HINT_CHANCE := 0.003
const PROGRAM_STEP_PAUSE := 0.18

const PRODUCT_COLORS := [
	Color("#e6394b"), Color("#3cb44b"), Color("#4363d8"), Color("#f58231"),
	Color("#9b3fc4"), Color("#29b6c8"), Color("#e8559c"), Color("#9bbf2a"),
]
const COL_RAIL := Color("#6b7380")
const COL_STEEL := Color("#4a525e")
const COL_STEEL_DARK := Color("#343a43")
const COL_PALLET := Color("#a8743f")
const COL_PALLET_DARK := Color("#6e4a2a")
const COL_SELECT := Color("#4fd1ff")
const COL_HINT := Color("#ffd23f")
const COL_DONE := Color("#3ddc84")
const COL_FAULT := Color("#ff4d4d")
const LAMP_OFF := Color("#3a4048")

const INTROS := {
	"folia": ["Nowość: folia stretch", "Niektóre paczki są owinięte folią – nie widać, co jest w środku.\nPaczka odsłoni się, gdy znajdzie się na górze palety."],
	"limit": ["Nowość: limit ruchów", "Zlecenie trzeba wykonać w podanej liczbie ruchów.\nCofnięcie zwraca ruch, więc zawsze możesz spróbować inaczej."],
	"cap5": ["Nowość: palety na 5", "Na tych paletach mieści się 5 paczek.\nPaleta jest gotowa, gdy ma 5 paczek tego samego produktu."],
	"chwytaki": ["Nowość: wymiana chwytaków", "Próżnia bierze cały ciąg paczek – ale tylko, gdy zmieści się w całości.\nWidły biorą do 2 paczek, szczęki 1.\nZmiana chwytaka kosztuje jeden ruch."],
	"program": ["Programowanie robota", "Ułóż program: dotknij palety źródłowej, potem docelowej – to jeden krok.\nPodczas programowania robot stoi, więc przewiduj skutki kroków w głowie.\nSTART uruchamia program. Błędny krok zatrzymuje robota."],
}
const TOOL_NAMES := {-1: "próżnię", 2: "widły", 1: "szczęki"}

var hud: CanvasLayer
var fx: Node2D
var mode := ""  # "", "campaign" albo "program"

# Wspólny stan planszy.
var board: Board
var start_board: Board
var selected := -1
var anim := {}
var hint := {}
var gripper_x := 360.0
var bounce := {}
var shake := {}
var time := 0.0
var fault_time := 0.0

# Kampania.
var level := 0
var params := {}
var move_limit := 0
var par := 0
var history: Array = []
var found_hint_this_level := false
var max_progress := 0

# Tryb programowania.
var prog := {}  # {"number", "optimal", "max_steps"}
var program: Array = []
var prog_state := "edit"  # edit / run / fault / fail / done
var prog_index := -1
var prog_error := -1
var prog_wait := 0.0

# Generowanie poziomów w tle (dla numerów spoza gotowego pliku danych).
var gen_thread: Thread
var gen_key := ""
var pending_key := ""
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
	hud.next_pressed.connect(_on_next)
	hud.sound_toggled.connect(_on_sound_toggled)
	hud.buy_pressed.connect(_on_buy)
	hud.ad_pressed.connect(_on_ad)
	hud.level_chosen.connect(_on_level_chosen)
	hud.menu_pressed.connect(func(): hud.show_menu())
	hud.campaign_pressed.connect(_start_campaign)
	hud.program_mode_pressed.connect(_start_program_mode)
	hud.decor_chosen.connect(_on_decor_chosen)
	hud.tool_pressed.connect(_on_tool)
	hud.prog_delete_pressed.connect(_on_prog_delete)
	hud.prog_clear_pressed.connect(_on_prog_clear)
	hud.prog_start_pressed.connect(_on_prog_start)
	Store.purchase_finished.connect(_on_purchase_finished)
	Store.ad_finished.connect(_on_ad_finished)
	get_viewport().size_changed.connect(_on_resize)
	hud.show_menu()


func _exit_tree() -> void:
	if gen_thread != null:
		gen_thread.wait_to_finish()


# ---------------------------------------------------------------- tryby i ładowanie

func _start_campaign() -> void:
	hud.hide_menu()
	if mode == "campaign" and board != null and level == Save.level:
		return  # kontynuacja bieżącego zlecenia
	mode = "campaign"
	hud.set_mode(mode)
	_request("c", Save.level)


func _start_program_mode() -> void:
	hud.hide_menu()
	if mode == "program" and board != null and prog.get("number", 0) == Save.program:
		return
	mode = "program"
	hud.set_mode(mode)
	_request("p", Save.program)
	if not Save.seen_intros.has("program"):
		Save.seen_intros.append("program")
		Save.save()
		hud.show_intro(INTROS["program"][0], INTROS["program"][1])


func _on_next() -> void:
	hud.hide_win()
	if mode == "program":
		_request("p", prog["number"] + 1)
	else:
		_request("c", level + 1)


## Wczytuje zlecenie ("c") albo program ("p"): z gotowego pliku albo generuje w tle.
func _request(kind: String, n: int) -> void:
	hud.hide_win()
	var key := "%s%d" % [kind, n]
	if not cache.has(key):
		if kind == "c" and Levels.has_level(n):
			cache[key] = Levels.get_level(n)
		elif kind == "p" and Levels.has_program(n):
			cache[key] = Levels.get_program(n)
	pending_key = key
	if not cache.has(key):
		hud.show_busy("Przygotowuję %s %d…" % ["program" if kind == "p" else "zlecenie", n])
	_pump_generation()


func _pump_generation() -> void:
	if gen_thread != null and not gen_thread.is_alive():
		cache[gen_key] = gen_thread.wait_to_finish()
		gen_thread = null
	if pending_key != "" and cache.has(pending_key):
		var key := pending_key
		pending_key = ""
		hud.hide_busy()
		var data: Dictionary = cache[key]
		cache.erase(key)
		if key.begins_with("p"):
			_apply_program(data)
		else:
			_apply_level(data)
	if gen_thread == null:
		var want := pending_key
		if want == "" and mode == "campaign" and level > 0 and not Levels.has_level(level + 1):
			want = "c%d" % (level + 1)
		if want != "" and not cache.has(want):
			gen_key = want
			gen_thread = Thread.new()
			gen_thread.start(_generate_job.bind(want))


func _generate_job(key: String) -> Dictionary:
	var n := int(key.substr(1))
	return LevelGenerator.generate_program(n) if key.begins_with("p") else LevelGenerator.generate(n)


func _apply_level(g: Dictionary) -> void:
	mode = "campaign"
	hud.set_mode(mode)
	params = g["params"]
	level = params["level"]
	board = g["board"]
	start_board = board.clone()
	move_limit = g["move_limit"]
	par = g["par"]
	found_hint_this_level = false
	max_progress = 0
	_reset_state()
	var intro: String = params["intro"]
	if intro != "" and not Save.seen_intros.has(intro):
		Save.seen_intros.append(intro)
		Save.save()
		hud.show_intro(INTROS[intro][0], INTROS[intro][1])


func _apply_program(g: Dictionary) -> void:
	mode = "program"
	hud.set_mode(mode)
	prog = {"number": g["number"], "optimal": g["optimal"], "max_steps": g["max_steps"]}
	board = g["board"]
	start_board = board.clone()
	program.clear()
	prog_state = "edit"
	prog_index = -1
	prog_error = -1
	_reset_state()


func _restart_level() -> void:
	if not anim.is_empty() or board == null or hud.is_modal_open():
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
	fault_time = 0.0
	_layout()
	gripper_x = get_viewport_rect().size.x / 2.0
	_update_hud()
	queue_redraw()


func _limit_left() -> int:
	return move_limit - history.size() if move_limit > 0 else 9999


# ---------------------------------------------------------------- ruchy (wspólne)

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
	var lucky := false
	if mode == "campaign":
		history.append(rec)
		var new_ground := history.size() > max_progress
		max_progress = maxi(max_progress, history.size())
		lucky = new_ground and not found_hint_this_level and randf() < FIND_HINT_CHANCE
	var travel := absf(src_top.x + box_size.x / 2.0 - gripper_x) / TRAVEL_SPEED + 0.05
	anim = {"from": from, "to": to, "n": n, "items": items, "reveals": rec[3], "s": src_top, "d": dst_top,
		"gx0": gripper_x, "travel": travel, "e": 0.0, "picked": false, "dropped": false,
		"revealed": false, "lucky": lucky}
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
				fx.burst(_box_rect(r[0], r[1]).get_center(), Color(0.9, 0.95, 1.0), 14)
	if not anim["dropped"] and u >= 0.9:
		anim["dropped"] = true
		Sfx.play("drop", randf_range(0.9, 1.1))
		bounce[anim["to"]] = 1.0


func _after_move(to: int) -> void:
	if board.is_stack_complete(to):
		var r: Rect2 = stack_rects[to]
		fx.burst(Vector2(r.get_center().x, r.position.y), COL_DONE, 34)
		Sfx.play("complete")
	if mode != "campaign":
		return
	if board.is_solved():
		_on_level_complete()
	elif not board.has_any_move():
		hud.show_msg("Brak ruchów – cofnij albo zacznij od nowa", 4.0)
	elif _limit_left() <= 0:
		hud.show_msg("Limit ruchów wyczerpany – cofnij ruch albo zacznij od nowa", 4.0)


func _on_level_complete() -> void:
	var moves := history.size()
	var stars := LevelGenerator.stars_for(moves, par)
	var new_stars: int = Save.record_stars(false, level, stars)
	var bonus: int = Save.wallet.on_level_completed()
	Save.level = level + 1
	Save.save()
	_update_hud()
	fx.confetti(get_viewport_rect().size.x)
	Sfx.play("win")
	var text := "Zlecenie %d wykonane!\nRuchy: %d (na 3 gwiazdki: %d)" % [level, moves, par]
	if new_stars > 0:
		text += "\n+%d %s do rozbudowy hali" % [new_stars, _plural(new_stars, "gwiazdka", "gwiazdki", "gwiazdek")]
	if bonus > 0:
		text += "\n+1 podpowiedź za 3 zlecenia"
	await get_tree().create_timer(0.6).timeout
	hud.show_win(text, stars, "Następne zlecenie")


func _on_undo() -> void:
	if mode != "campaign" or not anim.is_empty() or history.is_empty() or hud.is_modal_open():
		return
	board.undo(history.pop_back())
	selected = -1
	hint = {}
	_update_hud()
	queue_redraw()


func _on_tool(cap: int) -> void:
	if mode != "campaign" or not anim.is_empty() or hud.is_modal_open() or board == null:
		return
	if _limit_left() <= 0:
		hud.show_msg("Limit ruchów wyczerpany – cofnij ruch albo zacznij od nowa", 3.0)
		Sfx.play("error")
		return
	var rec := board.do_tool(cap)
	if rec.is_empty():
		return
	history.append(rec)
	max_progress = maxi(max_progress, history.size())
	hint = {}
	Sfx.play("pick", 0.7)
	fx.burst(Vector2(gripper_x, rail_y + 50), COL_SELECT, 12)
	_update_hud()
	if board.is_solved():
		_on_level_complete()


# ---------------------------------------------------------------- tryb programowania

func _on_prog_delete() -> void:
	if mode != "program" or prog_state != "edit" or program.is_empty():
		return
	program.pop_back()
	hint = {}
	_update_hud()


func _on_prog_clear() -> void:
	if mode != "program" or prog_state != "edit":
		return
	program.clear()
	hint = {}
	_update_hud()


func _on_prog_start() -> void:
	if mode != "program" or hud.is_modal_open():
		return
	if prog_state in ["fault", "fail"]:
		# "Edytuj": plansza wraca do stanu początkowego, program zostaje.
		board = start_board.clone()
		prog_state = "edit"
		prog_index = -1
		prog_error = -1
		fault_time = 0.0
		hud.show_msg("")
		_update_hud()
		return
	if prog_state != "edit":
		return
	if program.is_empty():
		hud.show_msg("Program jest pusty – dodaj kroki", 3.0)
		Sfx.play("error")
		return
	board = start_board.clone()
	selected = -1
	hint = {}
	prog_state = "run"
	prog_index = 0
	prog_error = -1
	prog_wait = 0.3
	hud.show_msg("Program uruchomiony…", 2.0)
	_update_hud()


func _program_tick(delta: float) -> void:
	if prog_state != "run" or not anim.is_empty():
		return
	prog_wait -= delta
	if prog_wait > 0.0:
		return
	if board.is_solved():
		_on_program_complete()
		return
	if prog_index >= program.size():
		prog_state = "fail"
		Sfx.play("error")
		hud.show_msg("Program zakończony, ale palety nie są posortowane. Naciśnij „Edytuj”.", 6.0)
		_update_hud()
		return
	var step: Array = program[prog_index]
	if board.move_count(step[0], step[1]) == 0:
		prog_state = "fault"
		prog_error = prog_index
		fault_time = 1.5
		Sfx.play("error")
		shake[step[0]] = 0.3
		fx.burst(Vector2(gripper_x, rail_y + 40), COL_FAULT, 26)
		hud.show_msg("BŁĄD PROGRAMU – krok %d: %s" % [prog_index + 1, _fault_reason(step[0], step[1])], 8.0)
		_update_hud()
		return
	_try_move(step[0], step[1])
	prog_index += 1
	prog_wait = PROGRAM_STEP_PAUSE
	_update_hud()


func _fault_reason(from: int, to: int) -> String:
	var src: Array = board.stacks[from]
	var dst: Array = board.stacks[to]
	if src.is_empty():
		return "paleta %d jest pusta" % (from + 1)
	if dst.size() >= board.capacity:
		return "paleta %d jest pełna" % (to + 1)
	return "na palecie %d leży inny produkt" % (to + 1)


func _on_program_complete() -> void:
	prog_state = "done"
	var number: int = prog["number"]
	var stars := LevelGenerator.program_stars(program.size(), prog["optimal"])
	var new_stars: int = Save.record_stars(true, number, stars)
	var bonus: int = Save.wallet.on_level_completed()
	Save.program = maxi(Save.program, number + 1)
	Save.save()
	_update_hud()
	fx.confetti(get_viewport_rect().size.x)
	Sfx.play("win")
	var text := "Program %d działa!\nKroki: %d (najkrótszy: %d)" % [number, program.size(), prog["optimal"]]
	if new_stars > 0:
		text += "\n+%d %s do rozbudowy hali" % [new_stars, _plural(new_stars, "gwiazdka", "gwiazdki", "gwiazdek")]
	if bonus > 0:
		text += "\n+1 podpowiedź za 3 ukończone zadania"
	await get_tree().create_timer(0.6).timeout
	hud.show_win(text, stars, "Następny program")


## Podpowiedź w trybie programowania: sprawdza program "na sucho" i mówi, co poprawić.
func _program_hint() -> void:
	var sim := start_board.clone()
	for k in program.size():
		var st: Array = program[k]
		if sim.move_count(st[0], st[1]) == 0:
			var saved := board
			board = sim
			var reason := _fault_reason(st[0], st[1])
			board = saved
			Save.wallet.use()
			hud.show_msg("Krok %d nie zadziała: %s" % [k + 1, reason], 5.0)
			return
		sim.do_move(st[0], st[1])
		if sim.is_solved():
			hud.show_msg("Ten program już działa – naciśnij START (podpowiedź nie została zużyta)", 4.0)
			return
	var left: int = prog["max_steps"] - program.size()
	var r := Solver.solve(sim, 40000, left)
	if r.ok and not r.moves.is_empty():
		Save.wallet.use()
		var m: Array = r.moves[0]
		hint = {"from": m[0], "to": m[1], "time": HINT_TIME}
		hud.show_msg("Dodaj krok: %d » %d" % [m[0] + 1, m[1] + 1], 5.0)
		return
	# Program prowadzi w ślepy zaułek - znajdź, od którego kroku trzeba go poprawić.
	for k in range(program.size() - 1, -1, -1):
		var b := start_board.clone()
		for j in k:
			b.do_move(program[j][0], program[j][1])
		if Solver.solve(b, 20000, prog["max_steps"] - k).ok:
			Save.wallet.use()
			hud.show_msg("Usuń kroki od %d – dalej program nie da się dokończyć" % (k + 1), 5.0)
			return
	hud.show_msg("Spróbuj ułożyć program od nowa", 4.0)


# ---------------------------------------------------------------- podpowiedzi i sklep

func _on_hint() -> void:
	if not anim.is_empty() or board == null or hud.is_modal_open():
		return
	if mode == "program" and prog_state != "edit":
		return
	if not Save.wallet.can_use():
		hud.show_shop()
		return
	hint = {}
	selected = -1
	if mode == "program":
		_program_hint()
	else:
		_campaign_hint()
	Sfx.play("hint")
	Save.save()
	_update_hud()
	queue_redraw()


func _campaign_hint() -> void:
	var r := Solver.solve(board, 40000, _limit_left() if move_limit > 0 else -1)
	if r.ok and not r.moves.is_empty():
		Save.wallet.use()
		var m: Array = r.moves[0]
		if m[0] < 0:
			hud.show_msg("Zmień chwytak na %s" % TOOL_NAMES.get(m[1], "inny"), HINT_TIME)
		else:
			hint = {"from": m[0], "to": m[1], "time": HINT_TIME}
			hud.show_msg("Przenieś z palety Z na paletę NA", HINT_TIME)
		return
	var k := _undos_needed()
	if k > 0:
		Save.wallet.use()
		hud.show_msg("Ślepy zaułek – cofnij %d %s" % [k, _plural(k, "ruch", "ruchy", "ruchów")], 4.0)
	else:
		hud.show_msg("Najlepiej zacząć od nowa (podpowiedź nie została zużyta)", 4.0)


func _undos_needed() -> int:
	var b := board.clone()
	for k in history.size():
		b.undo(history[history.size() - 1 - k])
		var used := history.size() - k - 1
		var depth := move_limit - used if move_limit > 0 else -1
		if Solver.solve(b, 15000, depth).ok:
			return k + 1
	return 0


func _plural(k: int, one: String, few: String, many: String) -> String:
	if k == 1:
		return one
	if k % 10 >= 2 and k % 10 <= 4 and (k % 100 < 10 or k % 100 >= 20):
		return few
	return many


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
	hud.show_shop()
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
		hud.show_shop()
		_update_hud()


func _on_decor_chosen(slot_id: String, item_id: String) -> void:
	var had := Save.owns(item_id)
	if Save.choose_decor(slot_id, item_id):
		Sfx.play("click" if had else "reward")
	else:
		Sfx.play("error")
	hud.refresh_decor()
	queue_redraw()


## Wybór poziomu z okna testowego (w trybie programowania - numer programu).
func _on_level_chosen(n: int) -> void:
	if not anim.is_empty():
		return
	if mode == "program":
		Save.program = n
		Save.save()
		_request("p", n)
	else:
		Save.level = n
		Save.save()
		mode = "campaign"
		_request("c", n)


func _on_sound_toggled() -> void:
	Save.sound_on = not Save.sound_on
	Save.save()


func _update_hud() -> void:
	if board == null:
		return
	if mode == "program":
		hud.set_program_status(prog["number"], program, prog["max_steps"], prog["optimal"],
			prog_index if prog_state == "run" else -1, prog_error, prog_state, Save.wallet.hints)
	else:
		hud.set_status(level, history.size(), move_limit, params.get("mods", []), Save.wallet.hints)
		hud.set_tools(board.tools, board.tool_cap)


# ---------------------------------------------------------------- dotyk

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tap(event.position)


func _on_tap(pos: Vector2) -> void:
	if board == null or not anim.is_empty() or hud.is_modal_open():
		return
	if mode == "program":
		_on_tap_program(pos)
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
	elif _limit_left() <= 0 and board.can_move(selected, i):
		_reject(i)
		hud.show_msg("Limit ruchów wyczerpany – cofnij ruch albo zacznij od nowa", 3.0)
	elif _try_move(selected, i):
		selected = -1
	elif board.can_move(selected, i) and not board.tools.is_empty():
		_reject(i)
		hud.show_msg("Ten chwytak nie przeniesie tych paczek – zmień chwytak", 3.0)
	elif _can_pick(i):
		selected = i
		Sfx.play("click")
	else:
		_reject(i)
		selected = -1
	queue_redraw()


## W trybie programowania dotknięcia dodają kroki - plansza się nie zmienia.
func _on_tap_program(pos: Vector2) -> void:
	if prog_state != "edit":
		return
	var i := _stack_at(pos)
	hint = {}
	if i < 0:
		selected = -1
	elif selected == -1:
		selected = i
		Sfx.play("click")
	elif selected == i:
		selected = -1
	elif program.size() >= prog["max_steps"]:
		hud.show_msg("Program ma już maksymalną liczbę kroków (%d)" % prog["max_steps"], 3.0)
		Sfx.play("error")
		selected = -1
	else:
		program.append([selected, i])
		Sfx.play("pick", 1.2)
		selected = -1
		_update_hud()
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
	if mode == "program":
		_program_tick(delta)
	_decay(bounce, delta * 3.0)
	_decay(shake, delta)
	fault_time = maxf(0.0, fault_time - delta)
	if not hint.is_empty():
		hint["time"] -= delta
		if hint["time"] <= 0.0:
			hint = {}
	queue_redraw()  # tło (taśmociąg, lampki, ozdoby) jest animowane cały czas


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
	rail_y = 292.0 if mode == "program" else 196.0
	var top := rail_y + 54.0
	var bottom := vs.y - (262.0 if not board.tools.is_empty() else 200.0)
	var row_gap := 64.0
	var avail_h := (bottom - top - row_gap * (rows - 1)) / rows - pallet_h
	var box_h := minf(col_w * 0.62, avail_h / board.capacity)
	box_size = Vector2(col_w, box_h)
	var stack_h := box_h * board.capacity + pallet_h
	var total_h := stack_h * rows + row_gap * (rows - 1)
	var y0 := top + (bottom - top - total_h) / 2.0
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


# ---------------------------------------------------------------- rysowanie: hala i ozdoby

func _draw() -> void:
	var vs := get_viewport_rect().size
	_draw_hall(vs)
	if board != null:
		for i in board.stacks.size():
			_draw_stack(i)
	_draw_robot()


func _draw_hall(vs: Vector2) -> void:
	var wall := Decor.item(Save.decor_of("wall"))
	var top_col := Color(wall["top"])
	var bottom_col := Color(wall["bottom"])
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(0, vs.y)]),
		PackedColorArray([top_col, top_col, bottom_col, bottom_col]))
	var floor_y := vs.y - 190.0
	if wall.get("brick", false):
		var row := 0
		for y in range(0, int(floor_y), 26):
			var shift := 0 if row % 2 == 0 else 34
			draw_line(Vector2(0, y), Vector2(vs.x, y), Color(0, 0, 0, 0.18), 2)
			for x in range(-shift, int(vs.x), 68):
				draw_line(Vector2(x, y), Vector2(x, y + 26), Color(0, 0, 0, 0.18), 2)
			row += 1
	else:
		for x in range(60, int(vs.x), 120):
			draw_line(Vector2(x, 0), Vector2(x, floor_y), Color(1, 1, 1, 0.025), 2)
	_draw_lights(vs)
	_draw_sign(vs)
	# Posadzka.
	var fl := Decor.item(Save.decor_of("floor"))
	draw_rect(Rect2(0, floor_y, vs.x, vs.y - floor_y), Color(fl["color"]))
	if fl.get("grate", false):
		for x in range(0, int(vs.x), 22):
			draw_line(Vector2(x, floor_y), Vector2(x, vs.y), Color(0, 0, 0, 0.25), 2)
		for y in range(int(floor_y), int(vs.y), 22):
			draw_line(Vector2(0, y), Vector2(vs.x, y), Color(0, 0, 0, 0.25), 2)
	for x in range(-20, int(vs.x) + 20, 28):
		draw_colored_polygon(PackedVector2Array([Vector2(x, floor_y), Vector2(x + 14, floor_y), Vector2(x + 4, floor_y + 10), Vector2(x - 10, floor_y + 10)]), Color("#e0b000"))
	_draw_arm(vs, floor_y)
	_draw_plants(vs, floor_y)
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


func _draw_lights(vs: Vector2) -> void:
	match Save.decor_of("lights"):
		"lights_lamps":
			for k in 3:
				var x := vs.x * (k + 0.5) / 3.0
				draw_line(Vector2(x, 0), Vector2(x, 14), COL_STEEL, 3)
				draw_colored_polygon(PackedVector2Array([Vector2(x - 26, 34), Vector2(x - 12, 14), Vector2(x + 12, 14), Vector2(x + 26, 34)]), COL_STEEL)
				draw_colored_polygon(PackedVector2Array([Vector2(x - 26, 34), Vector2(x + 26, 34), Vector2(x + 150, vs.y - 190), Vector2(x - 150, vs.y - 190)]), Color(1, 0.95, 0.75, 0.035))
				draw_circle(Vector2(x, 34), 8, Color("#fff3c4"))
		"lights_led":
			var hue := fmod(time * 0.05, 1.0)
			for k in 12:
				var c := Color.from_hsv(fmod(hue + k / 12.0, 1.0), 0.6, 1.0)
				var x := vs.x * k / 12.0
				draw_rect(Rect2(x, rail_y - 16, vs.x / 12.0, 5), c)
			draw_rect(Rect2(0, rail_y - 26, vs.x, 26), Color.from_hsv(hue, 0.6, 1.0, 0.07))


func _draw_sign(vs: Vector2) -> void:
	if mode == "program":
		return  # w trybie programowania to miejsce zajmuje lista kroków
	var font := ThemeDB.fallback_font
	match Save.decor_of("sign"):
		"sign_clock":
			var c := Vector2(56, 160)
			draw_circle(c, 28, Color("#e9edf2"))
			draw_arc(c, 28, 0, TAU, 32, COL_STEEL_DARK, 4)
			var t := Time.get_time_dict_from_system()
			var ha: float = TAU * (float(t["hour"] % 12) + t["minute"] / 60.0) / 12.0 - PI / 2.0
			var ma: float = TAU * t["minute"] / 60.0 - PI / 2.0
			draw_line(c, c + Vector2.from_angle(ha) * 14, COL_STEEL_DARK, 4)
			draw_line(c, c + Vector2.from_angle(ma) * 21, COL_STEEL_DARK, 3)
			draw_circle(c, 3, COL_FAULT)
		"sign_board":
			var r := Rect2(vs.x - 236, 132, 212, 52)
			draw_rect(r, Color("#111418"))
			draw_rect(r, COL_STEEL, false, 3)
			var done := Save.stars.size() + Save.program_stars.size()
			draw_string(font, r.position + Vector2(10, 22), "Wykonane: %d" % done, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#3ddc84"))
			draw_string(font, r.position + Vector2(10, 44), "Gwiazdki: %d" % Save.total_stars(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#ffc93c"))


func _draw_plants(vs: Vector2, floor_y: float) -> void:
	var kind := Save.decor_of("plants")
	if kind == "plants_none":
		return
	for x in [22.0, vs.x - 22.0]:
		var pot := Rect2(x - 14, floor_y - 26, 28, 26)
		draw_colored_polygon(PackedVector2Array([pot.position, pot.position + Vector2(28, 0), pot.end - Vector2(4, 0), Vector2(pot.position.x + 4, pot.end.y)]), Color("#b5603a"))
		var sway := sin(time * 1.3 + x) * 2.0
		if kind == "plants_flower":
			draw_line(Vector2(x, floor_y - 26), Vector2(x + sway, floor_y - 58), Color("#3f8f4a"), 3)
			draw_circle(Vector2(x - 8, floor_y - 40), 6, Color("#3f8f4a"))
			draw_circle(Vector2(x + sway, floor_y - 62), 9, Color("#ff7aa8"))
			draw_circle(Vector2(x + sway, floor_y - 62), 4, Color("#ffd23f"))
		else:
			draw_line(Vector2(x, floor_y - 26), Vector2(x + sway, floor_y - 90), Color("#7a5a3a"), 5)
			for k in 5:
				var a := -PI / 2.0 + (k - 2) * 0.6 + sway * 0.05
				var tip := Vector2(x + sway, floor_y - 90) + Vector2.from_angle(a) * 34
				draw_line(Vector2(x + sway, floor_y - 90), tip, Color("#2f8a46"), 7)


## Ramię przemysłowe w tle, które przekłada kartony z taśmociągu (tylko ozdoba).
func _draw_arm(vs: Vector2, floor_y: float) -> void:
	if Save.decor_of("arm") != "arm_robot":
		return
	var base := Vector2(vs.x - 70, floor_y + 16)
	var a1 := -PI / 2.0 + 0.5 * sin(time * 0.9)
	var a2 := a1 + 1.2 + 0.4 * sin(time * 1.3)
	var j1 := base + Vector2.from_angle(a1) * 70
	var j2 := j1 + Vector2.from_angle(a2) * 55
	var col := Color("#e8a100")
	draw_rect(Rect2(base.x - 22, base.y - 10, 44, 16), COL_STEEL_DARK)
	draw_line(base, j1, col, 14)
	draw_line(j1, j2, col, 10)
	draw_circle(base, 11, col.darkened(0.3))
	draw_circle(j1, 9, col.darkened(0.3))
	draw_rect(Rect2(j2.x - 8, j2.y - 4, 16, 10), COL_STEEL)


# ---------------------------------------------------------------- rysowanie: palety i paczki

func _draw_stack(i: int) -> void:
	var r: Rect2 = stack_rects[i]
	var stack: Array = board.stacks[i]
	var complete := board.is_stack_complete(i)
	var sx: float = sin(time * 60.0) * 7.0 * (shake.get(i, 0.0) / 0.3)
	var by := sin(bounce.get(i, 0.0) * PI) * 5.0
	var base := r.position + Vector2(sx, 0)
	var slot := Rect2(base, Vector2(r.size.x, r.size.y - pallet_h))
	draw_rect(slot, Color(COL_DONE, 0.10) if complete else Color(1, 1, 1, 0.035))
	for px in [base.x - 8, base.x + r.size.x + 2]:
		draw_rect(Rect2(px, base.y - 14, 6, r.size.y + 14), COL_STEEL)
		for hy in range(int(base.y), int(base.y + r.size.y), 18):
			draw_rect(Rect2(px + 2, hy, 2, 6), COL_STEEL_DARK)
	draw_rect(Rect2(base.x - 8, base.y - 18, r.size.x + 16, 6), COL_STEEL)
	var lamp := Vector2(base.x + r.size.x / 2.0, base.y - 15)
	var lamp_col := LAMP_OFF
	if complete:
		lamp_col = COL_DONE
	elif not hint.is_empty() and (hint["from"] == i or hint["to"] == i):
		lamp_col = COL_HINT.lerp(LAMP_OFF, 0.5 + 0.5 * sin(time * 12.0))
	if lamp_col != LAMP_OFF:
		draw_circle(lamp, 16, Color(lamp_col, 0.25))
	if complete:
		draw_circle(lamp, 12, COL_DONE)
		draw_polyline(PackedVector2Array([lamp + Vector2(-6, 0), lamp + Vector2(-2, 5), lamp + Vector2(6, -5)]), Color.WHITE, 3.0)
	else:
		draw_circle(lamp, 6, lamp_col)
	var hidden: int = anim["n"] if not anim.is_empty() and anim["to"] == i else 0
	var visible_count := stack.size() - hidden
	var lift_from := stack.size() - board.top_run(i) if selected == i and mode == "campaign" else 9999
	for k in visible_count:
		var br := _box_rect(i, k)
		br.position.x += sx
		br.position.y += by * (k + 1) / float(maxi(1, visible_count))
		if k >= lift_from:
			br.position.y -= 24.0 + sin(time * 7.0) * 3.0
		_draw_box(br, stack[k], _wrapped_during_anim(i, k))
	var pr := Rect2(base.x - 6, base.y + r.size.y - pallet_h, r.size.x + 12, pallet_h)
	draw_rect(Rect2(pr.position, Vector2(pr.size.x, pallet_h * 0.4)), COL_PALLET)
	for b in 3:
		var bx := pr.position.x + 2 + b * (pr.size.x - 24) / 2.0
		draw_rect(Rect2(bx, pr.position.y + pallet_h * 0.4, 20, pallet_h * 0.6), COL_PALLET_DARK)
	draw_rect(Rect2(pr.position.x, pr.end.y - 3, pr.size.x, 3), COL_PALLET)
	if mode == "program":
		# Numery palet - potrzebne do czytania programu.
		draw_string(ThemeDB.fallback_font, Vector2(base.x, pr.end.y + 28), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, Color("#c8d0da"))
	if selected == i:
		draw_rect(Rect2(base, r.size).grow(8), COL_SELECT, false, 4.0)
	if not hint.is_empty() and (hint["from"] == i or hint["to"] == i):
		var a := 0.7 + 0.3 * sin(time * 8.0)
		var hr := Rect2(base, r.size).grow(10)
		draw_rect(hr, Color(COL_HINT, 0.15 * a))
		draw_rect(hr, Color(COL_HINT, a), false, 6.0)
		var label := "Z" if hint["from"] == i else "NA"
		draw_string(ThemeDB.fallback_font, Vector2(base.x, base.y - 30), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, COL_HINT)


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


# ---------------------------------------------------------------- rysowanie: robot

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
	var robot_col := Color(Decor.item(Save.decor_of("robot"))["color"])
	var n_load: int = anim["n"] if not anim.is_empty() else 0
	if st["load"] != null:
		var top_left: Vector2 = st["load"]
		for j in n_load:
			var p := top_left + Vector2(0, (n_load - 1 - j) * box_size.y)
			_draw_box(Rect2(p, box_size), anim["items"][j])
	var w := box_size.x if box_size.x > 0 else 110.0
	# Wózek na szynie.
	var cart := Rect2(grip.x - 36, rail_y - 18, 72, 34)
	var sb := StyleBoxFlat.new()
	sb.bg_color = robot_col
	sb.border_color = robot_col.darkened(0.35)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	draw_style_box(sb, cart)
	draw_rect(Rect2(cart.position.x + 8, cart.position.y + 8, cart.size.x - 16, 6), Color(0, 0, 0, 0.25))
	for wx in [-22, 0, 22]:
		draw_circle(Vector2(grip.x + wx, rail_y - 12), 5, COL_STEEL_DARK)
	# Lampa: miga w ruchu, świeci na czerwono po błędzie programu.
	var lamp_col := Color("#7a3a2a")
	if fault_time > 0.0 or prog_state == "fault":
		lamp_col = COL_FAULT if fmod(time, 0.3) < 0.15 or prog_state == "fault" else Color("#7a3a2a")
	elif not anim.is_empty() and fmod(time, 0.4) < 0.2:
		lamp_col = Color("#ff9a36")
	draw_rect(Rect2(grip.x - 7, rail_y - 30, 14, 12), lamp_col)
	if lamp_col != Color("#7a3a2a"):
		draw_circle(Vector2(grip.x, rail_y - 24), 16, Color(lamp_col, 0.25))
	# Kolumna teleskopowa.
	var head_y := grip.y - 16.0
	draw_rect(Rect2(grip.x - 9, rail_y + 16, 18, 26), COL_STEEL)
	draw_rect(Rect2(grip.x - 5, rail_y + 16, 10, maxf(0.0, head_y - rail_y - 16)), COL_RAIL)
	# Głowica zależna od chwytaka.
	var tool := Board.TOOL_SMART
	if board != null and not board.tools.is_empty():
		tool = board.tool_cap
	var head_col := robot_col.darkened(0.15)
	match tool:
		Board.TOOL_VACUUM:
			draw_rect(Rect2(grip.x - w / 2.0, head_y, w, 12), head_col)
			for k in 3:
				var cx := grip.x - w / 3.0 + k * w / 3.0
				draw_rect(Rect2(cx - 3, head_y + 10, 6, 6), COL_STEEL_DARK)
				draw_colored_polygon(PackedVector2Array([Vector2(cx - 10, head_y + 18), Vector2(cx + 10, head_y + 18), Vector2(cx + 6, head_y + 14), Vector2(cx - 6, head_y + 14)]), Color("#1d2229"))
		2:
			draw_rect(Rect2(grip.x - w / 2.0 - 12, head_y, w + 24, 12), head_col)
			var fork_len := (n_load * box_size.y + 16.0) if st["closed"] else 18.0
			for side in [-1.0, 1.0]:
				var fx_: float = grip.x + side * (w / 2.0 + 6) - 3
				draw_rect(Rect2(fx_, head_y + 8, 6, fork_len), COL_STEEL_DARK)
				if st["closed"]:
					draw_rect(Rect2(fx_ - (side * 14.0 if side > 0 else 0.0), head_y + 8 + fork_len - 6, 20, 6), COL_STEEL_DARK)
		_:
			var open := 0.0 if st["closed"] else 10.0
			draw_rect(Rect2(grip.x - w / 2.0 - 10 - open, head_y, w + 20 + open * 2.0, 12), head_col)
			var jaw_h := 22.0 if st["closed"] else 16.0
			for side in [-1.0, 1.0]:
				var jx: float = grip.x + side * (w / 2.0 + 4 + open) - 4
				draw_rect(Rect2(jx, head_y + 8, 8, jaw_h), COL_STEEL_DARK)

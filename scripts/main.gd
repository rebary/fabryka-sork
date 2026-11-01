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
	"upadki": ["Nowość: śliskie paczki", "Czasem paczka wyślizgnie się z chwytaka i spadnie z powrotem na paletę.\nTaki ruch przepada – nie da się go cofnąć."],
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
var dropped_moves := 0  # ruchy stracone przez upuszczenie paczki (nie da się ich cofnąć)
var found_hint_this_level := false
var hint_planner := HintPlanner.new()
var hints_used_level := 0  # podpowiedzi użyte na tym poziomie (premia punktowa za grę bez nich)
var preview := {}  # podgląd programu: {"board", "time", "error"}
# Pojedynek: {"kind": "ai"/"code"/"create", "seed", "rival": Rival|null, "rival_info",
#             "target_ds", "target_moves", "time", "countdown", "finished", "surrender"}
var duel := {}
const DUEL_COUNTDOWN := 3.0
const PREVIEW_TIME := 4.0
const FREE_PREVIEW_PROGRAMS := 3  # w programach 1-3 podgląd jest darmowy (nauka)
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


var post: CanvasLayer


func _ready() -> void:
	randomize()
	Look.init()
	# Efekty całego obrazu (shader) - warstwa nad grą, pod interfejsem.
	post = CanvasLayer.new()
	post.layer = 1
	var pr := ColorRect.new()
	pr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/post.gdshader")
	pr.material = mat
	post.add_child(pr)
	post.visible = Save.fx_on
	add_child(post)
	hud = preload("res://scripts/hud.gd").new()
	hud.layer = 2
	add_child(hud)
	hud.fx_toggled.connect(func():
		Save.fx_on = not Save.fx_on
		Save.save()
		post.visible = Save.fx_on)
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
	hud.prog_preview_pressed.connect(_on_prog_preview)
	hud.duel_ai_pressed.connect(_start_duel_ai)
	hud.duel_create_pressed.connect(_start_duel_create)
	hud.duel_code_entered.connect(_start_duel_code)
	hud.survey_submitted.connect(_on_survey_submitted)
	hud.survey_opened.connect(func(): Save.feedback_prompted = true)
	hud.menu_pressed.connect(func(): Feedback.flush())
	Feedback.sent_ok.connect(func(_n): pass)
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


## Jednorazowe zaproszenie do ankiety po 5 ukończonych zadaniach (łatwe do odrzucenia).
const SURVEY_PROMPT_AFTER := 5


func _maybe_prompt_survey() -> void:
	if not Save.feedback_prompted and Save.tasks_completed >= SURVEY_PROMPT_AFTER:
		Save.feedback_prompted = true
		Save.save()
		hud.show_survey_prompt()


func _on_survey_submitted(answers: Dictionary) -> void:
	var context := {
		"mode_at_survey": mode if mode != "" else "menu",
		"campaign_level": Save.level,
		"program_number": Save.program,
		"stars": Save.total_stars(),
		"hints": Save.wallet.hints,
		"tasks_completed": Save.tasks_completed,
	}
	Feedback.submit(answers, context)
	Sfx.play("reward")
	hud.show_menu()
	var where := "Wysyłamy ją do twórcy." if Feedback.endpoint != "" else "Zapisaliśmy ją na telefonie – zostanie wysłana, gdy ankiety zostaną włączone."
	hud.show_intro("Dziękujemy!", "Twoja opinia jest dla nas bardzo ważna.\n" + where)


func _on_next() -> void:
	hud.hide_win()
	_maybe_prompt_survey()
	if mode == "duel":
		if duel.get("kind", "ai") == "ai":
			_start_duel_ai()
		else:
			hud.show_duel_menu()
		return
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
	hints_used_level = 0
	_reset_state()
	hud.transition()
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
	hints_used_level = 0
	_reset_state()
	hud.transition()


func _restart_level() -> void:
	if not anim.is_empty() or board == null or hud.is_modal_open():
		return
	board = start_board.clone()
	_reset_state()


func _reset_state() -> void:
	history.clear()
	hint_planner.reset()
	dropped_moves = 0
	selected = -1
	anim = {}
	hint = {}
	bounce.clear()
	shake.clear()
	fault_time = 0.0
	preview = {}
	_layout()
	gripper_x = get_viewport_rect().size.x / 2.0
	_update_hud()
	queue_redraw()


func _moves_used() -> int:
	return history.size() + dropped_moves


func _limit_left() -> int:
	return move_limit - _moves_used() if move_limit > 0 else 9999


# ---------------------------------------------------------------- ruchy (wspólne)

func _try_move(from: int, to: int) -> bool:
	var n := board.move_count(from, to)
	if n == 0:
		return false
	if mode == "campaign" and params.get("mods", []).has(LevelGenerator.MOD_DROP) and randf() < LevelGenerator.DROP_CHANCE:
		_drop_move(from, n)
		return true
	var src_size: int = board.stacks[from].size()
	var dst_size: int = board.stacks[to].size()
	var items: Array = board.stacks[from].slice(src_size - n)
	var src_top := _box_rect(from, src_size - 1).position
	var dst_top := _box_rect(to, dst_size + n - 1).position
	var rec := board.do_move(from, to)
	var lucky := false
	if mode == "duel":
		history.append(rec)
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


## Paczka wyślizguje się z chwytaka: robot ją podnosi, a ona spada z powrotem na paletę.
## Ruch jest liczony, plansza się nie zmienia, cofnięcie nie zwraca ruchu.
func _drop_move(from: int, n: int) -> void:
	var size: int = board.stacks[from].size()
	var items: Array = board.stacks[from].slice(size - n)
	var src_top := _box_rect(from, size - 1).position
	dropped_moves += 1
	var travel := absf(src_top.x + box_size.x / 2.0 - gripper_x) / TRAVEL_SPEED + 0.05
	anim = {"from": from, "to": from, "n": n, "items": items, "reveals": [], "s": src_top, "d": src_top,
		"gx0": gripper_x, "travel": travel, "e": 0.0, "picked": false, "dropped": false,
		"revealed": true, "lucky": false, "drop": true, "slipped": false}
	_update_hud()


func _on_anim_event(u: float) -> void:
	if anim.get("drop", false) and not anim["slipped"] and u >= 0.45:
		anim["slipped"] = true
		Sfx.play("error")
		var p: Vector2 = anim["s"] + Vector2(box_size.x / 2.0, -10)
		fx.float_text("Wyślizgnęła się! −1 ruch", p, Color("#ff6b6b"))
		fx.burst(p + Vector2(0, 30), Color("#ff9a36"), 16)
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
	if mode == "duel":
		if board.is_solved() and not duel.get("finished", true):
			_on_duel_end(true)
		return
	if mode != "campaign":
		return
	if board.is_solved():
		_on_level_complete()
	elif not board.has_any_move():
		hud.show_msg("Brak ruchów – cofnij albo zacznij od nowa", 4.0)
	elif _limit_left() <= 0:
		hud.show_msg("Limit ruchów wyczerpany – cofnij ruch albo zacznij od nowa", 4.0)


func _on_level_complete() -> void:
	var moves := _moves_used()
	var stars := LevelGenerator.stars_for(moves, par)
	var new_stars: int = Save.record_stars(false, level, stars)
	var pts := Score.points(Score.campaign_base(params), stars, hints_used_level)
	var rank_before := Score.rank_for(Save.total_points())
	var gained: int = Save.record_points("c%d" % level, pts)
	var rank_after := Score.rank_for(Save.total_points())
	var bonus: int = Save.wallet.on_level_completed()
	Save.level = level + 1
	Save.tasks_completed += 1
	Save.save()
	_update_hud()
	fx.confetti(get_viewport_rect().size.x)
	Sfx.play("win")
	var text := "Zlecenie %d wykonane!\nRuchy: %d (na 3 gwiazdki: %d)" % [level, moves, par]
	text += _points_text(pts, gained, rank_before, rank_after)
	if new_stars > 0:
		text += "\n+%d %s do rozbudowy hali" % [new_stars, _plural(new_stars, "gwiazdka", "gwiazdki", "gwiazdek")]
	if bonus > 0:
		text += "\n+1 podpowiedź za 3 zlecenia"
	await get_tree().create_timer(0.6).timeout
	hud.show_win(text, stars, "Następne zlecenie")


## Tekst o punktach i ewentualnym awansie na ekranie wygranej.
func _points_text(pts: int, gained: int, rank_before: Dictionary, rank_after: Dictionary) -> String:
	var t := ""
	if gained > 0:
		t += "\n+%d pkt%s" % [gained, " (bez podpowiedzi +20%)" if hints_used_level == 0 else ""]
	else:
		t += "\nWynik: %d pkt (rekord bez zmian)" % pts
	if rank_after["index"] > rank_before["index"]:
		t += "\nAWANS: %s!" % rank_after["name"]
		fx.confetti(get_viewport_rect().size.x)
		Sfx.play("reward")
	return t


func _on_undo() -> void:
	if not (mode in ["campaign", "duel"]) or not anim.is_empty() or history.is_empty() or hud.is_modal_open():
		return
	if mode == "duel" and (duel.get("finished", true) or duel.get("countdown", 0.0) > 0.0):
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


## Podgląd programu: pokazuje, jak wyglądałyby palety po wykonaniu obecnych kroków.
## W programach 1-3 za darmo, potem kosztuje 1 podpowiedź.
func _on_prog_preview() -> void:
	if mode != "program" or prog_state != "edit" or hud.is_modal_open():
		return
	if program.is_empty():
		hud.show_msg("Dodaj kroki, żeby zobaczyć ich skutek", 3.0)
		return
	var free: bool = int(prog["number"]) <= FREE_PREVIEW_PROGRAMS
	if not free and not Save.wallet.can_use():
		hud.show_shop()
		return
	var sim := start_board.clone()
	var error := -1
	for k in program.size():
		var st: Array = program[k]
		if sim.move_count(st[0], st[1]) == 0:
			error = k
			break
		sim.do_move(st[0], st[1])
	if not free:
		_use_hint()
		Save.save()
	selected = -1
	preview = {"board": sim, "time": PREVIEW_TIME, "error": error}
	Sfx.play("hint")
	if error >= 0:
		hud.show_msg("Podgląd: krok %d się nie wykona – robot zatrzyma się tutaj" % (error + 1), PREVIEW_TIME)
	elif sim.is_solved():
		hud.show_msg("Podgląd: program działa! Naciśnij START", PREVIEW_TIME)
	else:
		hud.show_msg("Podgląd: tak wyglądają palety po Twoim programie", PREVIEW_TIME)
	_update_hud()


func _shown_board() -> Board:
	return preview["board"] if not preview.is_empty() else board


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
	var pts := Score.points(Score.program_base(prog["optimal"]), stars, hints_used_level)
	var rank_before := Score.rank_for(Save.total_points())
	var gained: int = Save.record_points("p%d" % number, pts)
	var rank_after := Score.rank_for(Save.total_points())
	var bonus: int = Save.wallet.on_level_completed()
	Save.program = maxi(Save.program, number + 1)
	Save.tasks_completed += 1
	Save.save()
	_update_hud()
	fx.confetti(get_viewport_rect().size.x)
	Sfx.play("win")
	var text := "Program %d działa!\nKroki: %d (najkrótszy: %d)" % [number, program.size(), prog["optimal"]]
	text += _points_text(pts, gained, rank_before, rank_after)
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
			_use_hint()
			hud.show_msg("Krok %d nie zadziała: %s" % [k + 1, reason], 5.0)
			return
		sim.do_move(st[0], st[1])
		if sim.is_solved():
			hud.show_msg("Ten program już działa – naciśnij START (podpowiedź nie została zużyta)", 4.0)
			return
	var left: int = prog["max_steps"] - program.size()
	var seen := {}
	var replay := start_board.clone()
	seen[replay.key()] = true
	for st in program:
		replay.do_move(st[0], st[1])
		seen[replay.key()] = true
	seen.erase(sim.key())
	var r := Solver.solve(sim, 40000, left, seen)
	if r.ok and not r.moves.is_empty():
		_use_hint()
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
			_use_hint()
			hud.show_msg("Usuń kroki od %d – dalej program nie da się dokończyć" % (k + 1), 5.0)
			return
	hud.show_msg("Spróbuj ułożyć program od nowa", 4.0)


# ---------------------------------------------------------------- pojedynek

func _begin_duel(kind: String, seed: int, rival: Rival, rival_info: Dictionary, target_ds: int = 0, target_moves: int = 0) -> void:
	hud.hide_menu()
	hud.hide_win()
	mode = "duel"
	hud.set_mode(mode)
	board = Duel.board_for_seed(seed)
	start_board = board.clone()
	duel = {"kind": kind, "seed": seed, "rival": rival, "rival_info": rival_info, "target_ds": target_ds,
		"target_moves": target_moves, "time": 0.0, "countdown": DUEL_COUNTDOWN, "finished": false, "surrender": 0.0}
	hints_used_level = 0
	_reset_state()
	hud.transition()
	Sfx.play("hint")


## Pojedynek ligowy z rywalem komputerowym dobranym do wyniku gracza.
func _start_duel_ai() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var lg := Duel.league_for(Save.duel_rating)
	var seed := Duel.seed_for_league(lg["index"], rng)
	var info := Duel.pick_rival(Save.duel_rating, rng)
	_begin_duel("ai", seed, Rival.new(Duel.board_for_seed(seed), info, seed), info)


## Wyzwanie dla znajomego: gracz ustala wynik na losowej planszy, dostaje kod.
func _start_duel_create() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var seed := Duel.seed_for_league(Duel.league_for(Save.duel_rating)["index"], rng)
	_begin_duel("create", seed, null, {})


## Przyjęcie wyzwania z kodu: rywalem jest symulacja tempa znajomego.
func _start_duel_code(d: Dictionary) -> void:
	var seed: int = d["seed"]
	var b := Duel.board_for_seed(seed)
	var info := {"name": "Znajomy", "model": "tempo z kodu", "rating": 1000}
	var ghost := Rival.new(b, info, seed)
	ghost.set_exact(Solver.solve_short(b).moves, d["time_ds"] / 10.0)
	_begin_duel("code", seed, ghost, info, d["time_ds"], d["moves"])


func _duel_title() -> String:
	match duel.get("kind", ""):
		"ai":
			var info: Dictionary = duel["rival_info"]
			return "Pojedynek: %s" % info.get("name", "rywal")
		"code":
			return "Wyzwanie"
	return "Ustal wynik"


func _duel_tick(delta: float) -> void:
	if duel["finished"]:
		return
	if duel["countdown"] > 0.0:
		var before: int = ceili(duel["countdown"])
		duel["countdown"] -= delta
		if ceili(duel["countdown"]) != before:
			Sfx.play("click" if duel["countdown"] > 0.0 else "complete")
		return
	duel["time"] += delta
	duel["surrender"] = maxf(0.0, duel["surrender"] - delta)
	var rv = duel["rival"]
	if rv != null and rv.update(delta) and rv.done:
		duel["rival_time"] = duel["time"]
		_on_duel_end(false)
	_update_hud()


func _on_surrender() -> void:
	if duel.is_empty() or duel["finished"] or duel["countdown"] > 0.0:
		return
	if duel["surrender"] > 0.0:
		_on_duel_end(false, true)
	else:
		duel["surrender"] = 3.0
		hud.show_msg("Naciśnij „Poddaj się” jeszcze raz, aby zakończyć pojedynek", 3.0)


func _on_duel_end(player_won: bool, surrendered: bool = false) -> void:
	if duel["finished"]:
		return
	duel["finished"] = true
	var t: float = duel["time"]
	var moves := history.size()
	var kind: String = duel["kind"]
	var text := ""
	var code := ""
	var finished_board := board.is_solved()
	if finished_board:
		code = Duel.encode(duel["seed"], int(round(t * 10.0)), moves)
	match kind:
		"ai":
			var info: Dictionary = duel["rival_info"]
			var before: int = Save.duel_rating
			var lg_before := Duel.league_for(before)
			Save.duel_rating = Duel.new_rating(before, int(info["rating"]), player_won)
			Save.duel_best = maxi(Save.duel_best, Save.duel_rating)
			if player_won:
				Save.duel_wins += 1
			else:
				Save.duel_losses += 1
			var lg_after := Duel.league_for(Save.duel_rating)
			var rv: Rival = duel["rival"]
			if player_won:
				text = "Wygrana z rywalem %s!\nTwój czas: %.1f s (%d ruchów)\nRywal miał %d%% palet" % [info["name"], t, moves, int(rv.progress() * 100.0)]
				var st: int = Save.award_duel_star()
				if st > 0:
					text += "\n+%d gwiazdka do rozbudowy hali" % st
			elif surrendered:
				text = "Poddałeś pojedynek z rywalem %s." % info["name"]
			else:
				text = "Przegrana. %s skończył w %.1f s.\nTy: %d ruchów, %.1f s" % [info["name"], t, moves, t]
			var delta := Save.duel_rating - before
			text += "\nLiga %s: %d (%s%d)" % [lg_after["name"], Save.duel_rating, "+" if delta >= 0 else "", delta]
			if lg_after["index"] > lg_before["index"]:
				text += "\nAWANS do ligi %s!" % lg_after["name"]
				fx.confetti(get_viewport_rect().size.x)
			if code != "":
				text += "\n\nWyzwij znajomego na tej hali:"
		"code":
			var target_s: float = duel["target_ds"] / 10.0
			if finished_board:
				var win := int(round(t * 10.0)) < int(duel["target_ds"]) or (int(round(t * 10.0)) == int(duel["target_ds"]) and moves < int(duel["target_moves"]))
				text = ("Wygrywasz wyzwanie!" if win else "Znajomy był szybszy.") + "\nTy: %.1f s (%d ruchów)\nZnajomy: %.1f s (%d ruchów)" % [t, moves, target_s, duel["target_moves"]]
				text += "\n\nOdeślij znajomemu swój kod:"
				player_won = win
			else:
				text = "Znajomy był szybszy: %.1f s (%d ruchów).\nSpróbuj jeszcze raz z tym samym kodem." % [target_s, duel["target_moves"]]
		"create":
			if finished_board:
				text = "Twój wynik: %.1f s, %d ruchów.\nWyślij znajomemu kod – zagra tę samą halę:" % [t, moves]
				player_won = true
			else:
				text = "Wyzwanie przerwane."
	Save.save()
	if player_won:
		fx.confetti(get_viewport_rect().size.x)
		Sfx.play("win")
	else:
		Sfx.play("error")
	_update_hud()
	await get_tree().create_timer(0.7).timeout
	hud.show_win(text, 0, "Następny pojedynek" if kind == "ai" else "Pojedynek – menu", code)


# ---------------------------------------------------------------- podpowiedzi i sklep

func _on_hint() -> void:
	if mode == "duel":
		_on_surrender()
		return
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
	var h := hint_planner.next_move(board, history, _limit_left() if move_limit > 0 else -1)
	if not h.is_empty():
		_use_hint()
		var m: Array = h["move"]
		if m[0] < 0:
			hud.show_msg("Zmień chwytak na %s" % TOOL_NAMES.get(m[1], "inny"), HINT_TIME)
		else:
			hint = {"from": m[0], "to": m[1], "time": HINT_TIME}
			hud.show_msg("Przenieś z palety Z na paletę NA", HINT_TIME)
		return
	var k := _undos_needed()
	if k > 0:
		_use_hint()
		hud.show_msg("Ślepy zaułek – cofnij %d %s" % [k, _plural(k, "ruch", "ruchy", "ruchów")], 4.0)
	else:
		hud.show_msg("Najlepiej zacząć od nowa (podpowiedź nie została zużyta)", 4.0)


func _use_hint() -> void:
	Save.wallet.use()
	hints_used_level += 1


func _undos_needed() -> int:
	var b := board.clone()
	for k in history.size():
		b.undo(history[history.size() - 1 - k])
		var used := _moves_used() - k - 1
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
func _on_level_chosen(n: int, for_program: bool) -> void:
	if not anim.is_empty():
		return
	if for_program:
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
	if mode == "duel":
		hud.set_duel_status(_duel_title(), duel.get("time", 0.0), history.size(), "")
		return
	if mode == "program":
		hud.set_program_status(prog["number"], program, prog["max_steps"], prog["optimal"],
			prog_index if prog_state == "run" else -1, prog_error, prog_state, Save.wallet.hints)
	else:
		hud.set_status(level, _moves_used(), move_limit, params.get("mods", []), Save.wallet.hints)
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
	if mode == "duel" and (duel.get("countdown", 0.0) > 0.0 or duel.get("finished", true)):
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
	if not preview.is_empty():
		preview = {}
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
	if mode != "" and not hud.menu_layer.visible:
		Save.playtime += delta
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
	if mode == "duel" and not duel.is_empty():
		_duel_tick(delta)
	if not preview.is_empty():
		preview["time"] -= delta
		if preview["time"] <= 0.0:
			preview = {}
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
	rail_y = 292.0 if mode in ["program", "duel"] else 196.0
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
	if mode == "duel" and not duel.is_empty():
		_draw_duel_overlay(vs)
	if not preview.is_empty() and not stack_rects.is_empty():
		var r0: Rect2 = stack_rects[0]
		var a := 0.6 + 0.4 * sin(time * 6.0)
		draw_string(ThemeDB.fallback_font, Vector2(0, r0.position.y - 34), "PODGLĄD PROGRAMU", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 30, Color(0.31, 0.82, 1.0, a))


## Podgląd ekranu przeciwnika (małe palety na żywo) i odliczanie startu.
func _draw_duel_overlay(vs: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var rv = duel["rival"]
	var panel := Rect2(vs.x - 330, 118, 310, 122)
	if rv != null:
		draw_rect(panel, Color(0.05, 0.06, 0.08, 0.85))
		draw_rect(panel, Color("#ff6b6b") if not rv.done else COL_DONE, false, 2.0)
		var info: Dictionary = duel["rival_info"]
		var name_txt := "%s (%s)" % [info.get("name", ""), info.get("model", "")]
		draw_string(font, panel.position + Vector2(10, 22), name_txt, HORIZONTAL_ALIGNMENT_LEFT, 200, 18, Color("#ffb3b3"))
		var status := "GOTOWE" if rv.done else "palety %d%%" % int(rv.progress() * 100.0)
		draw_string(font, panel.position + Vector2(10, 22), status, HORIZONTAL_ALIGNMENT_RIGHT, panel.size.x - 20, 18, COL_DONE if rv.done else Color("#c8d0da"))
		var rb: Board = rv.board
		var n := rb.stacks.size()
		var col_w := (panel.size.x - 20) / n
		var bh := 18.0
		for i in n:
			var x := panel.position.x + 10 + i * col_w
			var base_y := panel.end.y - 10
			draw_rect(Rect2(x + 2, base_y, col_w - 4, 3), COL_PALLET)
			var st: Array = rb.stacks[i]
			for k in st.size():
				var v: int = st[k]
				var c: Color = PRODUCT_COLORS[Board.type_of(v) % PRODUCT_COLORS.size()] if v >= 0 else Color("#b9c4d0")
				draw_rect(Rect2(x + 3, base_y - (k + 1) * bh, col_w - 6, bh - 2), c)
			if rb.is_stack_complete(i):
				draw_rect(Rect2(x + 1, base_y - rb.capacity * bh - 2, col_w - 2, rb.capacity * bh + 4), COL_DONE, false, 2.0)
		if duel["kind"] == "code":
			draw_string(font, Vector2(panel.position.x, panel.end.y + 18), "symulacja tempa znajomego", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 15, Color("#9aa5b1"))
	else:
		var target := "Ustal wynik do pobicia – czas biegnie"
		draw_string(font, Vector2(panel.position.x, panel.position.y + 60), target, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 18, Color("#c8d0da"))
	# Duży stoper po lewej, pod tytułem.
	var big := "%.1f s" % duel["time"]
	draw_string(Look.bold, Vector2(24, 196), big, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color.WHITE)
	if duel["kind"] == "code":
		draw_string(font, Vector2(26, 228), "cel: %.1f s" % (duel["target_ds"] / 10.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ffd23f"))
	if duel["countdown"] > 0.0:
		var n_txt := str(ceili(duel["countdown"]))
		var a := fmod(duel["countdown"], 1.0)
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.35))
		draw_string_outline(font, Vector2(0, vs.y * 0.45), n_txt, HORIZONTAL_ALIGNMENT_CENTER, vs.x, int(140 + 60 * a), 12, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(0, vs.y * 0.45), n_txt, HORIZONTAL_ALIGNMENT_CENTER, vs.x, int(140 + 60 * a), Color("#ffd23f"))
	elif duel["time"] < 0.8:
		draw_string(font, Vector2(0, vs.y * 0.45), "START!", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 110, Color(0.24, 0.86, 0.52, 1.0 - duel["time"] / 0.8))


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
	_draw_backdrop(vs, floor_y)
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


## Głębia hali: świetliki z promieniami światła, regały w oddali i unoszący się kurz.
func _draw_backdrop(vs: Vector2, floor_y: float) -> void:
	# Świetliki pod dachem i promienie światła.
	for k in 3:
		var x := vs.x * (0.2 + 0.3 * k)
		draw_rect(Rect2(x - 40, 2, 80, 26), Color(0.55, 0.7, 0.85, 0.22))
		draw_rect(Rect2(x - 40, 2, 80, 26), Color(0.7, 0.8, 0.9, 0.25), false, 2.0)
		draw_line(Vector2(x, 2), Vector2(x, 28), Color(0, 0, 0, 0.3), 2)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 40, 28), Vector2(x + 40, 28), Vector2(x + 170, floor_y), Vector2(x + 30, floor_y)]),
			Color(0.75, 0.85, 1.0, 0.035))
	# Regały w oddali (sylwetki z kartonami).
	var far := Color(0, 0, 0, 0.16)
	var y_top := floor_y - 300.0
	for x in range(-30, int(vs.x) + 60, 150):
		draw_rect(Rect2(x, y_top, 6, 300), far)
		draw_rect(Rect2(x + 120, y_top, 6, 300), far)
		for shelf in 4:
			var sy := y_top + 40 + shelf * 72
			draw_rect(Rect2(x, sy, 126, 5), far)
			for b in 3:
				var h := 26.0 + float((x * 7 + shelf * 13 + b * 5) % 18)
				draw_rect(Rect2(x + 10 + b * 38, sy - h, 32, h), Color(0, 0, 0, 0.10))
	# Kurz w świetle.
	for i in 36:
		var fx_ := fmod(i * 97.3 + sin(time * 0.3 + i) * 18.0, vs.x)
		var fy := fmod(i * 53.1 + time * (6.0 + float(i % 5) * 2.0), floor_y)
		draw_circle(Vector2(fx_, fy), 1.2 + float(i % 3) * 0.6, Color(1, 1, 0.9, 0.10 + 0.05 * sin(time + i)))


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
	var bd := _shown_board()
	var r: Rect2 = stack_rects[i]
	var stack: Array = bd.stacks[i]
	var complete := bd.is_stack_complete(i)
	var sx: float = sin(time * 60.0) * 7.0 * (shake.get(i, 0.0) / 0.3)
	var by := sin(bounce.get(i, 0.0) * PI) * 5.0
	var base := r.position + Vector2(sx, 0)
	var slot := Rect2(base, Vector2(r.size.x, r.size.y - pallet_h))
	draw_rect(slot, Color(COL_DONE, 0.10) if complete else Color(1, 1, 1, 0.035))
	for px in [base.x - 9, base.x + r.size.x + 2]:
		_grad_h(Rect2(px, base.y - 14, 7, r.size.y + 14), Color("#3a414b"), Color("#8d98a6"), Color("#3a414b"))
		for hy in range(int(base.y), int(base.y + r.size.y), 18):
			draw_rect(Rect2(px + 2.5, hy, 2, 6), COL_STEEL_DARK)
		# Stopka z pasem ostrzegawczym.
		draw_rect(Rect2(px - 3, base.y + r.size.y - 6, 13, 6), Color("#e0b000"))
	_grad_v(Rect2(base.x - 9, base.y - 19, r.size.x + 18, 7), Color("#8d98a6"), Color("#3a414b"))
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
	var lift_from := stack.size() - bd.top_run(i) if selected == i and mode == "campaign" else 9999
	for k in visible_count:
		var br := _box_rect(i, k)
		br.position.x += sx
		br.position.y += by * (k + 1) / float(maxi(1, visible_count))
		if k >= lift_from:
			br.position.y -= 24.0 + sin(time * 7.0) * 3.0
		_draw_box(br, stack[k], _wrapped_during_anim(i, k))
	var pr := Rect2(base.x - 6, base.y + r.size.y - pallet_h, r.size.x + 12, pallet_h)
	_draw_pallet(pr)
	if mode == "program":
		# Numery palet - potrzebne do czytania programu.
		draw_string(ThemeDB.fallback_font, Vector2(base.x, pr.end.y + 28), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, Color("#c8d0da"))
	if selected == i:
		for g in 4:
			draw_rect(Rect2(base, r.size).grow(8 + g * 3), Color(COL_SELECT, 0.22 - g * 0.05), false, 3.0)
		draw_rect(Rect2(base, r.size).grow(8), COL_SELECT, false, 3.0)
	if not hint.is_empty() and (hint["from"] == i or hint["to"] == i):
		var a := 0.7 + 0.3 * sin(time * 8.0)
		var hr := Rect2(base, r.size).grow(10)
		draw_rect(hr, Color(COL_HINT, 0.15 * a))
		draw_rect(hr, Color(COL_HINT, a), false, 6.0)
		var label := "Z" if hint["from"] == i else "NA"
		draw_string(ThemeDB.fallback_font, Vector2(base.x, base.y - 30), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, COL_HINT)


func _draw_pallet(pr: Rect2) -> void:
	var top_h := pallet_h * 0.42
	_grad_v(Rect2(pr.position, Vector2(pr.size.x, top_h)), Color("#c58c52"), Color("#8f5f33"))
	for k in range(1, 4):
		var x := pr.position.x + pr.size.x * k / 4.0
		draw_line(Vector2(x, pr.position.y), Vector2(x, pr.position.y + top_h), Color(0, 0, 0, 0.25), 1.5)
	for b in 3:
		var bx := pr.position.x + 2 + b * (pr.size.x - 24) / 2.0
		_grad_v(Rect2(bx, pr.position.y + top_h, 20, pallet_h - top_h), Color("#7d532d"), Color("#4f331b"))
		draw_circle(Vector2(bx + 10, pr.position.y + top_h * 0.5), 1.6, Color("#d9d2c5"))
	_grad_v(Rect2(pr.position.x, pr.end.y - 3, pr.size.x, 3), Color("#a8743f"), Color("#6e4a2a"))


## Prostokąt z pionowym gradientem (kolor u góry -> u dołu).
func _grad_v(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


## Prostokąt z poziomym gradientem w trzech punktach (efekt walcowanego metalu).
func _grad_h(r: Rect2, left: Color, mid: Color, right: Color) -> void:
	var mx := r.position.x + r.size.x * 0.4
	draw_polygon(PackedVector2Array([r.position, Vector2(mx, r.position.y), Vector2(mx, r.end.y), Vector2(r.position.x, r.end.y)]),
		PackedColorArray([left, mid, mid, left]))
	draw_polygon(PackedVector2Array([Vector2(mx, r.position.y), Vector2(r.end.x, r.position.y), r.end, Vector2(mx, r.end.y)]),
		PackedColorArray([mid, right, right, mid]))


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
	# Cieniowanie: jaśniej u góry, ciemniej u dołu.
	var body := inner.grow(-4)
	_grad_v(body, Color(1, 1, 1, 0.16), Color(0, 0, 0, 0.18))
	# Pokrywa kartonu (lekka perspektywa) i taśma.
	var lid := minf(8.0, inner.size.y * 0.16)
	draw_colored_polygon(PackedVector2Array([inner.position + Vector2(4, 3), Vector2(inner.end.x - 4, inner.position.y + 3),
		Vector2(inner.end.x - 8, inner.position.y + 3 + lid), inner.position + Vector2(8, 3 + lid)]), Color(col.lightened(0.35), 0.8))
	draw_rect(Rect2(inner.get_center().x - 5, inner.position.y + 3, 10, inner.size.y - 9), Color(col.lightened(0.4), 0.45))
	# Plakietka z symbolem produktu.
	var s := minf(inner.size.x, inner.size.y) * 0.25
	var c := inner.get_center() + Vector2(-inner.size.x * 0.12, 1)
	draw_circle(c, s * 1.45, col.darkened(0.32))
	draw_arc(c, s * 1.45, 0, TAU, 24, Color(1, 1, 1, 0.25), 1.5)
	_draw_icon(v, c, s, Color.WHITE)
	# Naklejka z kodem kreskowym.
	var tag := Rect2(inner.end.x - inner.size.x * 0.3, inner.get_center().y - inner.size.y * 0.2, inner.size.x * 0.22, inner.size.y * 0.4)
	draw_rect(tag, Color(0.96, 0.96, 0.92, 0.92))
	for k in 7:
		var bx := tag.position.x + 3 + k * (tag.size.x - 6) / 7.0
		var bw := 1.0 + float((v * 3 + k) % 3) * 0.7
		draw_rect(Rect2(bx, tag.position.y + 3, bw, tag.size.y - 6), Color(0.1, 0.1, 0.1))


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
	if anim.get("drop", false) and u >= 0.35 and u < 0.6:
		load.x += sin(time * 70.0) * 5.0  # paczka się wyślizguje
	if grip_y < 0.0:
		grip_y = load.y
	return {"grip": Vector2(load.x + half, grip_y), "load": load, "closed": closed}


## Prowadnik kablowy (łańcuch energetyczny) nad szyną - jak w prawdziwych suwnicach.
func _draw_cable_chain(cart_x: float) -> void:
	var vs := get_viewport_rect().size
	var fix_x := vs.x * 0.5
	var low_y := rail_y - 30.0
	var high_y := rail_y - 46.0
	var bend_x := (fix_x + cart_x) / 2.0
	var dir := 1.0 if cart_x >= fix_x else -1.0
	draw_rect(Rect2(0, low_y + 6, vs.x, 3), Color(0, 0, 0, 0.35))  # korytko
	var col := Color("#20252c")
	var hi := Color("#454d58")
	var x := fix_x
	while (x - bend_x) * dir < 0.0:
		draw_rect(Rect2(x - 5, low_y - 5, 9, 10), col)
		draw_rect(Rect2(x - 5, low_y - 5, 9, 2), hi)
		x += 11.0 * dir
	draw_arc(Vector2(bend_x, (low_y + high_y) / 2.0), (low_y - high_y) / 2.0, -PI / 2.0 if dir > 0 else PI / 2.0,
		PI / 2.0 if dir > 0 else 3.0 * PI / 2.0, 10, col, 10)
	x = bend_x
	while (cart_x - x) * dir > 0.0:
		draw_rect(Rect2(x - 5, high_y - 5, 9, 10), col)
		draw_rect(Rect2(x - 5, high_y - 5, 9, 2), hi)
		x += 11.0 * dir
	draw_line(Vector2(cart_x, high_y), Vector2(cart_x, rail_y - 18), col, 6)
	draw_rect(Rect2(fix_x - 8, low_y - 8, 16, 16), COL_STEEL)


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
	_draw_cable_chain(grip.x)
	# Wózek na szynie (metaliczny, z diodami stanu).
	var cart := Rect2(grip.x - 38, rail_y - 18, 76, 34)
	var sb := StyleBoxFlat.new()
	sb.bg_color = robot_col
	sb.border_color = robot_col.darkened(0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 3)
	draw_style_box(sb, cart)
	_grad_v(cart.grow(-3), Color(1, 1, 1, 0.28), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(cart.position.x + 6, cart.position.y + 5, cart.size.x - 12, 3), Color(1, 1, 1, 0.35))
	var led_col := COL_DONE
	if prog_state == "fault" or fault_time > 0.0:
		led_col = COL_FAULT
	elif not anim.is_empty():
		led_col = Color("#ff9a36")
	for k in 4:
		var lp := Vector2(cart.position.x + 14 + k * 8, cart.end.y - 9)
		var on := anim.is_empty() or int(time * 10.0) % 4 == k
		draw_circle(lp, 2.6, led_col if on else led_col.darkened(0.6))
		if on:
			draw_circle(lp, 5, Color(led_col, 0.25))
	for bx in [cart.position.x + 5, cart.end.x - 5]:
		draw_circle(Vector2(bx, cart.position.y + 17), 2, robot_col.darkened(0.5))
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

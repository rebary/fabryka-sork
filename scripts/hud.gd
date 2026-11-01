extends CanvasLayer
## Interfejs: napisy, przyciski, menu główne, rozbudowa hali, sklep, wygrana, nowości,
## chwytaki, panel programu, wybór poziomu (test), ekran ładowania.
## Logika gry jest w main.gd - HUD tylko wyświetla i wysyła sygnały.

signal undo_pressed
signal restart_pressed
signal hint_pressed
signal next_pressed
signal sound_toggled
signal buy_pressed(product_id: String)
signal ad_pressed
signal level_chosen(level: int, for_program: bool)
signal menu_pressed
signal campaign_pressed
signal program_mode_pressed
signal decor_chosen(slot_id: String, item_id: String)
signal tool_pressed(cap: int)
signal prog_delete_pressed
signal prog_clear_pressed
signal prog_start_pressed
signal prog_preview_pressed
signal duel_ai_pressed
signal duel_create_pressed
signal duel_code_entered(data: Dictionary)
signal fx_toggled
signal survey_submitted(answers: Dictionary)
signal survey_opened

const COL_ACCENT := Color("#ffb627")
const COL_PANEL := Color("#1d2229")
const COL_TEXT := Color("#eef2f6")
const COL_MUTED := Color("#9aa5b1")
const COL_GREEN := Color("#3ddc84")
const COL_RED := Color("#ff6b6b")
const MOD_NAMES := {"folia": "Folia stretch", "limit": "Limit ruchów", "cap5": "Palety na 5", "chwytaki": "Chwytaki", "upadki": "Śliskie paczki"}
const TOOL_NAMES := {-1: "Próżnia", 2: "Widły", 1: "Szczęki"}
const TOOL_INFO := {-1: "cały ciąg", 2: "do 2 szt.", 1: "1 szt."}

var root: Control
var star_icon: ImageTexture
var lbl_title: Label
var lbl_info: Label
var lbl_badges: Label
var lbl_msg: Label
var msg_timer := 0.0
var program_mode := false
# Pasek kampanii i chwytaków.
var bar_campaign: HBoxContainer
var btn_hint: Button
var bar_tools: HBoxContainer
var tool_buttons := {}
# Tryb programowania.
var bar_program: HBoxContainer
var btn_prog_start: Button
var btn_prog_hint: Button
var prog_chips: HFlowContainer
# Okna.
var win_layer: Control
var win_panel: PanelContainer
var lbl_win: Label
var win_stars: StarRow
var btn_win_next: Button
var shop_layer: Control
var lbl_shop_info: Label
var shop_buttons := {}
var intro_layer: Control
var lbl_intro_title: Label
var lbl_intro: Label
var level_layer: Control
var level_title: Label
var level_edit: LineEdit
var picker_for_program := false
var lbl_level_err: Label
var menu_layer: Control
var btn_menu_campaign: Button
var btn_menu_program: Button
var btn_menu_decor: Button
var btn_menu_sound: Button
var btn_menu_fx: Button
var btn_menu_rank: Button
var btn_menu_duel: Button
var btn_test_stars: Button
var duel_layer: Control
var lbl_duel_league: Label
var lbl_duel_info: Label
var code_layer: Control
var code_edit: LineEdit
var lbl_code_err: Label
var win_code_row: HBoxContainer
var win_code_edit: LineEdit
var lbl_rank_duel: Label
var rank_layer: Control
var lbl_rank_name: Label
var lbl_rank_points: Label
var rank_bar: ProgressBar
var lbl_rank_next: Label
var rank_list: VBoxContainer
var lbl_rank_stats: Label
var fade: ColorRect
# Ankieta.
const SURVEY_CHOICES := {
	"difficulty": ["za łatwa", "w sam raz", "za trudna"],
	"favorite_mode": ["kampania", "programowanie", "oba", "żaden"],
	"recommend": ["tak", "może", "nie"],
}
var survey_layer: Control
var survey_answers := {}
var survey_stars: Array = []
var survey_choice_buttons := {}
var txt_liked: TextEdit
var txt_improve: TextEdit
var lbl_survey_err: Label
var prompt_layer: Control
var star_gray: ImageTexture
var decor_layer: Control
var decor_list: VBoxContainer
var lbl_decor_stars: Label
var busy_layer: Control
var lbl_busy: Label


func _ready() -> void:
	star_icon = StarRow.texture(30)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)

	lbl_title = _label(44, COL_TEXT)
	lbl_title.add_theme_font_override("font", Look.bold)
	lbl_title.position = Vector2(24, 14)
	root.add_child(lbl_title)
	lbl_info = _label(28, COL_MUTED)
	lbl_info.position = Vector2(26, 78)
	root.add_child(lbl_info)
	lbl_badges = _label(24, COL_ACCENT)
	lbl_badges.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	lbl_badges.offset_left = 220
	lbl_badges.offset_right = -24
	lbl_badges.offset_top = 90
	lbl_badges.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(lbl_badges)
	lbl_msg = _label(24, Color("#ffd23f"))
	lbl_msg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	lbl_msg.offset_top = 128
	lbl_msg.offset_left = 16
	lbl_msg.offset_right = -16
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(lbl_msg)

	var btn_menu := _small_button("Menu", func(): menu_pressed.emit())
	_place_top_right(btn_menu, -24, 130)
	root.add_child(btn_menu)
	# Wybór poziomu - TYLKO DO TESTÓW (ukryty w wersji wydawanej do sklepu).
	if OS.is_debug_build():
		var btn_level := _small_button("Poziom", func():
			show_level_picker(Save.program if program_mode else Save.level, program_mode))
		_place_top_right(btn_level, -168, 130)
		root.add_child(btn_level)

	bar_campaign = _bottom_bar()
	bar_campaign.add_child(_button("Cofnij", func(): undo_pressed.emit()))
	bar_campaign.add_child(_button("Od nowa", func(): restart_pressed.emit()))
	btn_hint = _button("Podpowiedź", func(): hint_pressed.emit())
	btn_hint.add_theme_stylebox_override("normal", _box(Color("#3a3216"), COL_ACCENT, 3))
	bar_campaign.add_child(btn_hint)

	bar_tools = _bottom_bar()
	bar_tools.offset_top = -240
	bar_tools.offset_bottom = -146
	for cap in [-1, 2, 1]:
		var b := _button("", func(): tool_pressed.emit(cap), 22)
		b.custom_minimum_size = Vector2(0, 90)
		bar_tools.add_child(b)
		tool_buttons[cap] = b
	bar_tools.visible = false

	bar_program = _bottom_bar()
	bar_program.add_child(_button("Usuń\nkrok", func(): prog_delete_pressed.emit(), 20))
	bar_program.add_child(_button("Wyczyść", func(): prog_clear_pressed.emit(), 20))
	var btn_preview := _button("Podgląd", func(): prog_preview_pressed.emit(), 20)
	btn_preview.add_theme_stylebox_override("normal", _box(Color("#1f3a4d"), Color("#4fd1ff"), 3))
	bar_program.add_child(btn_preview)
	btn_prog_hint = _button("Podpowiedź", func(): hint_pressed.emit(), 20)
	btn_prog_hint.add_theme_stylebox_override("normal", _box(Color("#3a3216"), COL_ACCENT, 3))
	bar_program.add_child(btn_prog_hint)
	btn_prog_start = _button("START", func(): prog_start_pressed.emit(), 24)
	btn_prog_start.add_theme_stylebox_override("normal", _box(Color("#2b6e3f"), COL_GREEN, 3))
	bar_program.add_child(btn_prog_start)
	bar_program.visible = false
	prog_chips = HFlowContainer.new()
	prog_chips.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	prog_chips.offset_left = 20
	prog_chips.offset_right = -20
	prog_chips.offset_top = 128
	prog_chips.add_theme_constant_override("h_separation", 8)
	prog_chips.add_theme_constant_override("v_separation", 8)
	prog_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prog_chips.visible = false
	root.add_child(prog_chips)

	_build_win()
	_build_shop()
	_build_intro()
	_build_level_picker()
	_build_decor()
	_build_menu()
	_build_survey()
	_build_ranking()
	_build_duel_menu()
	_build_code_entry()
	_build_survey_prompt()
	_build_busy()
	# Przejście między poziomami (krótkie wygaszenie).
	fade = ColorRect.new()
	fade.color = Color(0.02, 0.03, 0.04, 1.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	root.add_child(fade)


func transition() -> void:
	fade.modulate.a = 1.0
	create_tween().tween_property(fade, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	if msg_timer > 0.0:
		msg_timer -= delta
		if msg_timer <= 0.0:
			lbl_msg.text = ""


# ---------------------------------------------------------------- API dla main.gd

func set_mode(mode: String) -> void:
	program_mode = mode == "program"
	bar_campaign.visible = not program_mode
	bar_program.visible = program_mode
	prog_chips.visible = program_mode
	lbl_msg.offset_top = 216 if program_mode else (248 if mode == "duel" else 128)
	if program_mode:
		bar_tools.visible = false


func set_status(level: int, moves: int, limit: int, mods: Array, hints: int) -> void:
	lbl_title.text = "Zlecenie %d" % level
	if limit > 0:
		lbl_info.text = "Ruchy: %d / %d" % [moves, limit]
		lbl_info.add_theme_color_override("font_color", COL_RED if limit - moves <= 3 else COL_MUTED)
	else:
		lbl_info.text = "Ruchy: %d" % moves
		lbl_info.add_theme_color_override("font_color", COL_MUTED)
	var b := PackedStringArray()
	for m in mods:
		b.append(MOD_NAMES.get(m, m))
	lbl_badges.text = "  •  ".join(b)
	_set_hint_text(btn_hint, hints)


## Pasek informacji w pojedynku: czas, ruchy, rywal. Przycisk podpowiedzi = "Poddaj się".
func set_duel_status(title: String, seconds: float, moves: int, rival_label: String) -> void:
	lbl_title.text = title
	lbl_info.text = "Czas: %.1f s  •  Ruchy: %d" % [seconds, moves]
	lbl_info.add_theme_color_override("font_color", COL_MUTED)
	lbl_badges.text = ""
	btn_hint.text = "Poddaj się"
	bar_tools.visible = false


func set_tools(tools: Array, current: int) -> void:
	bar_tools.visible = not tools.is_empty()
	for cap in tool_buttons:
		var b: Button = tool_buttons[cap]
		b.visible = tools.has(cap)
		b.text = "%s\n%s" % [TOOL_NAMES[cap], TOOL_INFO[cap]]
		if cap == current:
			b.add_theme_stylebox_override("normal", _box(Color("#1f4a5c"), Color("#4fd1ff"), 4))
			b.add_theme_color_override("font_color", Color("#4fd1ff"))
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_color_override("font_color")


## program = lista kroków [from, to]; active = wykonywany krok (-1 = brak);
## error_step = krok z błędem (-1 = brak); state: "edit", "run", "fault", "fail".
func set_program_status(number: int, program: Array, max_steps: int, optimal: int, active: int, error_step: int, state: String, hints: int) -> void:
	lbl_title.text = "Program %d" % number
	lbl_info.text = "Kroki: %d / %d" % [program.size(), max_steps]
	lbl_info.add_theme_color_override("font_color", COL_MUTED)
	lbl_badges.text = "Najkrótszy: %d" % optimal
	for c in prog_chips.get_children():
		c.queue_free()
	for i in program.size():
		var chip := PanelContainer.new()
		var col := Color("#323a45")
		var border := Color("#59636f")
		if i == error_step:
			col = Color("#5c1f24")
			border = COL_RED
		elif i == active:
			col = Color("#1f4a5c")
			border = Color("#4fd1ff")
		elif active >= 0 and i < active:
			border = COL_GREEN
		var sb := _box(col, border, 2)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		chip.add_theme_stylebox_override("panel", sb)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _label(22, COL_TEXT)
		l.text = "%d: %d » %d" % [i + 1, program[i][0] + 1, program[i][1] + 1]
		chip.add_child(l)
		prog_chips.add_child(chip)
	if program.is_empty() and state == "edit":
		var l := _label(22, COL_MUTED)
		l.text = "Dotknij palety źródłowej, potem docelowej – tak dodajesz krok."
		prog_chips.add_child(l)
	for b in bar_program.get_children():
		b.disabled = state == "run"
	btn_prog_start.text = "Edytuj" if state in ["fault", "fail"] else "START"
	_set_hint_text(btn_prog_hint, hints)


func show_msg(text: String, seconds: float = 3.0) -> void:
	lbl_msg.text = text
	msg_timer = seconds


func show_win(text: String, stars: int, next_label: String, code: String = "") -> void:
	lbl_win.text = text
	win_stars.visible = stars > 0
	win_stars.set_stars(stars, true)
	win_code_row.visible = code != ""
	win_code_edit.text = code
	btn_win_next.text = next_label
	win_layer.visible = true
	win_layer.modulate.a = 0.0
	await get_tree().process_frame
	win_panel.pivot_offset = win_panel.size / 2.0
	win_panel.scale = Vector2(0.7, 0.7)
	var tw := create_tween().set_parallel()
	tw.tween_property(win_layer, "modulate:a", 1.0, 0.25)
	tw.tween_property(win_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_win() -> void:
	win_layer.visible = false


func show_shop() -> void:
	for id in shop_buttons:
		shop_buttons[id].text = "%s – %s" % [Store.PRODUCTS[id]["title"], Store.price_text(id)]
	lbl_shop_info.text = "Masz podpowiedzi: %d" % Save.wallet.hints
	shop_layer.visible = true


func show_intro(title: String, text: String) -> void:
	lbl_intro_title.text = title
	lbl_intro.text = text
	intro_layer.move_to_front()
	intro_layer.visible = true


func show_busy(text: String) -> void:
	lbl_busy.text = text
	busy_layer.visible = true


func hide_busy() -> void:
	busy_layer.visible = false


func show_menu() -> void:
	btn_menu_campaign.text = "Kampania – zlecenie %d" % Save.level
	btn_menu_program.text = "Programowanie robota – program %d" % Save.program
	btn_menu_decor.text = "Rozbudowa hali – %d" % Save.stars_available()
	if btn_test_stars != null:
		btn_test_stars.text = "Test: gwiazdki bez limitu – %s" % ("WŁ." if Save.test_unlimited_stars else "wył.")
	btn_menu_duel.text = "Pojedynek – liga %s (%d)" % [Duel.league_for(Save.duel_rating)["name"], Save.duel_rating]
	var rk := Score.rank_for(Save.total_points())
	btn_menu_rank.text = "Ranking – %s (%d pkt)" % [rk["name"], Save.total_points()]
	btn_menu_sound.text = "Dźwięk: wł." if Save.sound_on else "Dźwięk: wył."
	btn_menu_fx.text = "Efekty graficzne: wł." if Save.fx_on else "Efekty graficzne: wył."
	menu_layer.visible = true


func hide_menu() -> void:
	menu_layer.visible = false


func show_level_picker(current: int, for_program: bool = false) -> void:
	picker_for_program = for_program
	level_layer.move_to_front()  # nad menu głównym
	level_title.text = "Wybór programu (test)" if for_program else "Wybór poziomu (test)"
	lbl_level_err.text = ""
	level_edit.text = str(current)
	level_layer.visible = true
	level_edit.grab_focus()
	level_edit.select_all()


func show_decor() -> void:
	menu_layer.visible = false
	refresh_decor()
	decor_layer.visible = true


func is_modal_open() -> bool:
	for l in [win_layer, shop_layer, intro_layer, busy_layer, level_layer, menu_layer, decor_layer, survey_layer, prompt_layer, rank_layer, duel_layer, code_layer]:
		if l.visible:
			return true
	return false


# ---------------------------------------------------------------- budowa okien

func _build_win() -> void:
	win_layer = _overlay()
	win_panel = _panel(win_layer)
	var v := _vbox(win_panel)
	lbl_win = _label(32, COL_TEXT)
	lbl_win.add_theme_font_override("font", Look.bold)
	lbl_win.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_win.custom_minimum_size = Vector2(520, 0)
	lbl_win.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_win)
	win_stars = StarRow.new(64)
	v.add_child(win_stars)
	win_code_row = HBoxContainer.new()
	win_code_row.add_theme_constant_override("separation", 10)
	win_code_edit = LineEdit.new()
	win_code_edit.editable = false
	win_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_code_edit.custom_minimum_size = Vector2(330, 80)
	win_code_edit.add_theme_font_size_override("font_size", 30)
	win_code_row.add_child(win_code_edit)
	var copy := _button("Kopiuj", func():
		DisplayServer.clipboard_set(win_code_edit.text)
		show_msg("Skopiowano kod – wyślij go znajomemu", 3.0), 22)
	copy.custom_minimum_size = Vector2(160, 80)
	copy.size_flags_horizontal = Control.SIZE_FILL
	win_code_row.add_child(copy)
	win_code_row.visible = false
	v.add_child(win_code_row)
	btn_win_next = _button("Dalej", func(): next_pressed.emit())
	btn_win_next.custom_minimum_size = Vector2(460, 110)
	btn_win_next.add_theme_stylebox_override("normal", _box(Color("#2b6e3f"), COL_GREEN, 3))
	v.add_child(btn_win_next)
	var menu := _button("Menu", func():
		win_layer.visible = false
		menu_pressed.emit())
	menu.custom_minimum_size = Vector2(460, 90)
	v.add_child(menu)


func _build_shop() -> void:
	shop_layer = _overlay()
	var v := _vbox(_panel(shop_layer))
	v.add_child(_title("Podpowiedzi"))
	lbl_shop_info = _label(26, COL_MUTED)
	lbl_shop_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_shop_info)
	var ad := _button("Obejrzyj reklamę: +1", func(): ad_pressed.emit())
	ad.custom_minimum_size = Vector2(480, 96)
	v.add_child(ad)
	for id in Store.PRODUCTS:
		if not Store.PRODUCTS[id].has("hints"):
			continue  # pakiety wyglądu są w "Rozbudowie hali"
		var b := _button(id, func(): buy_pressed.emit(id))
		b.custom_minimum_size = Vector2(480, 96)
		v.add_child(b)
		shop_buttons[id] = b
	var note := _label(20, COL_MUTED)
	note.text = "Tryb testowy: bez prawdziwych płatności i reklam.\nZa darmo: +1 podpowiedź co 3 zlecenia."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	var close := _button("Zamknij", func(): shop_layer.visible = false)
	close.custom_minimum_size = Vector2(480, 90)
	v.add_child(close)


func _build_intro() -> void:
	intro_layer = _overlay()
	var v := _vbox(_panel(intro_layer))
	lbl_intro_title = _label(38, COL_ACCENT)
	lbl_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_intro_title)
	lbl_intro = _label(28, COL_TEXT)
	lbl_intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_intro.custom_minimum_size = Vector2(520, 0)
	v.add_child(lbl_intro)
	var ok := _button("Rozumiem", func(): intro_layer.visible = false)
	ok.custom_minimum_size = Vector2(440, 100)
	v.add_child(ok)


func _build_level_picker() -> void:
	level_layer = _overlay()
	var v := _vbox(_panel(level_layer))
	level_title = _title("Wybór poziomu (test)")
	level_title.add_theme_color_override("font_color", COL_ACCENT)
	v.add_child(level_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var minus := _button("–", func(): _step_level(-1), 40)
	minus.custom_minimum_size = Vector2(96, 96)
	minus.size_flags_horizontal = Control.SIZE_FILL
	row.add_child(minus)
	level_edit = LineEdit.new()
	level_edit.custom_minimum_size = Vector2(240, 96)
	level_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_edit.max_length = 4
	level_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	level_edit.add_theme_font_size_override("font_size", 40)
	level_edit.text_submitted.connect(func(_t): _confirm_level())
	row.add_child(level_edit)
	var plus := _button("+", func(): _step_level(1), 40)
	plus.custom_minimum_size = Vector2(96, 96)
	plus.size_flags_horizontal = Control.SIZE_FILL
	row.add_child(plus)
	lbl_level_err = _label(22, COL_RED)
	lbl_level_err.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_level_err)
	var hint := _label(20, COL_MUTED)
	hint.text = "Nowości: 18 palety na 5 • 23 chwytaki • 28 śliskie\n33 limit ruchów • 41 folia"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var ok := _button("Zatwierdź", func(): _confirm_level())
	ok.custom_minimum_size = Vector2(460, 100)
	ok.add_theme_stylebox_override("normal", _box(Color("#2b6e3f"), COL_GREEN, 3))
	v.add_child(ok)
	var cancel := _button("Anuluj", func(): level_layer.visible = false)
	cancel.custom_minimum_size = Vector2(460, 90)
	v.add_child(cancel)


func _step_level(delta: int) -> void:
	var n := int(level_edit.text) if level_edit.text.is_valid_int() else 1
	level_edit.text = str(clampi(n + delta, 1, 9999))


func _confirm_level() -> void:
	var t := level_edit.text.strip_edges()
	if not t.is_valid_int() or int(t) < 1 or int(t) > 9999:
		lbl_level_err.text = "Wpisz liczbę od 1 do 9999"
		return
	level_layer.visible = false
	menu_layer.visible = false
	level_chosen.emit(int(t), picker_for_program)


func _build_menu() -> void:
	menu_layer = _overlay()
	(menu_layer as ColorRect).color = Color(0.06, 0.07, 0.09, 0.94)
	var v := _vbox(_panel(menu_layer))
	var t := _label(60, COL_ACCENT)
	t.add_theme_font_override("font", Look.bold)
	t.text = "Fabryka Sort"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := _label(22, COL_MUTED)
	sub.text = "Robot, palety i porządek na hali"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	btn_menu_campaign = _menu_button(func(): campaign_pressed.emit())
	btn_menu_campaign.add_theme_stylebox_override("normal", _box(Color("#2b6e3f"), COL_GREEN, 3))
	v.add_child(btn_menu_campaign)
	btn_menu_program = _menu_button(func(): program_mode_pressed.emit())
	btn_menu_program.add_theme_stylebox_override("normal", _box(Color("#1f4a5c"), Color("#4fd1ff"), 3))
	v.add_child(btn_menu_program)
	btn_menu_duel = _menu_button(func(): show_duel_menu())
	btn_menu_duel.add_theme_stylebox_override("normal", _box(Color("#5c1f24"), Color("#ff6b6b"), 3))
	v.add_child(btn_menu_duel)
	btn_menu_decor = _menu_button(func(): show_decor())
	btn_menu_decor.icon = star_icon
	btn_menu_decor.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(btn_menu_decor)
	btn_menu_rank = _menu_button(func(): show_ranking())
	btn_menu_rank.add_theme_stylebox_override("normal", _box(Color("#4a3a12"), COL_ACCENT, 3))
	btn_menu_rank.custom_minimum_size = Vector2(560, 90)
	v.add_child(btn_menu_rank)
	var btn_survey := _menu_button(func(): show_survey())
	btn_survey.text = "Ankieta – podziel się wrażeniami"
	btn_survey.custom_minimum_size = Vector2(560, 84)
	btn_survey.add_theme_stylebox_override("normal", _box(Color("#3a2f4d"), Color("#c77dff"), 3))
	v.add_child(btn_survey)
	btn_menu_sound = _menu_button(func():
		sound_toggled.emit()
		btn_menu_sound.text = "Dźwięk: wł." if Save.sound_on else "Dźwięk: wył.")
	btn_menu_sound.custom_minimum_size = Vector2(560, 80)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	btn_menu_sound.custom_minimum_size = Vector2(0, 80)
	btn_menu_sound.add_theme_font_size_override("font_size", 22)
	row.add_child(btn_menu_sound)
	btn_menu_fx = _button("", func():
		fx_toggled.emit()
		btn_menu_fx.text = "Efekty graficzne: wł." if Save.fx_on else "Efekty graficzne: wył.", 22)
	btn_menu_fx.custom_minimum_size = Vector2(0, 80)
	row.add_child(btn_menu_fx)
	# Wybór poziomu z menu - TYLKO DO TESTÓW (ukryty w wersji wydawanej do sklepu).
	if OS.is_debug_build():
		var test_row := HBoxContainer.new()
		test_row.add_theme_constant_override("separation", 12)
		v.add_child(test_row)
		var b1 := _button("Test: wybierz zlecenie", func(): show_level_picker(Save.level, false), 20)
		b1.custom_minimum_size = Vector2(0, 76)
		test_row.add_child(b1)
		var b2 := _button("Test: wybierz program", func(): show_level_picker(Save.program, true), 20)
		b2.custom_minimum_size = Vector2(0, 76)
		test_row.add_child(b2)
		var b3 := _button("", func():
			Save.test_unlimited_stars = not Save.test_unlimited_stars
			Save.save()
			show_menu(), 20)
		b3.custom_minimum_size = Vector2(560, 70)
		b3.set_meta("unlimited_toggle", true)
		v.add_child(b3)
		btn_test_stars = b3


func _menu_button(cb: Callable) -> Button:
	var b := _button("", cb, 26)
	b.custom_minimum_size = Vector2(560, 100)
	return b


func _build_decor() -> void:
	decor_layer = _overlay()
	(decor_layer as ColorRect).color = Color(0.03, 0.04, 0.06, 0.45)
	var v := _vbox(_panel(decor_layer))
	v.add_theme_constant_override("separation", 12)
	v.add_child(_title("Rozbudowa hali"))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	lbl_decor_stars = _label(28, Color("#ffc93c"))
	row.add_child(lbl_decor_stars)
	var icon := TextureRect.new()
	icon.texture = star_icon
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(icon)
	v.add_child(row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 640)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	decor_list = VBoxContainer.new()
	decor_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decor_list.add_theme_constant_override("separation", 8)
	scroll.add_child(decor_list)
	var note := _label(20, COL_MUTED)
	note.text = "Gwiazdki zdobywasz w zleceniach, programach i pojedynkach. Złote przyciski to pakiety płatne (tryb testowy). Ozdoby zmieniają tylko wygląd."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(540, 0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	var close := _button("Zamknij", func():
		decor_layer.visible = false
		show_menu())
	close.custom_minimum_size = Vector2(560, 90)
	v.add_child(close)


func refresh_decor() -> void:
	lbl_decor_stars.text = ("Gwiazdki: bez limitu (tryb testowy) " if Save.unlimited_stars() else "Dostępne gwiazdki: %d " % Save.stars_available())
	for c in decor_list.get_children():
		c.queue_free()
	for s in Decor.SLOTS:
		var head := _label(26, COL_ACCENT)
		head.text = s["name"]
		decor_list.add_child(head)
		for it in s["items"]:
			var selected: bool = Save.decor_of(s["id"]) == it["id"]
			var owned: bool = Save.owns(it["id"])
			var text: String = it["name"]
			var premium: bool = it.has("premium")
			var slot_id: String = s["id"]
			var item_id: String = it["id"]
			if selected:
				text += " – wybrane"
			elif owned:
				text += " – wybierz"
			elif premium:
				var pid: String = it["premium"]
				text += "\n%s – %s" % [Store.PRODUCTS[pid]["title"], Store.price_text(pid)]
			else:
				text += " – %d" % it["price"]
			var b: Button
			if premium and not owned:
				var pid2: String = it["premium"]
				b = _button(text, func():
					show_busy("Przetwarzanie zakupu (test)…")
					buy_pressed.emit(pid2), 22)
				b.add_theme_stylebox_override("normal", _box(Color("#3d2f0c"), Color("#f2c14e"), 3))
				b.custom_minimum_size = Vector2(0, 92)
			else:
				b = _button(text, func(): decor_chosen.emit(slot_id, item_id), 24)
				b.custom_minimum_size = Vector2(0, 76)
			if not owned and not premium:
				b.icon = star_icon
				b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				b.disabled = Save.stars_available() < int(it["price"])
			if selected:
				b.add_theme_stylebox_override("normal", _box(Color("#1f4a5c"), Color("#4fd1ff"), 3))
			decor_list.add_child(b)


# ---------------------------------------------------------------- pojedynek

func show_duel_menu() -> void:
	var lg := Duel.league_for(Save.duel_rating)
	lbl_duel_league.text = "Liga: %s  (%d)" % [lg["name"], Save.duel_rating]
	var next := ""
	if lg["next_min"] > 0:
		next = "\nDo ligi „%s”: %d" % [lg["next_name"], int(lg["next_min"]) - Save.duel_rating]
	lbl_duel_info.text = "Wygrane: %d  •  Przegrane: %d%s" % [Save.duel_wins, Save.duel_losses, next]
	menu_layer.visible = false
	duel_layer.move_to_front()
	duel_layer.visible = true


func _build_duel_menu() -> void:
	duel_layer = _overlay()
	(duel_layer as ColorRect).color = Color(0.06, 0.07, 0.09, 0.94)
	var v := _vbox(_panel(duel_layer))
	v.add_child(_title("Pojedynek"))
	lbl_duel_league = _label(32, Color("#ff8f8f"))
	lbl_duel_league.add_theme_font_override("font", Look.bold)
	lbl_duel_league.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_duel_league)
	lbl_duel_info = _label(22, COL_MUTED)
	lbl_duel_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_duel_info)
	var ai := _menu_button(func():
		duel_layer.visible = false
		duel_ai_pressed.emit())
	ai.text = "Walcz z rywalem (liga)"
	ai.add_theme_stylebox_override("normal", _box(Color("#5c1f24"), Color("#ff6b6b"), 3))
	v.add_child(ai)
	var create := _menu_button(func():
		duel_layer.visible = false
		duel_create_pressed.emit())
	create.text = "Wyzwij znajomego (utwórz kod)"
	v.add_child(create)
	var accept := _menu_button(func():
		duel_layer.visible = false
		show_code_entry())
	accept.text = "Przyjmij wyzwanie (wpisz kod)"
	v.add_child(accept)
	var info := _label(19, COL_MUTED)
	info.text = "Ta sama hala dla obu graczy – wygrywa szybszy. Bez podpowiedzi, cofanie dozwolone. Wygrana z rywalem: +1 gwiazdka (najwyżej 5 dziennie). Wyzwania kodem nie zmieniają ligi."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(540, 0)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var close := _button("Zamknij", func():
		duel_layer.visible = false
		show_menu())
	close.custom_minimum_size = Vector2(560, 90)
	v.add_child(close)


func show_code_entry() -> void:
	code_edit.text = ""
	lbl_code_err.text = ""
	code_layer.move_to_front()
	code_layer.visible = true
	code_edit.grab_focus()


func _build_code_entry() -> void:
	code_layer = _overlay()
	var v := _vbox(_panel(code_layer))
	v.add_child(_title("Przyjmij wyzwanie"))
	var t := _label(22, COL_MUTED)
	t.text = "Wpisz kod od znajomego, np. FS-7K2QM-41BXD"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	code_edit = LineEdit.new()
	code_edit.custom_minimum_size = Vector2(460, 96)
	code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_edit.max_length = 20
	code_edit.placeholder_text = "FS-XXXXX-XXXXX"
	code_edit.add_theme_font_size_override("font_size", 36)
	code_edit.text_submitted.connect(func(_x): _confirm_code())
	v.add_child(code_edit)
	lbl_code_err = _label(22, COL_RED)
	lbl_code_err.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_code_err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_code_err.custom_minimum_size = Vector2(460, 0)
	v.add_child(lbl_code_err)
	var ok := _button("Zatwierdź", func(): _confirm_code())
	ok.custom_minimum_size = Vector2(460, 100)
	ok.add_theme_stylebox_override("normal", _box(Color("#2b6e3f"), COL_GREEN, 3))
	v.add_child(ok)
	var cancel := _button("Anuluj", func():
		code_layer.visible = false
		show_duel_menu())
	cancel.custom_minimum_size = Vector2(460, 90)
	v.add_child(cancel)


func _confirm_code() -> void:
	var d := Duel.decode(code_edit.text)
	if not d.ok:
		lbl_code_err.text = d["error"]
		return
	code_layer.visible = false
	duel_code_entered.emit(d)


# ---------------------------------------------------------------- ranking

func show_ranking() -> void:
	var total := Save.total_points()
	var rk := Score.rank_for(total)
	lbl_rank_name.text = rk["name"]
	lbl_rank_points.text = "%d pkt" % total
	if rk["next_min"] > 0:
		var span: float = float(rk["next_min"] - rk["min"])
		rank_bar.value = 100.0 * float(total - int(rk["min"])) / span
		lbl_rank_next.text = "Do rangi „%s”: %d pkt" % [rk["next_name"], int(rk["next_min"]) - total]
	else:
		rank_bar.value = 100.0
		lbl_rank_next.text = "Najwyższa ranga – gratulacje!"
	for c in rank_list.get_children():
		c.queue_free()
	for i in Score.RANKS.size():
		var r: Dictionary = Score.RANKS[i]
		var l := _label(24, COL_GREEN if i < rk["index"] else (COL_ACCENT if i == rk["index"] else COL_MUTED))
		var mark := "✓ " if i < rk["index"] else ("» " if i == rk["index"] else "   ")
		l.text = "%s%s – od %d pkt" % [mark, r["name"], r["min"]]
		rank_list.add_child(l)
	lbl_rank_stats.text = "Ukończone zlecenia: %d (%d pkt)\nUkończone programy: %d (%d pkt)\nGwiazdki: %d" % [
		Save.stars.size(), Save.points_of("c"), Save.program_stars.size(), Save.points_of("p"), Save.total_stars()]
	var lg := Duel.league_for(Save.duel_rating)
	lbl_rank_duel.text = "Liga pojedynków: %s – %d (rekord %d)\nWygrane: %d  •  Przegrane: %d" % [lg["name"], Save.duel_rating, Save.duel_best, Save.duel_wins, Save.duel_losses]
	menu_layer.visible = false
	rank_layer.move_to_front()
	rank_layer.visible = true


func _build_ranking() -> void:
	rank_layer = _overlay()
	var v := _vbox(_panel(rank_layer))
	v.add_theme_constant_override("separation", 12)
	v.add_child(_title("Ranga za postępy"))
	lbl_rank_name = _label(40, COL_ACCENT)
	lbl_rank_name.add_theme_font_override("font", Look.bold)
	lbl_rank_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_rank_name)
	lbl_rank_points = _label(30, COL_TEXT)
	lbl_rank_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_rank_points)
	rank_bar = ProgressBar.new()
	rank_bar.custom_minimum_size = Vector2(520, 26)
	rank_bar.show_percentage = false
	rank_bar.add_theme_stylebox_override("background", _box(Color("#2a3038"), Color("#3a414b"), 1))
	rank_bar.add_theme_stylebox_override("fill", _box(COL_ACCENT, COL_ACCENT, 0))
	v.add_child(rank_bar)
	lbl_rank_next = _label(22, COL_MUTED)
	lbl_rank_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_rank_next)
	rank_list = VBoxContainer.new()
	rank_list.add_theme_constant_override("separation", 4)
	v.add_child(rank_list)
	lbl_rank_stats = _label(22, COL_TEXT)
	lbl_rank_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_rank_stats)
	lbl_rank_duel = _label(24, Color("#ff8f8f"))
	lbl_rank_duel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_rank_duel)
	var info := _label(18, COL_MUTED)
	info.text = "Punkty: trudność poziomu × gwiazdki (+20% bez podpowiedzi).\nLiczy się najlepszy wynik każdego poziomu."
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var close := _button("Zamknij", func():
		rank_layer.visible = false
		show_menu())
	close.custom_minimum_size = Vector2(520, 90)
	v.add_child(close)


# ---------------------------------------------------------------- ankieta

func show_survey() -> void:
	survey_opened.emit()
	survey_answers = {}
	txt_liked.text = ""
	txt_improve.text = ""
	lbl_survey_err.text = ""
	_refresh_survey()
	menu_layer.visible = false
	prompt_layer.visible = false
	survey_layer.move_to_front()
	survey_layer.visible = true


func show_survey_prompt() -> void:
	prompt_layer.move_to_front()
	prompt_layer.visible = true


func _build_survey() -> void:
	star_gray = StarRow.texture(44, Color("#4a525e"))
	survey_layer = _overlay()
	(survey_layer as ColorRect).color = Color(0.03, 0.04, 0.06, 0.9)
	var v := _vbox(_panel(survey_layer))
	v.add_theme_constant_override("separation", 10)
	v.add_child(_title("Twoje wrażenia"))
	var info := _label(20, COL_MUTED)
	info.text = "6 krótkich pytań. Ankieta jest anonimowa\ni pomaga ulepszać grę."
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 760)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var q := VBoxContainer.new()
	q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q.add_theme_constant_override("separation", 10)
	scroll.add_child(q)

	q.add_child(_question("1. Jak oceniasz grę?"))
	var stars_row := HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	q.add_child(stars_row)
	for i in 5:
		var b := Button.new()
		b.flat = true
		b.icon = star_gray
		b.custom_minimum_size = Vector2(88, 72)
		b.expand_icon = false
		b.pressed.connect(func():
			Sfx.play("click")
			survey_answers["rating"] = i + 1
			_refresh_survey())
		stars_row.add_child(b)
		survey_stars.append(b)
	q.add_child(_question("2. Jak trudna jest gra?"))
	q.add_child(_choice_row("difficulty"))
	q.add_child(_question("3. Który tryb lubisz najbardziej?"))
	q.add_child(_choice_row("favorite_mode"))
	q.add_child(_question("4. Czy poleciłbyś grę znajomym?"))
	q.add_child(_choice_row("recommend"))
	q.add_child(_question("5. Co najbardziej Ci się podoba? (opcjonalnie)"))
	txt_liked = _text_box()
	q.add_child(txt_liked)
	q.add_child(_question("6. Co powinniśmy poprawić? (opcjonalnie)"))
	txt_improve = _text_box()
	q.add_child(txt_improve)
	var note := _label(18, COL_MUTED)
	note.text = "Nie wpisuj danych osobowych. Razem z odpowiedziami\nwysyłamy: wersję gry, postęp, czas gry, model telefonu\ni losowy identyfikator instalacji."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.add_child(note)

	lbl_survey_err = _label(22, COL_RED)
	lbl_survey_err.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_survey_err)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var cancel := _button("Anuluj", func():
		survey_layer.visible = false
		show_menu(), 24)
	cancel.custom_minimum_size = Vector2(0, 90)
	row.add_child(cancel)
	var send := _button("Wyślij", func(): _send_survey(), 26)
	send.custom_minimum_size = Vector2(0, 90)
	send.add_theme_stylebox_override("normal", _box(Color("#2b6e3f"), COL_GREEN, 3))
	row.add_child(send)


func _question(text: String) -> Label:
	var l := _label(24, COL_ACCENT)
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _choice_row(key: String) -> GridContainer:
	var row := GridContainer.new()
	row.columns = 2 if SURVEY_CHOICES[key].size() > 3 else SURVEY_CHOICES[key].size()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	survey_choice_buttons[key] = []
	for option in SURVEY_CHOICES[key]:
		var b := _button(option, func():
			survey_answers[key] = option
			_refresh_survey(), 20)
		b.custom_minimum_size = Vector2(0, 68)
		row.add_child(b)
		survey_choice_buttons[key].append(b)
	return row


func _text_box() -> TextEdit:
	var t := TextEdit.new()
	t.custom_minimum_size = Vector2(0, 110)
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	t.add_theme_font_size_override("font_size", 22)
	t.placeholder_text = "Napisz kilka słów…"
	return t


func _refresh_survey() -> void:
	var rating: int = survey_answers.get("rating", 0)
	for i in survey_stars.size():
		survey_stars[i].icon = star_icon_big() if i < rating else star_gray
	for key in survey_choice_buttons:
		var options: Array = SURVEY_CHOICES[key]
		for i in options.size():
			var b: Button = survey_choice_buttons[key][i]
			if survey_answers.get(key, "") == options[i]:
				b.add_theme_stylebox_override("normal", _box(Color("#1f4a5c"), Color("#4fd1ff"), 3))
				b.add_theme_color_override("font_color", Color("#4fd1ff"))
			else:
				b.remove_theme_stylebox_override("normal")
				b.remove_theme_color_override("font_color")


var _star_big: ImageTexture


func star_icon_big() -> ImageTexture:
	if _star_big == null:
		_star_big = StarRow.texture(44)
	return _star_big


func _send_survey() -> void:
	if not survey_answers.has("rating"):
		lbl_survey_err.text = "Zaznacz ocenę gwiazdkami (pytanie 1)"
		return
	for key in SURVEY_CHOICES:
		if not survey_answers.has(key):
			lbl_survey_err.text = "Odpowiedz na pytania 2–4"
			return
	var answers := survey_answers.duplicate()
	answers["liked"] = txt_liked.text.strip_edges().left(1000)
	answers["improve"] = txt_improve.text.strip_edges().left(1000)
	survey_layer.visible = false
	survey_submitted.emit(answers)


func _build_survey_prompt() -> void:
	prompt_layer = _overlay()
	var v := _vbox(_panel(prompt_layer))
	v.add_child(_title("Masz minutę?"))
	var t := _label(26, COL_TEXT)
	t.text = "Odpowiedz na 6 krótkich pytań o grę.\nKażda opinia pomaga ją ulepszyć."
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var yes := _button("Wypełnij ankietę", func(): show_survey())
	yes.custom_minimum_size = Vector2(460, 100)
	yes.add_theme_stylebox_override("normal", _box(Color("#2b6e3f"), COL_GREEN, 3))
	v.add_child(yes)
	var later := _button("Nie teraz", func(): prompt_layer.visible = false)
	later.custom_minimum_size = Vector2(460, 90)
	v.add_child(later)
	var info := _label(20, COL_MUTED)
	info.text = "Ankieta jest zawsze dostępna w menu."
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)


func _build_busy() -> void:
	busy_layer = _overlay()
	var v := _vbox(_panel(busy_layer))
	lbl_busy = _label(32, COL_TEXT)
	lbl_busy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_busy.custom_minimum_size = Vector2(440, 0)
	v.add_child(lbl_busy)


# ---------------------------------------------------------------- pomocnicze

func _set_hint_text(b: Button, hints: int) -> void:
	b.text = "Podpowiedź (%d)" % hints if hints > 0 else "Podpowiedź +"


func _bottom_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 20
	bar.offset_right = -20
	bar.offset_top = -132
	bar.offset_bottom = -28
	bar.add_theme_constant_override("separation", 12)
	root.add_child(bar)
	return bar


func _place_top_right(b: Control, right: float, width: float) -> void:
	b.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	b.offset_right = right
	b.offset_left = right - width
	b.offset_top = 20
	b.offset_bottom = 80


func _small_button(text: String, cb: Callable) -> Button:
	var b := _button(text, cb, 22)
	b.size_flags_horizontal = Control.SIZE_FILL
	b.custom_minimum_size = Vector2(0, 60)
	return b


func _overlay() -> Control:
	var layer := ColorRect.new()
	layer.color = Color(0.03, 0.04, 0.06, 0.78)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.visible = false
	root.add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	return layer


func _panel(layer: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := _box(COL_PANEL, COL_ACCENT, 4)
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	sb.shadow_size = 26
	sb.shadow_color = Color(1.0, 0.7, 0.15, 0.12)
	panel.add_theme_stylebox_override("panel", sb)
	layer.get_child(0).add_child(panel)
	return panel


func _vbox(parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(v)
	return v


func _title(text: String) -> Label:
	var l := _label(40, COL_TEXT)
	l.add_theme_font_override("font", Look.bold)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _button(text: String, cb: Callable, size: int = 28) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 100)  # duży cel dotyku
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	# Animacja wciśnięcia: przycisk lekko się zmniejsza i "odbija".
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	b.button_down.connect(func(): b.create_tween().tween_property(b, "scale", Vector2(0.94, 0.94), 0.06))
	b.button_up.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return b


func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(14)
	return sb


func _make_theme() -> Theme:
	var th := Theme.new()
	var normal := _box(Color("#323a45"), Color("#59636f"), 2)
	normal.border_width_bottom = 6
	normal.shadow_color = Color(0, 0, 0, 0.35)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 3)
	var hover := _box(Color("#3a4350"), Color("#6b7684"), 2)
	hover.border_width_bottom = 6
	var pressed := _box(Color("#272d35"), COL_ACCENT, 2)
	pressed.border_width_top = 6
	var disabled := _box(Color("#262b32"), Color("#3a414b"), 2)
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", disabled)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", COL_TEXT)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", COL_ACCENT)
	th.set_color("font_disabled_color", "Button", Color("#6b7380"))
	return th

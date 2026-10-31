extends CanvasLayer
## Interfejs: napisy, przyciski, okno sklepu, ekran wygranej, plansza "nowość",
## symulacja reklamy i ekran ładowania. Logika gry jest w main.gd - HUD tylko
## wyświetla i wysyła sygnały po naciśnięciu przycisków.

signal undo_pressed
signal restart_pressed
signal hint_pressed
signal next_pressed
signal sound_toggled
signal buy_pressed(product_id: String)
signal ad_pressed
signal level_chosen(level: int)

const COL_ACCENT := Color("#ffb627")
const COL_PANEL := Color("#1d2229")
const COL_TEXT := Color("#eef2f6")
const COL_MUTED := Color("#9aa5b1")

var lbl_title: Label
var lbl_info: Label
var lbl_badges: Label
var lbl_msg: Label
var btn_hint: Button
var btn_sound: Button
var win_layer: Control
var win_panel: PanelContainer
var lbl_win: Label
var shop_layer: Control
var lbl_shop_info: Label
var shop_buttons := {}
var intro_layer: Control
var lbl_intro_title: Label
var lbl_intro: Label
var busy_layer: Control
var level_layer: Control
var level_edit: LineEdit
var lbl_level_err: Label
var lbl_busy: Label
var msg_timer := 0.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)

	lbl_title = _label(44, COL_TEXT)
	lbl_title.position = Vector2(24, 18)
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

	btn_sound = _button("Dźwięk: wł.", func(): sound_toggled.emit(), 22)
	btn_sound.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	btn_sound.offset_left = -200
	btn_sound.offset_right = -24
	btn_sound.offset_top = 20
	btn_sound.offset_bottom = 80
	btn_sound.size_flags_horizontal = Control.SIZE_FILL
	btn_sound.custom_minimum_size = Vector2(176, 60)
	root.add_child(btn_sound)

	# Okno wyboru poziomu - TYLKO DO TESTÓW. Przycisk widać w edytorze i w wersjach
	# testowych (debug); w wersji wydawanej do sklepu (release) jest ukryty.
	if OS.is_debug_build():
		var btn_level := _button("Poziom", func(): show_level_picker(), 22)
		btn_level.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		btn_level.offset_left = -330
		btn_level.offset_right = -212
		btn_level.offset_top = 20
		btn_level.offset_bottom = 80
		btn_level.size_flags_horizontal = Control.SIZE_FILL
		btn_level.custom_minimum_size = Vector2(118, 60)
		root.add_child(btn_level)

	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 20
	bar.offset_right = -20
	bar.offset_top = -132
	bar.offset_bottom = -28
	bar.add_theme_constant_override("separation", 14)
	root.add_child(bar)
	bar.add_child(_button("Cofnij", func(): undo_pressed.emit()))
	bar.add_child(_button("Od nowa", func(): restart_pressed.emit()))
	btn_hint = _button("Podpowiedź", func(): hint_pressed.emit())
	btn_hint.add_theme_stylebox_override("normal", _box(Color("#3a3216"), COL_ACCENT, 3))
	bar.add_child(btn_hint)

	_build_win(root)
	_build_shop(root)
	_build_intro(root)
	_build_level_picker(root)
	_build_busy(root)


func _process(delta: float) -> void:
	if msg_timer > 0.0:
		msg_timer -= delta
		if msg_timer <= 0.0:
			lbl_msg.text = ""


# ---------------------------------------------------------------- API dla main.gd

func set_status(level: int, moves: int, limit: int, mods: Array, hints: int, sound_on: bool) -> void:
	lbl_title.text = "Zlecenie %d" % level
	if limit > 0:
		var left := limit - moves
		lbl_info.text = "Ruchy: %d / %d" % [moves, limit]
		lbl_info.add_theme_color_override("font_color", Color("#ff6b6b") if left <= 3 else COL_MUTED)
	else:
		lbl_info.text = "Ruchy: %d" % moves
		lbl_info.add_theme_color_override("font_color", COL_MUTED)
	var names := {"folia": "Folia stretch", "limit": "Limit ruchów", "cap5": "Palety na 5"}
	var b := PackedStringArray()
	for m in mods:
		b.append(names.get(m, m))
	lbl_badges.text = "  •  ".join(b)
	btn_hint.text = "Podpowiedź (%d)" % hints if hints > 0 else "Podpowiedź +"
	btn_sound.text = "Dźwięk: wł." if sound_on else "Dźwięk: wył."
	lbl_shop_info.text = "Masz podpowiedzi: %d" % hints


func show_msg(text: String, seconds: float = 3.0) -> void:
	lbl_msg.text = text
	msg_timer = seconds


func show_win(text: String) -> void:
	lbl_win.text = text
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
	shop_layer.visible = true


func show_intro(title: String, text: String) -> void:
	lbl_intro_title.text = title
	lbl_intro.text = text
	intro_layer.visible = true


func show_busy(text: String) -> void:
	lbl_busy.text = text
	busy_layer.visible = true


func hide_busy() -> void:
	busy_layer.visible = false


func is_modal_open() -> bool:
	return win_layer.visible or shop_layer.visible or intro_layer.visible or busy_layer.visible or level_layer.visible


func show_level_picker() -> void:
	lbl_level_err.text = ""
	level_edit.text = str(Save.level)
	level_layer.visible = true
	level_edit.grab_focus()
	level_edit.select_all()


# ---------------------------------------------------------------- budowa okien

func _build_win(root: Control) -> void:
	win_layer = _overlay(root)
	win_panel = _panel(win_layer)
	var v := _vbox(win_panel)
	lbl_win = _label(40, COL_TEXT)
	lbl_win.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_win)
	var next := _button("Następne zlecenie", func(): next_pressed.emit())
	next.custom_minimum_size = Vector2(440, 110)
	next.add_theme_stylebox_override("normal", _box(Color("#2b6e3f"), Color("#3ddc84"), 3))
	v.add_child(next)


func _build_shop(root: Control) -> void:
	shop_layer = _overlay(root)
	var panel := _panel(shop_layer)
	var v := _vbox(panel)
	var title := _label(40, COL_TEXT)
	title.text = "Podpowiedzi"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	lbl_shop_info = _label(26, COL_MUTED)
	lbl_shop_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_shop_info)
	var ad := _button("Obejrzyj reklamę: +1", func(): ad_pressed.emit())
	ad.custom_minimum_size = Vector2(480, 96)
	v.add_child(ad)
	for id in Store.PRODUCTS:
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


func _build_intro(root: Control) -> void:
	intro_layer = _overlay(root)
	var panel := _panel(intro_layer)
	var v := _vbox(panel)
	lbl_intro_title = _label(38, COL_ACCENT)
	lbl_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_intro_title)
	lbl_intro = _label(28, COL_TEXT)
	lbl_intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_intro.custom_minimum_size = Vector2(500, 0)
	v.add_child(lbl_intro)
	var ok := _button("Rozumiem", func(): intro_layer.visible = false)
	ok.custom_minimum_size = Vector2(440, 100)
	v.add_child(ok)


func _build_level_picker(root: Control) -> void:
	level_layer = _overlay(root)
	var panel := _panel(level_layer)
	var v := _vbox(panel)
	var title := _label(36, COL_ACCENT)
	title.text = "Wybór poziomu (test)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
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
	lbl_level_err = _label(22, Color("#ff6b6b"))
	lbl_level_err.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_level_err)
	var hint := _label(20, COL_MUTED)
	hint.text = "Nowości: 18 folia • 23 limit ruchów • 28 palety na 5"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var ok := _button("Zatwierdź", func(): _confirm_level())
	ok.custom_minimum_size = Vector2(460, 100)
	ok.add_theme_stylebox_override("normal", _box(Color("#2b6e3f"), Color("#3ddc84"), 3))
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
	level_chosen.emit(int(t))


func _build_busy(root: Control) -> void:
	busy_layer = _overlay(root)
	var panel := _panel(busy_layer)
	var v := _vbox(panel)
	lbl_busy = _label(32, COL_TEXT)
	lbl_busy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_busy.custom_minimum_size = Vector2(440, 0)
	v.add_child(lbl_busy)


# ---------------------------------------------------------------- pomocnicze

func _overlay(root: Control) -> Control:
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
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 32
	sb.content_margin_bottom = 32
	sb.shadow_size = 18
	sb.shadow_color = Color(0, 0, 0, 0.5)
	panel.add_theme_stylebox_override("panel", sb)
	layer.get_child(0).add_child(panel)
	return panel


func _vbox(parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(v)
	return v


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
	var hover := _box(Color("#3a4350"), Color("#6b7684"), 2)
	hover.border_width_bottom = 6
	var pressed := _box(Color("#272d35"), COL_ACCENT, 2)
	pressed.border_width_top = 6
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", COL_TEXT)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", COL_ACCENT)
	return th

extends SceneTree
## Film z rozgrywki do Google Play / YouTube (~25 s, 1080x1920, 30 kl./s) – nagrywany przez Godot Movie Maker.
## Uruchomienie (wymaga ekranu, np. xvfb-run):
##   godot --path . --resolution 1080x1920 --fixed-fps 30 --write-movie build/store/trailer.avi --script res://tools/store_trailer.gd
## Potem zamiana na MP4 (ffmpeg):
##   ffmpeg -y -i build/store/trailer.avi -c:v libx264 -pix_fmt yuv420p -crf 22 -movflags +faststart build/store/trailer.mp4

var main
var save


func _init() -> void:
	DirAccess.remove_absolute("user://save.cfg")
	await process_frame
	save = root.get_node("Save")
	save.load_data()
	save.sound_on = false
	save.seen_intros = ["program", "program_folia", "folia", "limit", "cap5", "chwytaki", "upadki"]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_hide_test_ui(main.hud)
	await _f(35)  # menu
	# Kampania: kilka ruchów robota w naturalnym tempie.
	save.level = 14
	main.hud.hide_menu()
	main._start_campaign()
	await _wait(func(): return main.level == 14)
	await _f(15)
	var plan = Solver.solve_short(main.board).moves
	for m in plan.slice(0, 4):
		await _move(m)
	# Programowanie: uruchomiony program.
	save.program = 12
	main._start_program_mode()
	await _wait(func(): return main.mode == "program" and main.prog.get("number", 0) == 12)
	for m in Solver.solve_optimal(main.board).moves:
		main.program.append(m)
		main._update_hud()
		await _f(3)
	main._on_prog_start()
	await _wait(func(): return main.prog_state != "run")
	await _f(40)  # ekran "Program działa!"
	main.hud.hide_win()
	# Pojedynek: odliczanie i wyścig z podglądem rywala.
	main._start_duel_ai()
	await _wait(func(): return main.duel.get("countdown", 1.0) <= 0.0)
	var dplan = Solver.solve_short(main.board).moves
	for m in dplan.slice(0, 3):
		await _move(m)
	main.duel["finished"] = true
	# Hala neonowa.
	save.unlock_pack("cosmetic_neon")
	for pair in [["boxes", "boxes_neon"], ["wall", "wall_neon"], ["robot", "robot_neon"], ["windows", "windows_night"], ["lights", "lights_led"], ["arm", "arm_two"]]:
		save.decor_selected[pair[0]] = pair[1]
	save.level = 9
	main._start_campaign()
	await _wait(func(): return main.level == 9)
	var p9 = Solver.solve_short(main.board).moves
	for m in p9.slice(0, 4):
		await _move(m)
	# Reszta zlecenia "za kulisami", na koniec ekran wygranej z gwiazdkami.
	for m in p9.slice(4):
		main._try_move(m[0], m[1])
		main.anim = {}
	main._on_level_complete()
	await _f(80)
	DirAccess.remove_absolute("user://save.cfg")
	quit()


## Ukrywa przyciski testowe (wybór poziomu, gwiazdki bez limitu) - nie powinny być w filmie.
func _hide_test_ui(node: Node) -> void:
	for c in node.get_children():
		if c is Button and (c.text == "Poziom" or c.text.begins_with("Test:") or c.has_meta("unlimited_toggle")):
			c.visible = false
		_hide_test_ui(c)


func _move(m: Array) -> void:
	if m[0] < 0:
		main._on_tool(m[1])
		await _f(10)
		return
	main._on_tap(main.stack_rects[m[0]].get_center())
	await _f(6)
	main._on_tap(main.stack_rects[m[1]].get_center())
	await _wait(func(): return main.anim.is_empty())
	await _f(4)


func _wait(cond):
	for i in 3000:
		await process_frame
		if cond.call():
			return


func _f(n):
	for i in n:
		await process_frame

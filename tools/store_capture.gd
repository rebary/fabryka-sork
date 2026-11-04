extends SceneTree
## Zrzuty ekranu do Google Play (1080x1920) prosto z gry - bez przycisków testowych.
## Uruchomienie (wymaga ekranu, np. xvfb-run):
##   godot --path . --resolution 1080x1920 --script res://tools/store_capture.gd
## Wynik: build/store/raw_1.png ... raw_6.png (podpisy dodaje tools/store_compose.py).

var main
var save
const OUT := "res://build/store/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.remove_absolute("user://save.cfg")
	await process_frame
	save = root.get_node("Save")
	save.load_data()
	save.seen_intros = ["program", "program_folia", "folia", "limit", "cap5", "chwytaki", "upadki"]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _f(6)
	_hide_test_ui()

	# 1. Kampania: robot przenosi paczki.
	save.level = 14
	main.hud.hide_menu()
	main._start_campaign()
	await _wait(func(): return main.level == 14)
	var plan = Solver.solve_short(main.board).moves
	for m in plan.slice(0, 5):
		main._try_move(m[0], m[1])
		main.anim = {}
	main._try_move(plan[5][0], plan[5][1])
	await _wait_anim(0.55)
	_save(1)

	# 2. Utrudnienia: folia i podpowiedź.
	main.anim = {}
	save.level = 47
	main._start_campaign()
	await _wait(func(): return main.level == 47)
	main._on_hint()
	await _f(20)
	_save(2)

	# 3. Programowanie robota (program z folią, część znana).
	save.program = 20
	main._start_program_mode()
	await _wait(func(): return main.mode == "program" and main.prog.get("number", 0) == 20)
	var opt = Solver.solve_optimal(main.board).moves
	for m in opt.slice(0, opt.size() - 2):
		main.program.append(m)
	main._update_hud()
	main._on_prog_start()
	await _wait(func(): return main.prog_index >= 3)
	await _wait_anim(0.5)
	_save(3)

	# 4. Pojedynek z rywalem - podgląd jego hali.
	main.prog_state = "edit"
	main._start_duel_ai()
	await _wait(func(): return main.duel.get("countdown", 1.0) <= 0.0)
	var dplan = Solver.solve_short(main.board).moves
	for m in dplan.slice(0, dplan.size() / 2):
		main._try_move(m[0], m[1])
		main.anim = {}
	for i in 420:
		await process_frame
	main._try_move(dplan[dplan.size() / 2][0], dplan[dplan.size() / 2][1])
	await _wait_anim(0.5)
	_save(4)

	# 5. Rozbudowana hala (pakiet Neon).
	main.duel["finished"] = true
	save.unlock_pack("cosmetic_neon")
	save.test_unlimited_stars = true
	for pair in [["boxes", "boxes_neon"], ["wall", "wall_neon"], ["robot", "robot_neon"], ["windows", "windows_night"], ["lights", "lights_led"], ["arm", "arm_two"]]:
		save.choose_decor(pair[0], pair[1])
	save.level = 33
	main._start_campaign()
	await _wait(func(): return main.level == 33)
	var p5 = Solver.solve_short(main.board).moves
	for m in p5.slice(0, 4):
		if m[0] < 0:
			main._on_tool(m[1])
		else:
			main._try_move(m[0], m[1])
			main.anim = {}
	await _f(30)
	_save(5)

	# 6. Wygrana: gwiazdki i awans (hala przyszłości).
	save.unlock_pack("cosmetic_future")
	save.unlock_pack("cosmetic_gala")
	for pair in [["boxes", "boxes_metal"], ["wall", "wall_future"], ["robot", "robot_gold"], ["windows", "windows_aurora"], ["floor", "floor_mirror"], ["lights", "lights_stage"], ["arm", "arm_robot"]]:
		save.choose_decor(pair[0], pair[1])
	for k in range(1, 9):
		save.points["c%d" % k] = 60
	save.level = 9
	main._start_campaign()
	await _wait(func(): return main.level == 9)
	for m in Solver.solve_short(main.board).moves:
		main._try_move(m[0], m[1])
		main.anim = {}
	main._on_level_complete()
	await _f(100)
	_save(6)
	save.test_unlimited_stars = false
	DirAccess.remove_absolute("user://save.cfg")
	print("zapisano zrzuty")
	quit()


func _hide_test_ui() -> void:
	for c in main.hud.root.get_children():
		if c is Button and c.text == "Poziom":
			c.visible = false


func _wait(cond):
	for i in 4000:
		await process_frame
		if cond.call():
			return


func _wait_anim(frac):
	for i in 2000:
		await process_frame
		if main.anim.is_empty():
			continue
		var u = (main.anim["e"] - main.anim["travel"]) / main.CARRY_TIME
		if u >= frac:
			return


func _f(n):
	for i in n:
		await process_frame


func _save(n: int) -> void:
	root.get_texture().get_image().save_png(OUT + "raw_%d.png" % n)

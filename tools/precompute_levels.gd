extends SceneTree
## Wylicza z góry zlecenia kampanii i programy i zapisuje je do res://data/levels.json.
## Dzięki temu telefon nie musi liczyć poziomów w trakcie gry.
## Uruchom PO KAŻDEJ zmianie w level_generator.gd (z folderu projektu):
##   godot --headless --script res://tools/precompute_levels.gd -- --campaign=150 --programs=60

func _init() -> void:
	var n_campaign := 150
	var n_programs := 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--campaign="):
			n_campaign = int(a.get_slice("=", 1))
		elif a.begins_with("--programs="):
			n_programs = int(a.get_slice("=", 1))
	var campaign: Array = []
	for n in range(1, n_campaign + 1):
		campaign.append(LevelGenerator.level_to_data(LevelGenerator.generate(n)))
		if n % 10 == 0:
			print("zlecenia: %d/%d" % [n, n_campaign])
	var programs: Array = []
	for n in range(1, n_programs + 1):
		programs.append(LevelGenerator.program_to_data(LevelGenerator.generate_program(n)))
		if n % 10 == 0:
			print("programy: %d/%d" % [n, n_programs])
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open("res://data/levels.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "campaign": campaign, "programs": programs}))
	f.close()
	print("Zapisano res://data/levels.json")
	quit()

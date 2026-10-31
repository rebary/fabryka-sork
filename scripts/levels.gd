extends Node
## Gotowe poziomy wyliczone z góry (autoload "Levels").
## Plik res://data/levels.json tworzy narzędzie tools/precompute_levels.gd.
## Poziomy spoza pliku są generowane w trakcie gry (w tle).

const PATH := "res://data/levels.json"

var campaign: Array = []  # indeks 0 = zlecenie 1
var programs: Array = []  # indeks 0 = program 1


func _ready() -> void:
	if not FileAccess.file_exists(PATH):
		push_warning("Brak pliku z gotowymi poziomami - wszystkie będą generowane w trakcie gry.")
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is Dictionary:
		campaign = data.get("campaign", [])
		programs = data.get("programs", [])


func has_level(n: int) -> bool:
	return n >= 1 and n <= campaign.size()


func get_level(n: int) -> Dictionary:
	return LevelGenerator.level_from_data(n, campaign[n - 1])


func has_program(n: int) -> bool:
	return n >= 1 and n <= programs.size()


func get_program(n: int) -> Dictionary:
	return LevelGenerator.program_from_data(n, programs[n - 1])

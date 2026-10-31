class_name HintWallet
extends RefCounted
## Licznik podpowiedzi gracza (bez zapisu na dysk - tym zajmuje się save_data.gd).

const START_HINTS := 3
const LEVELS_PER_FREE_HINT := 3

var hints: int = START_HINTS
var levels_completed: int = 0


func can_use() -> bool:
	return hints > 0


func use() -> bool:
	if hints <= 0:
		return false
	hints -= 1
	return true


func add(n: int) -> void:
	hints += maxi(0, n)


## Wywołaj po ukończeniu zlecenia. Zwraca liczbę podpowiedzi przyznanych w nagrodę.
func on_level_completed() -> int:
	levels_completed += 1
	if levels_completed % LEVELS_PER_FREE_HINT == 0:
		hints += 1
		return 1
	return 0


func to_dict() -> Dictionary:
	return {"hints": hints, "levels_completed": levels_completed}


func from_dict(d: Dictionary) -> void:
	hints = maxi(0, int(d.get("hints", START_HINTS)))
	levels_completed = maxi(0, int(d.get("levels_completed", 0)))

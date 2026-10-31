class_name LevelGenerator
extends RefCounted
## Generuje poziomy ("zlecenia"). Ten sam numer poziomu daje zawsze ten sam układ,
## więc każdy gracz widzi te same zlecenia, a ręczne projektowanie poziomów nie jest potrzebne.

const CAPACITY := 4
const EMPTY_STACKS := 2
const MIN_TYPES := 3
const MAX_TYPES := 8


## Trudność rośnie co 3 poziomy: więcej typów produktów = więcej palet.
static func params_for_level(level: int) -> Dictionary:
	var types := clampi(MIN_TYPES + floori((level - 1) / 3.0), MIN_TYPES, MAX_TYPES)
	return {"types": types, "capacity": CAPACITY, "empty": EMPTY_STACKS}


static func generate(level: int) -> Board:
	var p := params_for_level(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("fabryka_sort_%d" % level)
	var empty_count: int = p["empty"]
	var attempt := 0
	while true:
		attempt += 1
		# Po wielu nieudanych próbach dodajemy pustą paletę (łatwiejszy poziom).
		if attempt > 60:
			empty_count = p["empty"] + 1
		var board := _random_board(rng, p["types"], p["capacity"], empty_count)
		if _too_easy(board):
			continue
		if Solver.solve(board).ok:
			return board
		if attempt > 200:
			push_warning("LevelGenerator: brak rozwiązywalnego poziomu %d" % level)
			return board
	return null


static func _random_board(rng: RandomNumberGenerator, types: int, cap: int, empty_count: int) -> Board:
	var items: Array = []
	for t in types:
		for i in cap:
			items.append(t)
	# Tasowanie Fishera-Yatesa na własnym generatorze (powtarzalne dla danego seeda).
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp
	var stacks: Array = []
	for s in types:
		stacks.append(items.slice(s * cap, (s + 1) * cap))
	for e in empty_count:
		stacks.append([])
	return Board.new(stacks, cap)


## Odrzucamy układy, w których jakaś paleta jest już skompletowana na starcie.
static func _too_easy(board: Board) -> bool:
	for i in board.stacks.size():
		if board.is_stack_complete(i):
			return true
	return false

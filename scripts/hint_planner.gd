class_name HintPlanner
extends RefCounted
## Podpowiedzi bez chodzenia w kółko.
## 1) Plan: zapamiętujemy całe rozwiązanie. Jeśli gracz wykonał podpowiedziany ruch,
##    kolejna podpowiedź to następny krok TEGO SAMEGO planu.
## 2) Nowy plan nie może przechodzić przez układy, w których gracz już był w tym podejściu
##    (historia ruchów). Gdy bez powrotu nie da się wygrać - zwracamy pusty wynik,
##    a gra radzi cofnięcie ruchów.

var plan: Array = []
var plan_key := ""  # odcisk stanu, w którym ma być wykonany plan[0]


func reset() -> void:
	plan.clear()
	plan_key = ""


## board = aktualny stan; history = zapisy ruchów od początku podejścia (Board.undo);
## depth = ile ruchów zostało (limit), -1 = bez limitu.
## Zwraca {"move": [from, to]} albo {} (brak rozwiązania bez powrotu do starych układów).
func next_move(board: Board, history: Array, depth: int = -1, max_nodes: int = 40000) -> Dictionary:
	var fits := depth < 0 or plan.size() <= depth
	if not plan.is_empty() and fits and board.key() == plan_key:
		return _take(board)
	var r := Solver.solve(board, max_nodes, depth, visited_keys(board, history))
	if not r.ok or r.moves.is_empty():
		reset()
		return {}
	plan = r.moves.duplicate()
	plan_key = board.key()
	return _take(board)


func _take(board: Board) -> Dictionary:
	var m: Array = plan.pop_front()
	var b := board.clone()
	b.apply(m)
	plan_key = b.key()
	return {"move": m}


## Odciski wszystkich wcześniejszych układów z tego podejścia (bez bieżącego).
static func visited_keys(board: Board, history: Array) -> Dictionary:
	var keys := {}
	var b := board.clone()
	for i in range(history.size() - 1, -1, -1):
		b.undo(history[i])
		keys[b.key()] = true
	return keys

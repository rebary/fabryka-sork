class_name Solver
extends RefCounted
## Szuka rozwiązania planszy (przeszukiwanie w głąb z pamięcią odwiedzonych stanów).
## Zastosowania: sprawdzenie, czy poziom da się ułożyć, wyznaczenie limitu ruchów
## i podpowiedź dla gracza. Solver zna zawartość paczek w folii.
## Rozwiązanie NIE musi być najkrótsze, ale kolejność ruchów (najpierw "dokładanie"
## do tego samego produktu) zwykle daje krótkie rozwiązania.

const UNLIMITED := 1 << 30


## Zwraca {"ok": bool, "moves": Array of [from, to]}.
## max_depth = maksymalna liczba ruchów (-1 = bez limitu).
## ok = false: brak rozwiązania ALBO przekroczony limit węzłów (max_nodes).
static func solve(board: Board, max_nodes: int = 40000, max_depth: int = -1) -> Dictionary:
	var ctx := {"visited": {}, "nodes": 0, "max": max_nodes, "path": []}
	var depth := UNLIMITED if max_depth < 0 else max_depth
	var ok := _dfs(board.clone(), depth, ctx)
	return {"ok": ok, "moves": ctx["path"] if ok else []}


## Szuka możliwie krótkiego rozwiązania: najpierw dowolne, potem próbuje krótszych.
static func solve_short(board: Board, max_nodes: int = 40000) -> Dictionary:
	var best := solve(board, max_nodes)
	if not best.ok:
		return best
	for attempt in 3:
		var target := int(best.moves.size() * 0.85)
		if target < 1:
			break
		var r := solve(board, max_nodes, target)
		if not r.ok:
			break
		best = r
	return best


static func _dfs(b: Board, remaining: int, ctx: Dictionary) -> bool:
	if b.is_solved():
		return true
	if remaining <= 0:
		return false
	ctx["nodes"] += 1
	if ctx["nodes"] > ctx["max"]:
		return false
	var k := b.key()
	# Pomijamy stan, który już badaliśmy z co najmniej takim samym zapasem ruchów.
	if ctx["visited"].get(k, -1) >= remaining:
		return false
	ctx["visited"][k] = remaining

	for m in _ordered_moves(b):
		var rec := b.do_move(m[0], m[1])
		ctx["path"].append([m[0], m[1]])
		if _dfs(b, remaining - 1, ctx):
			return true
		ctx["path"].pop_back()
		b.undo(rec)
	return false


## Sensowne ruchy, posortowane od najbardziej obiecujących.
static func _ordered_moves(b: Board) -> Array:
	var good: Array = []
	var to_empty: Array = []
	for from in b.stacks.size():
		var src: Array = b.stacks[from]
		if src.is_empty() or b.is_stack_complete(from):
			continue
		var uniform: bool = b.top_run(from) == src.size()
		var tried_empty := false
		for to in b.stacks.size():
			if not b.can_move(from, to):
				continue
			if b.stacks[to].is_empty():
				# Przenoszenie jednolitej palety na pustą nic nie daje,
				# a wszystkie puste palety są równoważne.
				if uniform or tried_empty:
					continue
				tried_empty = true
				to_empty.append([from, to])
			else:
				good.append([from, to])
	return good + to_empty

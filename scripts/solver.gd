class_name Solver
extends RefCounted
## Szukanie rozwiązań planszy.
##  - solve():         przeszukiwanie w głąb - szybko znajduje JAKIEŚ rozwiązanie
##                     (sprawdzanie poziomów, podpowiedzi);
##  - solve_short():   próbuje skrócić znalezione rozwiązanie (wzorzec na 3 gwiazdki);
##  - solve_optimal(): przeszukiwanie wszerz - NAJKRÓTSZE rozwiązanie (małe plansze,
##                     tryb programowania).
## Ruch to [from, to] albo [-1, chwytak] (zmiana chwytaka). Solver zna zawartość folii.

const UNLIMITED := 1 << 30


static func solve(board: Board, max_nodes: int = 40000, max_depth: int = -1) -> Dictionary:
	var ctx := {"visited": {}, "nodes": 0, "max": max_nodes, "path": []}
	var depth := UNLIMITED if max_depth < 0 else max_depth
	var ok := _dfs(board.clone(), depth, ctx)
	return {"ok": ok, "moves": ctx["path"] if ok else []}


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


## Najkrótsze rozwiązanie (BFS). ok = false: brak albo przekroczony limit stanów.
static func solve_optimal(board: Board, max_states: int = 60000) -> Dictionary:
	var start := board.clone()
	if start.is_solved():
		return {"ok": true, "moves": []}
	var start_key := start.key()
	var parents := {start_key: null}
	var queue: Array = [[start, start_key]]
	var head := 0
	while head < queue.size():
		var b: Board = queue[head][0]
		var k: String = queue[head][1]
		head += 1
		for m in _ordered_moves(b):
			var nb := b.clone()
			nb.apply(m)
			var nk := nb.key()
			if parents.has(nk):
				continue
			parents[nk] = [k, m]
			if nb.is_solved():
				var moves: Array = []
				var cur := nk
				while parents[cur] != null:
					moves.push_front(parents[cur][1])
					cur = parents[cur][0]
				return {"ok": true, "moves": moves}
			if parents.size() > max_states:
				return {"ok": false, "moves": []}
			queue.append([nb, nk])
	return {"ok": false, "moves": []}


static func _dfs(b: Board, remaining: int, ctx: Dictionary) -> bool:
	if b.is_solved():
		return true
	if remaining <= 0:
		return false
	ctx["nodes"] += 1
	if ctx["nodes"] > ctx["max"]:
		return false
	var k := b.key()
	if ctx["visited"].get(k, -1) >= remaining:
		return false
	ctx["visited"][k] = remaining

	for m in _ordered_moves(b):
		var rec := b.apply(m)
		ctx["path"].append(m)
		if _dfs(b, remaining - 1, ctx):
			return true
		ctx["path"].pop_back()
		b.undo(rec)
	return false


## Sensowne ruchy, od najbardziej obiecujących: dokładanie do tego samego produktu,
## potem ruchy na pustą paletę, na końcu zmiany chwytaka.
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
			var n := b.move_count(from, to)
			if n == 0:
				continue
			if b.stacks[to].is_empty():
				# Przeniesienie CAŁEJ jednolitej palety na pustą nic nie daje,
				# a wszystkie puste palety są równoważne.
				if tried_empty or (uniform and n == src.size()):
					continue
				tried_empty = true
				to_empty.append([from, to])
			else:
				good.append([from, to])
	var tool_moves: Array = []
	for cap in b.tools:
		if cap != b.tool_cap:
			tool_moves.append([-1, cap])
	return good + to_empty + tool_moves

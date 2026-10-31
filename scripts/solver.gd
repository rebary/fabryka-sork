class_name Solver
extends RefCounted
## Szuka rozwiązania planszy (przeszukiwanie w głąb z pamięcią odwiedzonych stanów).
## Służy do: 1) sprawdzania, czy wygenerowany poziom da się ułożyć,
##           2) podpowiedzi dla gracza (pierwszy ruch z rozwiązania).
## Rozwiązanie NIE musi być najkrótsze - wystarczy, że istnieje.


## Zwraca {"ok": bool, "moves": Array of [from, to]}.
## ok = false oznacza: brak rozwiązania ALBO przekroczono limit węzłów (max_nodes).
static func solve(board: Board, max_nodes: int = 40000) -> Dictionary:
	var ctx := {"visited": {}, "nodes": 0, "max": max_nodes, "path": []}
	var ok := _dfs(board.clone(), ctx)
	return {"ok": ok, "moves": ctx["path"] if ok else []}


static func _dfs(b: Board, ctx: Dictionary) -> bool:
	if b.is_solved():
		return true
	ctx["nodes"] += 1
	if ctx["nodes"] > ctx["max"]:
		return false
	var k := b.key()
	if ctx["visited"].has(k):
		return false
	ctx["visited"][k] = true

	for from in b.stacks.size():
		var src: Array = b.stacks[from]
		if src.is_empty() or b.is_stack_complete(from):
			continue
		# Przenoszenie palety z jednym typem na pustą paletę nic nie zmienia.
		var uniform := b.top_run(from) == src.size()
		var tried_empty := false
		for to in b.stacks.size():
			if not b.can_move(from, to):
				continue
			if b.stacks[to].is_empty():
				# Wszystkie puste palety są równoważne - sprawdzamy tylko jedną.
				if uniform or tried_empty:
					continue
				tried_empty = true
			var n := b.apply_move(from, to)
			ctx["path"].append([from, to])
			if _dfs(b, ctx):
				return true
			ctx["path"].pop_back()
			b.undo_move(from, to, n)
	return false

extends SceneTree
## Pomiar wpływu utrudnień na trudność gry (te same plansze bazowe, różne utrudnienia).
## Uruchomienie: godot --headless --script res://tools/analyze_modifiers.gd -- --boards=24
##
## Mierzymy:
##  - ruchy "mądrego gracza" (pełna wiedza, plan jak solver) w porównaniu z planszą bazową;
##  - ruchy i cofnięcia "gracza z niepełną wiedzą" (zgaduje zawartość folii, przy pomyłce
##    planuje od nowa albo cofa) - tylko to oddaje trudność folii;
##  - odsetek ślepych zaułków "rozsądnie losowego" gracza (miara z generatora);
##  - częstość występowania utrudnień w zleceniach 1-150.

var rng := RandomNumberGenerator.new()


func _init() -> void:
	var n_boards := 24
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--boards="):
			n_boards = int(a.get_slice("=", 1))
	rng.seed = 2026
	var variants := {
		"bazowa": {}, "chwytaki": {"grip": true}, "palety_na_5": {"cap5": true},
		"folia_35%": {"wrap": 0.35}, "folia_60%": {"wrap": 0.6}, "folia_90%": {"wrap": 0.9},
	}
	var res := {}
	for v in variants:
		res[v] = {"smart": [], "belief": [], "undos": [], "dead": [], "fail": 0}
	for i in n_boards:
		var seed := 1000 + i
		for v in variants:
			var opt: Dictionary = variants[v]
			var b := _make_board(seed, opt)
			var r: Dictionary = res[v]
			r["smart"].append(_smart_moves(b))
			var dr := RandomNumberGenerator.new()
			dr.seed = seed
			r["dead"].append(LevelGenerator.difficulty_score(b, dr, 16))
			if opt.has("wrap"):
				var bl := _belief_player(b, seed)
				if bl["solved"]:
					r["belief"].append(bl["moves"])
					r["undos"].append(bl["undos"])
				else:
					r["fail"] += 1
	var base_smart := _avg(res["bazowa"]["smart"])
	print("\n=== WPŁYW UTRUDNIEŃ (%d plansz: 6 produktów, 2 puste palety) ===" % n_boards)
	print("wariant        | ruchy mądrego gracza | vs baza | ślepe zaułki (losowy) | gracz bez wiedzy: ruchy / cofnięcia / porażki")
	for v in variants:
		var r: Dictionary = res[v]
		var s := _avg(r["smart"])
		var line := "%-14s | %20.1f | %+6.0f%% | %20.0f%% |" % [v, s, 100.0 * (s / base_smart - 1.0), 100.0 * _avg(r["dead"])]
		if variants[v].has("wrap"):
			line += " %.1f / %.1f / %d z %d" % [_avg(r["belief"]), _avg(r["undos"]), r["fail"], n_boards]
		print(line)
	# Limit ruchów i śliskie paczki - wpływ liczony analitycznie.
	print("\nLimit ruchów: wzorzec + zapas (60%% na zleceniu 23 -> 15%% przy ~90). Mądry gracz ~%.0f ruchów -> limit %d..%d." % [base_smart, ceili(base_smart * 1.15), ceili(base_smart * 1.6)])
	for m in [20, 35, 50]:
		print("Śliskie paczki (4%%): przy %d ruchach P(co najmniej 1 upadek) = %.0f%%, średnio %.1f straconych ruchów" % [m, 100.0 * (1.0 - pow(0.96, m)), 0.04 * m])
	# Częstość w kampanii.
	var counts := {}
	var first := {}
	for level in range(1, 151):
		for mod in LevelGenerator.params_for_level(level)["mods"]:
			counts[mod] = counts.get(mod, 0) + 1
			if not first.has(mod):
				first[mod] = level
	print("\n=== CZĘSTOŚĆ W ZLECENIACH 1-150 (obecny kalendarz) ===")
	for mod in counts:
		print("%-10s pierwsze: %3d  liczba zleceń: %3d (%.0f%%)" % [mod, first[mod], counts[mod], 100.0 * counts[mod] / 150.0])
	quit()


func _make_board(seed: int, opt: Dictionary) -> Board:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var cap := 5 if opt.has("cap5") else 4
	var types := 5 if opt.has("cap5") else 6
	var b: Board
	while true:
		b = LevelGenerator._random_board(r, types, cap, 2)
		if LevelGenerator._too_easy(b):
			continue
		if opt.has("wrap"):
			LevelGenerator._wrap(b, r, opt["wrap"])
		if opt.has("grip"):
			b.tools = LevelGenerator.GRIP_TOOLS.duplicate()
			b.tool_cap = Board.TOOL_VACUUM
		if Solver.solve(b).ok:
			break
	return b


## Mądry gracz z pełną wiedzą: podąża za planem (jak podpowiedzi), liczymy ruchy.
func _smart_moves(board: Board) -> int:
	return Solver.solve_short(board).moves.size()


## Gracz z niepełną wiedzą: zakłada losową (zgodną z liczbami) zawartość folii, planuje,
## a gdy odsłonięta paczka okaże się inna - planuje od nowa; gdy plan nie istnieje - cofa ruch.
func _belief_player(board: Board, seed: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed * 7
	var real := board.clone()
	var hist: Array = []
	var moves := 0
	var undos := 0
	var plan: Array = []
	var belief := _guess(real, r)
	for step in 400:
		if real.is_solved():
			return {"solved": true, "moves": moves, "undos": undos}
		if plan.is_empty():
			var sol := Solver.solve(belief, 20000, -1, HintPlanner.visited_keys(real, hist))
			if not sol.ok or sol.moves.is_empty():
				if hist.is_empty():
					break
				real.undo(hist.pop_back())
				undos += 1
				moves += 1
				belief = _guess(real, r)
				continue
			plan = sol.moves
		var m: Array = plan.pop_front()
		var rec := real.apply(m)
		if rec.is_empty():
			plan.clear()
			belief = _guess(real, r)
			continue
		hist.append(rec)
		moves += 1
		belief.apply(m)
		# Czy odsłonięte paczki zgadzają się z przypuszczeniem?
		var mismatch := false
		for rv in rec[3]:
			if Board.type_of(belief.stacks[rv[0]][rv[1]]) != real.stacks[rv[0]][rv[1]]:
				mismatch = true
		if mismatch:
			plan.clear()
			belief = _guess(real, r)
	return {"solved": false, "moves": moves, "undos": undos}


## Plansza "w głowie gracza": paczki w folii dostają losowe typy zgodne z tym, co widać.
func _guess(real: Board, r: RandomNumberGenerator) -> Board:
	var b := real.clone()
	var visible := {}
	var total := {}
	var slots: Array = []
	for i in b.stacks.size():
		for k in b.stacks[i].size():
			var v: int = b.stacks[i][k]
			total[Board.type_of(v)] = b.capacity
			if v >= 0:
				visible[v] = visible.get(v, 0) + 1
			else:
				slots.append([i, k])
	var pool: Array = []
	for t in total:
		for c in total[t] - visible.get(t, 0):
			pool.append(t)
	for i in range(pool.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for idx in slots.size():
		var s: Array = slots[idx]
		b.stacks[s[0]][s[1]] = -int(pool[idx]) - 1
	return b


func _avg(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for x in a:
		s += float(x)
	return s / a.size()

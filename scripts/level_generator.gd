class_name LevelGenerator
extends RefCounted
## Generuje zlecenia (poziomy). Ten sam numer zlecenia daje zawsze ten sam układ.
##
## KRZYWA TRUDNOŚCI (wszystkie liczby można stroić w tym pliku):
##  - zlecenia 1-15: rośnie liczba produktów (3 -> 8), bez utrudnień;
##  - nowe utrudnienia pojawiają się stopniowo: folia (18), limit ruchów (23), palety na 5 (28);
##  - potem utrudnienia występują na przemian, a co pewien czas łączą się po dwa;
##  - co 5. zlecenie (od 10.) jest "przerwą": łatwiejsze, bez utrudnień;
##  - z kilku losowych kandydatów wybieramy ten, którego zmierzona trudność
##    jest najbliższa celowi dla danego zlecenia.

const MOD_WRAP := "folia"
const MOD_LIMIT := "limit"
const MOD_CAP5 := "cap5"
const INTRO_LEVEL := {MOD_WRAP: 18, MOD_LIMIT: 23, MOD_CAP5: 28}

const CANDIDATES := 3
const PLAYOUTS := 12


static func params_for_level(level: int) -> Dictionary:
	var p := {
		"level": level,
		"types": clampi(3 + floori((level - 1) / 2.5), 3, 8),
		"capacity": 4,
		"empty": 2,
		"mods": [],
		"intro": "",  # utrudnienie pokazywane po raz pierwszy
		"wrap_fraction": 0.0,
		"limit_slack": 0.0,
		"target": 0.1 + 0.3 * clampf((level - 1) / 15.0, 0.0, 1.0),
		"breather": false,
	}
	if level >= 10 and level % 5 == 0:
		p["breather"] = true
		p["types"] = maxi(4, p["types"] - 2)
		p["target"] = 0.15
		return p
	if level < 16:
		return p

	# Natężenie utrudnień rośnie powoli od 0 (zlecenie 16) do 1 (zlecenie ~90).
	var t := clampf((level - 16) / 75.0, 0.0, 1.0)
	p["target"] = lerpf(0.35, 0.75, t)
	p["wrap_fraction"] = lerpf(0.35, 0.9, t)
	p["limit_slack"] = lerpf(0.6, 0.15, t)

	var mods: Array = []
	for m in INTRO_LEVEL:
		if level == INTRO_LEVEL[m]:
			mods = [m]
			p["intro"] = m
	if mods.is_empty():
		var available: Array = []
		for m in [MOD_WRAP, MOD_LIMIT, MOD_CAP5]:
			if level > INTRO_LEVEL[m]:
				available.append(m)
		if level <= INTRO_LEVEL[MOD_CAP5] + 2:
			# Faza wprowadzania: na przemian "bez utrudnień" i poznane utrudnienia.
			var options: Array = [null] + available
			var pick = options[level % options.size()]
			if pick != null:
				mods = [pick]
		else:
			# Faza pełna: cykl 4 zleceń - trzy pojedyncze utrudnienia i jedna para.
			match level % 4:
				0:
					mods = [MOD_WRAP]
				1:
					mods = [MOD_LIMIT]
				2:
					mods = [MOD_CAP5]
				3:
					var pairs := [[MOD_WRAP, MOD_LIMIT], [MOD_CAP5, MOD_WRAP], [MOD_CAP5, MOD_LIMIT]]
					mods = pairs[floori(level / 4.0) % 3]
	p["mods"] = mods
	if mods.has(MOD_CAP5):
		p["capacity"] = 5
		p["types"] = maxi(5, p["types"] - 1)
	# Przy wprowadzaniu nowości łagodniej.
	if p["intro"] != "":
		p["target"] = 0.3
		p["wrap_fraction"] = 0.35
		p["limit_slack"] = 0.6
	return p


## Zwraca {"board": Board, "params": Dictionary, "move_limit": int (0 = brak), "difficulty": float}.
static func generate(level: int) -> Dictionary:
	var p := params_for_level(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("fabryka_sort_%d" % level)
	var mods: Array = p["mods"]
	var best: Board = null
	var best_score := 0.0
	var found := 0
	var attempt := 0
	while found < CANDIDATES and attempt < 300:
		attempt += 1
		var empty_count: int = p["empty"] + (1 if attempt > 150 else 0)
		var b := _random_board(rng, p["types"], p["capacity"], empty_count)
		if _too_easy(b):
			continue
		if mods.has(MOD_WRAP):
			_wrap(b, rng, p["wrap_fraction"])
		if not Solver.solve(b).ok:
			continue
		found += 1
		var score := difficulty_score(b, rng, PLAYOUTS)
		if best == null or absf(score - p["target"]) < absf(best_score - p["target"]):
			best = b
			best_score = score
	if best == null:
		push_warning("LevelGenerator: brak rozwiązywalnego poziomu %d" % level)
		best = _random_board(rng, p["types"], p["capacity"], p["empty"] + 2)
	var limit := 0
	if mods.has(MOD_LIMIT):
		var r := Solver.solve_short(best)
		var n: int = r.moves.size()
		limit = n + maxi(2, ceili(n * float(p["limit_slack"])))
	return {"board": best, "params": p, "move_limit": limit, "difficulty": best_score}


## Trudność 0..1 = jak często "rozsądnie losowy" gracz trafia w ślepy zaułek.
static func difficulty_score(board: Board, rng: RandomNumberGenerator, playouts: int) -> float:
	var fails := 0
	for p in playouts:
		var b := board.clone()
		var last := [-1, -1]
		var solved := false
		for step in 150:
			if b.is_solved():
				solved = true
				break
			var good: Array = []
			var other: Array = []
			for from in b.stacks.size():
				if b.stacks[from].is_empty() or b.is_stack_complete(from):
					continue
				var uniform: bool = b.top_run(from) == b.stacks[from].size()
				for to in b.stacks.size():
					if not b.can_move(from, to) or (from == last[1] and to == last[0]):
						continue
					if b.stacks[to].is_empty():
						if not uniform:
							other.append([from, to])
					else:
						good.append([from, to])
			if good.is_empty() and other.is_empty():
				break
			var pool := good if not good.is_empty() and rng.randf() < 0.75 else (other if not other.is_empty() else good)
			var m: Array = pool[rng.randi_range(0, pool.size() - 1)]
			b.do_move(m[0], m[1])
			last = m
		if not solved:
			fails += 1
	return fails / float(playouts)


static func _random_board(rng: RandomNumberGenerator, types: int, cap: int, empty_count: int) -> Board:
	var items: Array = []
	for t in types:
		for i in cap:
			items.append(t)
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


## Owija folią część paczek (nigdy górnej - ta zawsze jest widoczna).
static func _wrap(b: Board, rng: RandomNumberGenerator, fraction: float) -> void:
	for s in b.stacks:
		for k in range(s.size() - 1):
			if rng.randf() < fraction:
				s[k] = -s[k] - 1


static func _too_easy(board: Board) -> bool:
	for i in board.stacks.size():
		if board.is_stack_complete(i):
			return true
	return false

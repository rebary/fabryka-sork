class_name LevelGenerator
extends RefCounted
## Generuje zlecenia kampanii i programy (tryb programowania).
## Ten sam numer daje zawsze ten sam układ.
##
## KRZYWA TRUDNOŚCI KAMPANII (wszystkie liczby można stroić w tym pliku):
##  - zlecenia 1-15: rośnie liczba produktów (3 -> 8), bez utrudnień;
##  - nowości pojawiają się stopniowo: folia (18), limit ruchów (23), palety na 5 (28),
##    wymiana chwytaków (33);
##  - potem utrudnienia występują na przemian, czasem po dwa naraz;
##  - co 5. zlecenie (od 10.) jest "przerwą": łatwiejsze, bez utrudnień;
##  - z kilku losowych kandydatów wybieramy ten o trudności najbliższej celowi.

const MOD_WRAP := "folia"
const MOD_LIMIT := "limit"
const MOD_CAP5 := "cap5"
const MOD_GRIP := "chwytaki"
const ALL_MODS := [MOD_WRAP, MOD_LIMIT, MOD_CAP5, MOD_GRIP]
const INTRO_LEVEL := {MOD_WRAP: 18, MOD_LIMIT: 23, MOD_CAP5: 28, MOD_GRIP: 33}
const PAIRS := [[MOD_WRAP, MOD_LIMIT], [MOD_CAP5, MOD_WRAP], [MOD_CAP5, MOD_LIMIT], [MOD_GRIP, MOD_LIMIT], [MOD_GRIP, MOD_WRAP]]
const GRIP_TOOLS := [Board.TOOL_VACUUM, 2, 1]

const CANDIDATES := 3
const PLAYOUTS := 12


static func params_for_level(level: int) -> Dictionary:
	var p := {
		"level": level,
		"types": clampi(3 + floori((level - 1) / 2.5), 3, 8),
		"capacity": 4,
		"empty": 2,
		"mods": [],
		"intro": "",
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
		var last_intro: int = INTRO_LEVEL[MOD_GRIP]
		if level <= last_intro + 2:
			# Faza wprowadzania: na przemian "bez utrudnień" i poznane utrudnienia.
			var options: Array = [null]
			for m in ALL_MODS:
				if level > INTRO_LEVEL[m]:
					options.append(m)
			var pick = options[level % options.size()]
			if pick != null:
				mods = [pick]
		else:
			# Faza pełna: cykl 6 zleceń - cztery pojedyncze utrudnienia, para i "czyste".
			match level % 6:
				0, 1, 2, 3:
					mods = [ALL_MODS[level % 6]]
				4:
					mods = PAIRS[floori(level / 6.0) % PAIRS.size()]
				5:
					mods = []
	p["mods"] = mods
	if mods.has(MOD_CAP5):
		p["capacity"] = 5
		p["types"] = maxi(5, p["types"] - 1)
	if mods.has(MOD_GRIP):
		p["types"] = maxi(5, p["types"] - 1)
	if p["intro"] != "":
		p["target"] = 0.3
		p["wrap_fraction"] = 0.35
		p["limit_slack"] = 0.6
	return p


## Zwraca {"board", "params", "move_limit" (0 = brak), "par" (wzorzec ruchów), "difficulty"}.
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
		if mods.has(MOD_GRIP):
			b.tools = GRIP_TOOLS.duplicate()
			b.tool_cap = Board.TOOL_VACUUM
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
	var r := Solver.solve_short(best)
	var par: int = r.moves.size() if r.ok else 0
	var limit := 0
	if mods.has(MOD_LIMIT):
		limit = par + maxi(2, ceili(par * float(p["limit_slack"])))
	return {"board": best, "params": p, "move_limit": limit, "par": par, "difficulty": best_score}


## Gwiazdki za wynik (3 = co najwyżej wzorzec ruchów).
static func stars_for(moves: int, par: int) -> int:
	if par <= 0 or moves <= par:
		return 3
	if moves <= par + maxi(2, ceili(par * 0.25)):
		return 2
	return 1


# ---------------------------------------------------------------- zapis do pliku danych

## Zamiana wygenerowanego zlecenia/programu na dane JSON i z powrotem
## (gotowe poziomy są wyliczane z góry narzędziem tools/precompute_levels.gd).
static func board_to_data(b: Board) -> Dictionary:
	return {"s": b.stacks, "c": b.capacity, "t": b.tools, "tc": b.tool_cap}


static func board_from_data(d: Dictionary) -> Board:
	var stacks: Array = []
	for s in d["s"]:
		var st: Array = []
		for v in s:
			st.append(int(v))
		stacks.append(st)
	var tools: Array = []
	for t in d.get("t", []):
		tools.append(int(t))
	return Board.new(stacks, int(d["c"]), tools, int(d.get("tc", 0)))


static func level_to_data(g: Dictionary) -> Dictionary:
	return {"b": board_to_data(g["board"]), "limit": g["move_limit"], "par": g["par"], "diff": snappedf(g["difficulty"], 0.01)}


static func level_from_data(level: int, d: Dictionary) -> Dictionary:
	return {"board": board_from_data(d["b"]), "params": params_for_level(level), "move_limit": int(d["limit"]),
		"par": int(d["par"]), "difficulty": float(d["diff"])}


static func program_to_data(g: Dictionary) -> Dictionary:
	return {"b": board_to_data(g["board"]), "opt": g["optimal"], "max": g["max_steps"]}


static func program_from_data(number: int, d: Dictionary) -> Dictionary:
	return {"board": board_from_data(d["b"]), "optimal": int(d["opt"]), "max_steps": int(d["max"]), "number": number}


# ---------------------------------------------------------------- tryb programowania

## Program (poziom trybu programowania): mała plansza (palety na 3), znane najkrótsze rozwiązanie.
## Zwraca {"board", "optimal" (liczba kroków), "max_steps", "number"}.
static func generate_program(number: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("fabryka_program_%d" % number)
	var types := clampi(2 + floori((number + 1) / 3.0), 3, 5)
	var lo := clampi(3 + floori(number / 3.0), 3, 10)
	var hi := lo + 2
	var empty_count := 2 if number < 12 else 1
	var best: Board = null
	var best_len := 0
	for attempt in 120:
		var b := _random_board(rng, types, 3, empty_count)
		if _too_easy(b):
			continue
		var r := Solver.solve_optimal(b, 40000)
		if not r.ok:
			continue
		var n: int = r.moves.size()
		if n >= lo and n <= hi:
			best = b
			best_len = n
			break
		if best == null or absi(n - lo) < absi(best_len - lo):
			best = b
			best_len = n
	if best == null:
		best = _random_board(rng, 3, 3, 2)
		best_len = Solver.solve_optimal(best).moves.size()
	var slack := 2 if number < 10 else 1
	return {"board": best, "optimal": best_len, "max_steps": best_len + slack, "number": number}


static func program_stars(steps: int, optimal: int) -> int:
	if steps <= optimal:
		return 3
	if steps <= optimal + 1:
		return 2
	return 1


# ---------------------------------------------------------------- pomocnicze

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
					if b.move_count(from, to) == 0 or (from == last[1] and to == last[0]):
						continue
					if b.stacks[to].is_empty():
						if not uniform:
							other.append([from, to])
					else:
						good.append([from, to])
			if good.is_empty() and other.is_empty():
				# Z chwytakami: spróbuj zmienić narzędzie, zanim uznasz ślepy zaułek.
				var switched := false
				for cap in b.tools:
					if cap != b.tool_cap:
						b.do_tool(cap)
						switched = true
						break
				if switched and step < 149:
					continue
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

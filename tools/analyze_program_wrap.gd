extends SceneTree
## Ile uruchomień potrzebuje gracz w programach z folią, gdy układa program "w ciemno"?
## Model: gracz zgaduje zawartość folii (zgodnie z tym, co widać), układa najkrótszy program
## dla swojego przypuszczenia, uruchamia. Robot odsłania paczki; przy błędzie lub porażce gracz
## zapamiętuje odsłonięte paczki i układa program od nowa. Liczymy uruchomienia do sukcesu.
## Uruchomienie: godot --headless --script res://tools/analyze_program_wrap.gd

func _init() -> void:
	print("program | produkty | w folii | najkrótszy | uruchomienia (śr./max) | program dłuższy niż najkrótszy o")
	for n in [10, 20, 30, 40, 50, 60]:
		var g := LevelGenerator.generate_program(n)
		var b: Board = g.board
		var runs_all: Array = []
		var extra_all: Array = []
		for trial in 20:
			var r := _blind_player(b, 100 + trial)
			runs_all.append(r["runs"])
			extra_all.append(r["len"] - g.optimal)
		var mx := 0
		var sum := 0.0
		var ex := 0.0
		for x in runs_all:
			sum += x
			mx = maxi(mx, x)
		for x in extra_all:
			ex += x
		print("%7d | %8d | %7d | %10d | %10.1f / %d | %.1f kroku" % [n, b.stacks.size() - LevelGenerator.program_params(n)["empty"], b.wrapped_count(), g.optimal, sum / runs_all.size(), mx, ex / extra_all.size()])
	quit()


func _blind_player(real_start: Board, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var known := {}  # pozycje startowe odsłonięte w poprzednich uruchomieniach -> typ
	for run in range(1, 15):
		var guess := _guess(real_start, known, rng)
		var plan := Solver.solve_optimal(guess, 30000)
		if not plan.ok:
			continue
		# Uruchom plan na prawdziwej planszy.
		var b := real_start.clone()
		var ok := true
		for m in plan.moves:
			var rec := b.do_move(m[0], m[1])
			if rec.is_empty():
				ok = false
				break
			for rv in rec[3]:
				known[str(rv[0]) + ":" + str(rv[1])] = b.stacks[rv[0]][rv[1]]
		if ok and b.is_solved():
			return {"runs": run, "len": plan.moves.size()}
	return {"runs": 15, "len": 99}


func _guess(real: Board, known: Dictionary, rng: RandomNumberGenerator) -> Board:
	var b := real.clone()
	var visible := {}
	var slots: Array = []
	for i in b.stacks.size():
		for k in b.stacks[i].size():
			var v: int = b.stacks[i][k]
			var key := str(i) + ":" + str(k)
			if v >= 0:
				visible[v] = visible.get(v, 0) + 1
			elif known.has(key):
				visible[int(known[key])] = visible.get(int(known[key]), 0) + 1
			else:
				slots.append([i, k])
	var pool: Array = []
	var types := {}
	for st in b.stacks:
		for v in st:
			types[Board.type_of(v)] = true
	for t in types:
		for c in b.capacity - visible.get(t, 0):
			pool.append(t)
	pool.shuffle()
	for i in b.stacks.size():
		for k in b.stacks[i].size():
			var key := str(i) + ":" + str(k)
			if known.has(key) and b.stacks[i][k] < 0:
				b.stacks[i][k] = -int(known[key]) - 1  # znany typ, nadal w folii (zasady bez zmian)
	for idx in slots.size():
		var sp: Array = slots[idx]
		b.stacks[sp[0]][sp[1]] = -int(pool[idx]) - 1
	return b

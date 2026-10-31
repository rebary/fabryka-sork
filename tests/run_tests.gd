extends SceneTree
## Testy logiki gry. Uruchomienie (z folderu projektu):
##   godot --headless --script res://tests/run_tests.gd
## Opcjonalnie liczba sprawdzanych zleceń:  -- --levels=90

var failures := 0
var checks := 0


func _init() -> void:
	var levels := 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--levels="):
			levels = int(a.get_slice("=", 1))
	test_move_rules()
	test_undo()
	test_solved()
	test_wrapped()
	test_depth_limit()
	test_wallet()
	test_generator(levels)
	print("Sprawdzeń: %d, błędów: %d" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("BŁĄD: " + msg)


func test_move_rules() -> void:
	var b := Board.new([[0, 1, 1], [1], [], [0, 0, 0, 0]], 4)
	check(b.top_run(0) == 2, "top_run liczy górny ciąg")
	check(b.can_move(0, 1), "ruch na ten sam typ")
	check(b.move_count(0, 1) == 2, "przenosi cały ciąg")
	check(b.can_move(0, 2), "ruch na pustą paletę")
	check(not b.can_move(1, 3), "brak ruchu na pełną paletę")
	check(not b.can_move(2, 0), "brak ruchu z pustej palety")
	check(not b.can_move(0, 0), "brak ruchu na siebie")
	var b2 := Board.new([[1, 1, 1], [0, 0, 1]], 4)
	check(b2.move_count(0, 1) == 1, "przenosi tylko tyle, ile się zmieści")


func test_undo() -> void:
	var b := Board.new([[0, 1, 1], [1], []], 4)
	var before := b.key()
	var rec := b.do_move(0, 1)
	check(rec.size() == 4 and rec[2] == 2 and b.stacks[1].size() == 3, "do_move")
	b.undo(rec)
	check(b.key() == before, "undo przywraca stan")
	check(b.do_move(2, 0).is_empty(), "niedozwolony ruch zwraca pusty zapis")


func test_solved() -> void:
	check(Board.new([[0, 0, 0, 0], [], [1, 1, 1, 1]], 4).is_solved(), "ułożona plansza")
	check(not Board.new([[0, 0, 0], [0], []], 4).is_solved(), "nieukończona plansza")


func test_wrapped() -> void:
	# Paleta 0: dół = produkt 1 w folii (-2), góra = produkt 0.
	var b := Board.new([[-2, 0], [0], []], 4)
	check(b.top_run(0) == 1, "folia przerywa ciąg")
	check(b.wrapped_count() == 1, "liczenie paczek w folii")
	var before := b.key()
	var rec := b.do_move(0, 1)
	check(b.stacks[0][0] == 1, "paczka odsłania się na górze")
	b.undo(rec)
	check(b.key() == before and b.stacks[0][0] == -2, "cofnięcie ponownie owija paczkę")
	# Paczka w folii na górze nie może być przeniesiona (nie powinna wystąpić, ale zabezpieczenie).
	check(not Board.new([[-1], []], 4).can_move(0, 1), "brak ruchu paczką w folii")
	# Skompletowanie palety odsłania całą paletę.
	var c := Board.new([[-1, -1, 0], [0], []], 4)
	c.do_move(1, 0)
	check(c.is_stack_complete(0) and c.wrapped_count() == 0, "skompletowana paleta odsłonięta")


func test_depth_limit() -> void:
	var b := Board.new([[0, 1], [1, 0], []], 2)
	var r := Solver.solve(b)
	check(r.ok, "plansza rozwiązywalna")
	check(not Solver.solve(b, 40000, 1).ok, "limit 1 ruchu za mały")
	check(Solver.solve(b, 40000, r.moves.size()).ok, "limit równy długości rozwiązania wystarcza")


func test_wallet() -> void:
	var w := HintWallet.new()
	check(w.hints == HintWallet.START_HINTS, "podpowiedzi startowe")
	for i in HintWallet.START_HINTS:
		check(w.use(), "zużycie podpowiedzi")
	check(not w.use() and w.hints == 0, "brak podpowiedzi poniżej zera")
	var bonus := 0
	for i in HintWallet.LEVELS_PER_FREE_HINT:
		bonus += w.on_level_completed()
	check(bonus == 1 and w.hints == 1, "nagroda za ukończone zlecenia")
	w.add(5)
	var w2 := HintWallet.new()
	w2.from_dict(w.to_dict())
	check(w2.hints == 6 and w2.levels_completed == HintWallet.LEVELS_PER_FREE_HINT, "zapis i odczyt licznika")


func test_generator(levels: int) -> void:
	var worst_ms := 0
	var worst_level := 0
	var report := PackedStringArray()
	for level in range(1, levels + 1):
		var t0 := Time.get_ticks_msec()
		var g := LevelGenerator.generate(level)
		var dt := Time.get_ticks_msec() - t0
		if dt > worst_ms:
			worst_ms = dt
			worst_level = level
		var b: Board = g.board
		var p: Dictionary = g.params
		var counts := {}
		for s in b.stacks:
			check(s.size() <= b.capacity, "poziom %d: paleta nie przepełniona" % level)
			if not s.is_empty():
				check(s.back() >= 0, "poziom %d: górna paczka widoczna" % level)
			for v in s:
				var t := Board.type_of(v)
				counts[t] = counts.get(t, 0) + 1
		check(counts.size() == p["types"], "poziom %d: liczba typów" % level)
		for v in counts:
			check(counts[v] == b.capacity, "poziom %d: typ %d ma pełny komplet" % [level, v])
		check(not b.is_solved(), "poziom %d nie jest ułożony na starcie" % level)
		check(LevelGenerator.generate(level).board.key() == b.key(), "poziom %d powtarzalny" % level)
		check(p["mods"].has("folia") == (b.wrapped_count() > 0), "poziom %d: folia tylko gdy włączona" % level)
		check(p["mods"].has("cap5") == (b.capacity == 5), "poziom %d: palety na 5 tylko gdy włączone" % level)
		check(p["mods"].has("limit") == (g.move_limit > 0), "poziom %d: limit tylko gdy włączony" % level)
		# Rozwiązanie istnieje i mieści się w limicie ruchów.
		var r := Solver.solve(b, 40000, g.move_limit if g.move_limit > 0 else -1)
		check(r.ok, "poziom %d rozwiązywalny (w limicie)" % level)
		var c := b.clone()
		for m in r.moves:
			check(not c.do_move(m[0], m[1]).is_empty(), "poziom %d: ruch solvera dozwolony" % level)
		check(c.is_solved(), "poziom %d: rozwiązanie solvera układa planszę" % level)
		report.append("%d:%s%s d=%.2f" % [level, ",".join(p["mods"]), " L%d" % g.move_limit if g.move_limit > 0 else "", g.difficulty])
	print("Zlecenia: ", " | ".join(report))
	print("Najwolniejsze generowanie: %d ms (zlecenie %d)" % [worst_ms, worst_level])

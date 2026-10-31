extends SceneTree
## Testy logiki gry. Uruchomienie (z folderu projektu):
##   godot --headless --script res://tests/run_tests.gd

var failures := 0
var checks := 0


func _init() -> void:
	test_move_rules()
	test_undo()
	test_solved()
	test_generator_and_solver()
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
	var n := b.apply_move(0, 1)
	check(n == 2 and b.stacks[1].size() == 3, "apply_move")
	b.undo_move(0, 1, n)
	check(b.key() == before, "undo przywraca stan")


func test_solved() -> void:
	check(Board.new([[0, 0, 0, 0], [], [1, 1, 1, 1]], 4).is_solved(), "ułożona plansza")
	check(not Board.new([[0, 0, 0], [0], []], 4).is_solved(), "nieukończona plansza")


func test_generator_and_solver() -> void:
	var worst_ms := 0
	for level in range(1, 31):
		var t0 := Time.get_ticks_msec()
		var b := LevelGenerator.generate(level)
		worst_ms = maxi(worst_ms, Time.get_ticks_msec() - t0)
		var p := LevelGenerator.params_for_level(level)
		var counts := {}
		for s in b.stacks:
			for v in s:
				counts[v] = counts.get(v, 0) + 1
		check(counts.size() == p["types"], "poziom %d: liczba typów" % level)
		for v in counts:
			check(counts[v] == p["capacity"], "poziom %d: typ %d ma pełny komplet" % [level, v])
		check(not b.is_solved(), "poziom %d nie jest ułożony na starcie" % level)
		# Ten sam numer poziomu = ten sam układ.
		check(LevelGenerator.generate(level).key() == b.key(), "poziom %d powtarzalny" % level)
		# Rozwiązanie solvera faktycznie układa planszę.
		var r := Solver.solve(b)
		check(r.ok, "poziom %d rozwiązywalny" % level)
		var c := b.clone()
		for m in r.moves:
			check(c.apply_move(m[0], m[1]) > 0, "poziom %d: ruch solvera dozwolony" % level)
		check(c.is_solved(), "poziom %d: rozwiązanie solvera układa planszę" % level)
	print("Najwolniejsze generowanie poziomu: %d ms" % worst_ms)

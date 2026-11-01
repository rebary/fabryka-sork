class_name Rival
extends RefCounted
## Rywal komputerowy w pojedynku: gra na własnej kopii planszy, w swoim tempie,
## czasem robi zbędny ruch (im słabszy, tym częściej), potem wraca do planu.

var board: Board
var info: Dictionary
var interval := 3.0
var mistake := 0.2
var moves := 0
var done := false
var exact := false  # symulacja tempa znajomego: stały plan i równe tempo (bez losowości)
var _plan: Array = []
var _timer := 0.0
var _rng := RandomNumberGenerator.new()


func _init(start: Board, rival_info: Dictionary, seed: int) -> void:
	board = start.clone()
	info = rival_info
	var sk := Duel.rival_skill(int(rival_info.get("rating", 1000)))
	interval = sk["interval"]
	mistake = sk["mistake"]
	_rng.seed = seed
	_timer = interval * 1.3  # rywal też "rozgląda się" na starcie


## Ustawia symulację znajomego: idzie podanym planem i kończy po target_s sekundach.
func set_exact(plan: Array, target_s: float) -> void:
	exact = true
	mistake = 0.0
	_plan = plan.duplicate()
	interval = maxf(0.3, target_s / maxf(1.0, float(plan.size())))
	_timer = interval


## Postęp rywala (0..1) - ile palet ma już skompletowanych.
func progress() -> float:
	var full := 0
	var total := 0
	for i in board.stacks.size():
		if not board.stacks[i].is_empty():
			total += 1
			if board.is_stack_complete(i):
				full += 1
	return float(full) / maxf(1.0, float(total))


## Wywołuj co klatkę. Zwraca true, gdy rywal wykonał ruch.
func update(delta: float) -> bool:
	if done:
		return false
	_timer -= delta
	if _timer > 0.0:
		return false
	# += zamiast = : nadwyżka czasu z tej klatki przechodzi na następny ruch (dokładne tempo).
	_timer += interval if exact else interval * _rng.randf_range(0.75, 1.25)
	if _rng.randf() < mistake and _random_move():
		_plan.clear()
	else:
		if _plan.is_empty():
			var r := Solver.solve(board, 20000)
			if not r.ok:
				_random_move()
				return true
			_plan = r.moves
		var m: Array = _plan.pop_front()
		if board.apply(m).is_empty():
			_plan.clear()
	moves += 1
	done = board.is_solved()
	return true


## Zbędny (ale bezpieczny) ruch: taki, po którym plansza nadal jest rozwiązywalna.
func _random_move() -> bool:
	var opts: Array = []
	for a in board.stacks.size():
		for b in board.stacks.size():
			if board.move_count(a, b) > 0:
				opts.append([a, b])
	opts.shuffle()
	for m in opts.slice(0, 4):
		var rec := board.apply(m)
		if Solver.solve(board, 8000).ok:
			return true
		board.undo(rec)
	return false

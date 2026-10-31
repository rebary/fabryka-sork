class_name Board
extends RefCounted
## Logika planszy (bez grafiki).
## Plansza to kilka "palet" (stosów). Każda paleta mieści `capacity` paczek.
## Paczka to liczba całkowita = typ produktu (0, 1, 2...).
## stacks[i] to lista paczek na palecie i: indeks 0 = dół, ostatni = góra.

var capacity: int = 4
var stacks: Array = []


func _init(p_stacks: Array = [], p_capacity: int = 4) -> void:
	capacity = p_capacity
	stacks = []
	for s in p_stacks:
		stacks.append(s.duplicate())


## Pełna kopia planszy (np. do restartu poziomu lub do solvera).
func clone() -> Board:
	return Board.new(stacks, capacity)


## Ile paczek tego samego typu leży kolejno na górze palety i.
func top_run(i: int) -> int:
	var s: Array = stacks[i]
	if s.is_empty():
		return 0
	var top_type = s.back()
	var n := 0
	for k in range(s.size() - 1, -1, -1):
		if s[k] == top_type:
			n += 1
		else:
			break
	return n


## Czy wolno przenieść paczki z palety `from` na paletę `to`.
## Zasada: cel jest pusty albo ma na górze ten sam produkt i ma wolne miejsce.
func can_move(from: int, to: int) -> bool:
	if from == to:
		return false
	var src: Array = stacks[from]
	var dst: Array = stacks[to]
	if src.is_empty() or dst.size() >= capacity:
		return false
	if dst.is_empty():
		return true
	return dst.back() == src.back()


## Ile paczek zostanie przeniesionych (robot bierze cały górny ciąg, ile się zmieści).
func move_count(from: int, to: int) -> int:
	if not can_move(from, to):
		return 0
	return mini(top_run(from), capacity - stacks[to].size())


## Wykonuje ruch. Zwraca liczbę przeniesionych paczek (0 = ruch niedozwolony).
func apply_move(from: int, to: int) -> int:
	var n := move_count(from, to)
	for k in n:
		stacks[to].append(stacks[from].pop_back())
	return n


## Cofa ruch, który przeniósł `n` paczek z `from` na `to`.
func undo_move(from: int, to: int, n: int) -> void:
	for k in n:
		stacks[from].append(stacks[to].pop_back())


## Paleta skompletowana = pełna i tylko jeden typ produktu.
func is_stack_complete(i: int) -> bool:
	var s: Array = stacks[i]
	return s.size() == capacity and top_run(i) == capacity


## Poziom ukończony = każda paleta jest pusta albo skompletowana.
func is_solved() -> bool:
	for i in stacks.size():
		if not stacks[i].is_empty() and not is_stack_complete(i):
			return false
	return true


## Czy istnieje jakikolwiek dozwolony ruch.
func has_any_move() -> bool:
	for a in stacks.size():
		for b in stacks.size():
			if can_move(a, b):
				return true
	return false


## Tekstowy "odcisk" stanu, niezależny od kolejności palet (dla solvera).
func key() -> String:
	var parts := PackedStringArray()
	for s in stacks:
		var p := ""
		for v in s:
			p += char(65 + int(v))
		parts.append(p)
	parts.sort()
	return ",".join(parts)

class_name Board
extends RefCounted
## Logika planszy (bez grafiki).
## Plansza to kilka "palet" (stosów). Każda paleta mieści `capacity` paczek.
## stacks[i] to lista paczek na palecie i: indeks 0 = dół, ostatni = góra.
## Wartość paczki:
##   typ >= 0        -> paczka widoczna, typ produktu 0, 1, 2...
##   -(typ + 1) < 0  -> paczka w folii stretch (gracz nie widzi, co to za produkt).
## Paczka w folii odsłania się, gdy znajdzie się na górze palety.

var capacity: int = 4
var stacks: Array = []


func _init(p_stacks: Array = [], p_capacity: int = 4) -> void:
	capacity = p_capacity
	stacks = []
	for s in p_stacks:
		stacks.append(s.duplicate())


func clone() -> Board:
	return Board.new(stacks, capacity)


## Prawdziwy typ produktu (także dla paczki w folii).
static func type_of(v: int) -> int:
	return v if v >= 0 else -v - 1


static func is_wrapped(v: int) -> bool:
	return v < 0


## Ile widocznych paczek tego samego typu leży kolejno na górze palety i.
## Paczki w folii przerywają ciąg (robot bierze tylko to, co widać).
func top_run(i: int) -> int:
	var s: Array = stacks[i]
	if s.is_empty() or s.back() < 0:
		return 0
	var top_type: int = s.back()
	var n := 0
	for k in range(s.size() - 1, -1, -1):
		if s[k] == top_type:
			n += 1
		else:
			break
	return n


## Czy wolno przenieść paczki z palety `from` na paletę `to`.
func can_move(from: int, to: int) -> bool:
	if from == to:
		return false
	var src: Array = stacks[from]
	var dst: Array = stacks[to]
	if src.is_empty() or src.back() < 0 or dst.size() >= capacity:
		return false
	if dst.is_empty():
		return true
	return type_of(dst.back()) == src.back()


## Ile paczek zostanie przeniesionych (cały górny ciąg, ile się zmieści).
func move_count(from: int, to: int) -> int:
	if not can_move(from, to):
		return 0
	return mini(top_run(from), capacity - stacks[to].size())


## Wykonuje ruch. Zwraca "zapis ruchu" potrzebny do cofnięcia:
## [from, to, n, odsłonięcia], gdzie odsłonięcia = lista [paleta, indeks].
## Pusta tablica = ruch niedozwolony.
func do_move(from: int, to: int) -> Array:
	var n := move_count(from, to)
	if n == 0:
		return []
	for k in n:
		stacks[to].append(stacks[from].pop_back())
	var reveals: Array = []
	_reveal(from, stacks[from].size() - 1, reveals)
	# Skompletowana paleta odsłania się w całości.
	if is_stack_complete(to):
		for k in stacks[to].size():
			_reveal(to, k, reveals)
	return [from, to, n, reveals]


## Cofa ruch na podstawie zapisu z do_move.
func undo(record: Array) -> void:
	var reveals: Array = record[3]
	for r in reveals:
		stacks[r[0]][r[1]] = -int(stacks[r[0]][r[1]]) - 1
	for k in int(record[2]):
		stacks[record[0]].append(stacks[record[1]].pop_back())


func _reveal(i: int, k: int, reveals: Array) -> void:
	if k >= 0 and stacks[i][k] < 0:
		stacks[i][k] = type_of(stacks[i][k])
		reveals.append([i, k])


## Paleta skompletowana = pełna i tylko jeden typ produktu.
func is_stack_complete(i: int) -> bool:
	var s: Array = stacks[i]
	if s.size() != capacity:
		return false
	var t := type_of(s[0])
	for v in s:
		if type_of(v) != t:
			return false
	return true


## Poziom ukończony = każda paleta jest pusta albo skompletowana.
func is_solved() -> bool:
	for i in stacks.size():
		if not stacks[i].is_empty() and not is_stack_complete(i):
			return false
	return true


func has_any_move() -> bool:
	for a in stacks.size():
		for b in stacks.size():
			if can_move(a, b):
				return true
	return false


func wrapped_count() -> int:
	var n := 0
	for s in stacks:
		for v in s:
			if v < 0:
				n += 1
	return n


## Tekstowy "odcisk" stanu, niezależny od kolejności palet (dla solvera).
## Wielka litera = paczka widoczna, mała = w folii.
func key() -> String:
	var parts := PackedStringArray()
	for s in stacks:
		var p := ""
		for v in s:
			p += char(65 + v) if v >= 0 else char(97 + type_of(v))
		parts.append(p)
	parts.sort()
	return ",".join(parts)

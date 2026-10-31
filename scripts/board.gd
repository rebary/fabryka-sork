class_name Board
extends RefCounted
## Logika planszy (bez grafiki).
## Plansza to kilka "palet" (stosów). Każda paleta mieści `capacity` paczek.
## stacks[i] to lista paczek na palecie i: indeks 0 = dół, ostatni = góra.
## Wartość paczki:
##   typ >= 0        -> paczka widoczna, typ produktu 0, 1, 2...
##   -(typ + 1) < 0  -> paczka w folii stretch (gracz nie widzi, co to za produkt).
## Paczka w folii odsłania się, gdy znajdzie się na górze palety.
##
## CHWYTAKI (tool_cap):
##   TOOL_SMART (0)   - zwykły robot: bierze cały górny ciąg, ile się zmieści (domyślnie);
##   TOOL_VACUUM (-1) - chwytak próżniowy: cały ciąg albo nic (ciąg musi się zmieścić);
##   2                - widły: do 2 paczek;
##   1                - szczęki: 1 paczka.
## Gdy lista `tools` nie jest pusta, gracz może zmieniać chwytak (kosztuje to ruch).

const TOOL_SMART := 0
const TOOL_VACUUM := -1

var capacity: int = 4
var stacks: Array = []
var tools: Array = []
var tool_cap: int = TOOL_SMART


func _init(p_stacks: Array = [], p_capacity: int = 4, p_tools: Array = [], p_tool_cap: int = TOOL_SMART) -> void:
	capacity = p_capacity
	tools = p_tools.duplicate()
	tool_cap = p_tool_cap
	stacks = []
	for s in p_stacks:
		stacks.append(s.duplicate())


func clone() -> Board:
	return Board.new(stacks, capacity, tools, tool_cap)


## Prawdziwy typ produktu (także dla paczki w folii).
static func type_of(v: int) -> int:
	return v if v >= 0 else -v - 1


static func is_wrapped(v: int) -> bool:
	return v < 0


## Ile widocznych paczek tego samego typu leży kolejno na górze palety i.
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


## Czy cel w ogóle przyjmuje paczki ze źródła (bez uwzględniania chwytaka).
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


## Ile paczek przeniesie robot z aktualnym chwytakiem (0 = ruch niemożliwy).
func move_count(from: int, to: int) -> int:
	return move_count_with(from, to, tool_cap)


func move_count_with(from: int, to: int, cap: int) -> int:
	if not can_move(from, to):
		return 0
	var run := top_run(from)
	var space: int = capacity - stacks[to].size()
	match cap:
		TOOL_SMART:
			return mini(run, space)
		TOOL_VACUUM:
			return run if run <= space else 0
		_:
			return mini(mini(run, space), cap)


## Wykonuje ruch paczek. Zwraca zapis do cofnięcia: [from, to, n, odsłonięcia].
## Pusta tablica = ruch niedozwolony.
func do_move(from: int, to: int) -> Array:
	var n := move_count(from, to)
	if n == 0:
		return []
	for k in n:
		stacks[to].append(stacks[from].pop_back())
	var reveals: Array = []
	_reveal(from, stacks[from].size() - 1, reveals)
	if is_stack_complete(to):
		for k in stacks[to].size():
			_reveal(to, k, reveals)
	return [from, to, n, reveals]


## Zmiana chwytaka. Zapis: [-1, nowy, poprzedni, []]. Pusta tablica = niedozwolone.
func do_tool(cap: int) -> Array:
	if not tools.has(cap) or cap == tool_cap:
		return []
	var prev := tool_cap
	tool_cap = cap
	return [-1, cap, prev, []]


## Wykonuje ruch zapisany jako [from, to] albo [-1, chwytak].
func apply(m: Array) -> Array:
	return do_tool(m[1]) if m[0] < 0 else do_move(m[0], m[1])


func undo(record: Array) -> void:
	if record[0] < 0:
		tool_cap = record[2]
		return
	var reveals: Array = record[3]
	for r in reveals:
		stacks[r[0]][r[1]] = -int(stacks[r[0]][r[1]]) - 1
	for k in int(record[2]):
		stacks[record[0]].append(stacks[record[1]].pop_back())


func _reveal(i: int, k: int, reveals: Array) -> void:
	if k >= 0 and stacks[i][k] < 0:
		stacks[i][k] = type_of(stacks[i][k])
		reveals.append([i, k])


func is_stack_complete(i: int) -> bool:
	var s: Array = stacks[i]
	if s.size() != capacity:
		return false
	var t := type_of(s[0])
	for v in s:
		if type_of(v) != t:
			return false
	return true


func is_solved() -> bool:
	for i in stacks.size():
		if not stacks[i].is_empty() and not is_stack_complete(i):
			return false
	return true


## Czy jest jakikolwiek ruch paczkami (z aktualnym albo - jeśli wolno zmieniać - innym chwytakiem).
func has_any_move() -> bool:
	var caps: Array = [tool_cap] + tools
	for a in stacks.size():
		for b in stacks.size():
			for cap in caps:
				if move_count_with(a, b, cap) > 0:
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
func key() -> String:
	var parts := PackedStringArray()
	for s in stacks:
		var p := ""
		for v in s:
			p += char(65 + v) if v >= 0 else char(97 + type_of(v))
		parts.append(p)
	parts.sort()
	var k := ",".join(parts)
	if not tools.is_empty():
		k += "|%d" % tool_cap
	return k

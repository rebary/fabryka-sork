class_name Score
extends RefCounted
## Punkty i rangi (ranking punktowy).
## Za każde zlecenie/program liczy się NAJLEPSZY wynik - poprawa dodaje różnicę,
## a powtarzanie tego samego poziomu nie "nabija" punktów.
##   punkty = baza (trudność poziomu) x mnożnik gwiazdek x premia za grę bez podpowiedzi

const STAR_MULT := {1: 0.5, 2: 0.75, 3: 1.0}
const NO_HINT_BONUS := 1.2

## Rangi od najniższej. Progi dobrane tak, by kolejne awanse przychodziły
## mniej więcej co kilkanaście-kilkadziesiąt zleceń (do strojenia po testach).
const RANKS := [
	{"name": "Praktykant", "min": 0},
	{"name": "Operator", "min": 500},
	{"name": "Technik automatyk", "min": 1500},
	{"name": "Programista robotów", "min": 3500},
	{"name": "Integrator", "min": 7000},
	{"name": "Inżynier automatyki", "min": 12000},
	{"name": "Główny automatyk", "min": 20000},
]


static func campaign_base(params: Dictionary) -> float:
	var mods: Array = params.get("mods", [])
	var base := 40.0 + 8.0 * float(params.get("types", 3)) + 25.0 * mods.size()
	if int(params.get("capacity", 4)) == 5:
		base += 10.0
	if params.get("breather", false):
		base *= 0.85  # przerwa: trochę mniej, ale wciąż więcej niż wczesne zlecenia
	return base


static func program_base(optimal: int) -> float:
	return 30.0 + 12.0 * optimal


static func points(base: float, stars: int, hints_used: int) -> int:
	var p: float = base * STAR_MULT.get(clampi(stars, 1, 3), 0.5)
	if hints_used == 0:
		p *= NO_HINT_BONUS
	return int(round(p))


## Ranga dla liczby punktów: {"index", "name", "min", "next_name", "next_min"} (next_min = -1 dla najwyższej).
static func rank_for(total: int) -> Dictionary:
	var idx := 0
	for i in RANKS.size():
		if total >= int(RANKS[i]["min"]):
			idx = i
	var r := {"index": idx, "name": RANKS[idx]["name"], "min": RANKS[idx]["min"], "next_name": "", "next_min": -1}
	if idx + 1 < RANKS.size():
		r["next_name"] = RANKS[idx + 1]["name"]
		r["next_min"] = RANKS[idx + 1]["min"]
	return r

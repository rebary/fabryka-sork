class_name Duel
extends RefCounted
## Pojedynki: plansze z ziarna, kody wyzwań, liga (ranking pojedynków) i dobór rywali.
## Działa bez serwera: rywal jest komputerowy, a wyzwanie dla znajomego to kod
## wysyłany dowolnym komunikatorem.

const START_RATING := 1000
const K := 32.0  # jak szybko zmienia się wynik ligi
const STARS_PER_WIN := 1
const MAX_STARS_PER_DAY := 5

const LEAGUES := [
	{"name": "Brąz", "min": 0},
	{"name": "Srebro", "min": 1100},
	{"name": "Złoto", "min": 1250},
	{"name": "Platyna", "min": 1400},
	{"name": "Diament", "min": 1600},
]

## Rywale komputerowi (od najsłabszego). rating = siła rywala w tej samej skali co gracz.
const RIVALS := [
	{"name": "Śrubka", "model": "RB-12", "rating": 900},
	{"name": "Wózek", "model": "MT-7", "rating": 1050},
	{"name": "Dźwig", "model": "PX-40", "rating": 1200},
	{"name": "Iskra", "model": "KX-90", "rating": 1350},
	{"name": "Tytan", "model": "HV-300", "rating": 1500},
	{"name": "Mistrz", "model": "DX-1", "rating": 1700},
]

const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"  # bez I, L, O, U (mniej pomyłek)
const MAX_SEED := 1 << 20
const MAX_TIME_DS := (1 << 14) - 1  # czas w dziesiątych sekundy (do ~27 min)
const MAX_MOVES := (1 << 7) - 1


# ---------------------------------------------------------------- plansze

## Liczba produktów zależy od ziarna (5-7), więc kod wyzwania wystarcza do odtworzenia planszy.
static func types_for_seed(seed: int) -> int:
	return 5 + seed % 3


## Ta sama plansza dla tego samego ziarna (u gracza, rywala i znajomego).
static func board_for_seed(seed: int) -> Board:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("fabryka_duel_%d" % seed)
	var types := types_for_seed(seed)
	for attempt in 300:
		var b := LevelGenerator._random_board(rng, types, 4, 2)
		if LevelGenerator._too_easy(b):
			continue
		if Solver.solve(b).ok:
			return b
	return LevelGenerator._random_board(rng, types, 4, 3)


## Losowe ziarno pasujące do ligi (słabsze ligi - mniej produktów).
static func seed_for_league(league_index: int, rng: RandomNumberGenerator) -> int:
	var want := 5 + clampi(floori(league_index / 2.0), 0, 2)
	var s := rng.randi_range(0, MAX_SEED - 1)
	return s - (s % 3) + (want - 5) if s - (s % 3) + (want - 5) < MAX_SEED else want - 5


# ---------------------------------------------------------------- liga

static func league_for(rating: int) -> Dictionary:
	var idx := 0
	for i in LEAGUES.size():
		if rating >= int(LEAGUES[i]["min"]):
			idx = i
	var r := {"index": idx, "name": LEAGUES[idx]["name"], "min": LEAGUES[idx]["min"], "next_name": "", "next_min": -1}
	if idx + 1 < LEAGUES.size():
		r["next_name"] = LEAGUES[idx + 1]["name"]
		r["next_min"] = LEAGUES[idx + 1]["min"]
	return r


## Nowy wynik ligi gracza po pojedynku (system Elo).
static func new_rating(player: int, rival: int, won: bool) -> int:
	var expected := 1.0 / (1.0 + pow(10.0, (rival - player) / 400.0))
	var delta := K * ((1.0 if won else 0.0) - expected)
	return maxi(0, player + int(round(delta)))


## Rywal najbliższy siłą graczowi (z lekką losowością, żeby nie był zawsze ten sam).
static func pick_rival(rating: int, rng: RandomNumberGenerator) -> Dictionary:
	var best := 0
	for i in RIVALS.size():
		if absi(int(RIVALS[i]["rating"]) - rating) < absi(int(RIVALS[best]["rating"]) - rating):
			best = i
	var idx := clampi(best + rng.randi_range(-1, 1) if rng.randf() < 0.35 else best, 0, RIVALS.size() - 1)
	return RIVALS[idx]


## Tempo i omylność rywala z jego siły: interwał między ruchami (s) i szansa na zbędny ruch.
static func rival_skill(rating: int) -> Dictionary:
	var t := clampf((rating - 900) / 800.0, 0.0, 1.0)
	return {"interval": lerpf(4.0, 1.6, t), "mistake": lerpf(0.35, 0.04, t)}


# ---------------------------------------------------------------- kody wyzwań

## Kod: ziarno planszy + czas i ruchy autora + suma kontrolna. Format FS-XXXXX-XXXXX.
static func encode(seed: int, time_ds: int, moves: int) -> String:
	var payload: int = (clampi(seed, 0, MAX_SEED - 1) << 21) | (clampi(time_ds, 0, MAX_TIME_DS) << 7) | clampi(moves, 0, MAX_MOVES)
	var value: int = (payload << 9) | _checksum(payload)
	var chars := ""
	for i in 10:
		chars = ALPHABET[value & 31] + chars
		value >>= 5
	return "FS-%s-%s" % [chars.substr(0, 5), chars.substr(5, 5)]


## Zwraca {"ok", "seed", "time_ds", "moves"} albo {"ok": false, "error": opis}.
static func decode(code: String) -> Dictionary:
	var c := code.strip_edges().to_upper().replace(" ", "").replace("-", "")
	if c.begins_with("FS"):
		c = c.substr(2)
	c = c.replace("O", "0").replace("I", "1").replace("L", "1")
	if c.length() != 10:
		return {"ok": false, "error": "Kod ma mieć 10 znaków (np. FS-7K2QM-41BXD)"}
	var value := 0
	for ch in c:
		var v := ALPHABET.find(ch)
		if v < 0:
			return {"ok": false, "error": "Niedozwolony znak w kodzie: %s" % ch}
		value = (value << 5) | v
	var payload: int = value >> 9
	if (value & 511) != _checksum(payload):
		return {"ok": false, "error": "Kod jest niepoprawny – sprawdź, czy nie ma literówki"}
	return {"ok": true, "seed": payload >> 21, "time_ds": (payload >> 7) & MAX_TIME_DS, "moves": payload & MAX_MOVES}


static func _checksum(payload: int) -> int:
	var h := 7
	var p := payload
	for i in 6:
		h = (h * 131 + (p & 255)) % 509
		p >>= 8
	return h

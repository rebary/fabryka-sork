extends Node
## Zapis postępu gracza (autoload "Save" - dostępny z każdego skryptu jako Save).
## Plik: user://save.cfg (na Androidzie w prywatnym folderze aplikacji).

const PATH := "user://save.cfg"

var level: int = 1  # następne zlecenie kampanii
var program: int = 1  # następny program (tryb programowania)
var wallet := HintWallet.new()
var sound_on: bool = true
var fx_on: bool = true  # efekty graficzne całego obrazu
var seen_intros: Array = []
var stars: Dictionary = {}  # zlecenie -> najlepsza liczba gwiazdek
var program_stars: Dictionary = {}  # program -> najlepsza liczba gwiazdek
var stars_spent: int = 0
var decor_owned: Array = []
var decor_selected: Dictionary = {}  # miejsce -> id ozdoby
var install_id: String = ""  # losowy, anonimowy identyfikator instalacji (do ankiet)
var playtime: float = 0.0  # łączny czas gry w sekundach
var tasks_completed: int = 0  # ukończone zlecenia + programy
var feedback_pending: Array = []  # ankiety czekające na wysłanie (np. brak internetu)
var feedback_sent: int = 0
var feedback_prompted: bool = false
var points: Dictionary = {}  # "c12" / "p5" -> najlepsze punkty za zlecenie / program
var duel_rating: int = 1000  # wynik ligi pojedynków
var duel_best: int = 1000
var duel_wins: int = 0
var duel_losses: int = 0
var duel_star_day: String = ""
var duel_stars_today: int = 0
## TYLKO W WERSJI TESTOWEJ: nieograniczone gwiazdki (do oglądania ozdób). W wersji do sklepu ignorowane.
var test_unlimited_stars: bool = false


func _ready() -> void:
	load_data()
	if install_id == "":
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		install_id = "%08x%08x" % [rng.randi(), rng.randi()]
		save()


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	level = maxi(1, int(cfg.get_value("progress", "level", 1)))
	program = maxi(1, int(cfg.get_value("progress", "program", 1)))
	wallet.from_dict(cfg.get_value("progress", "wallet", {}))
	seen_intros = cfg.get_value("progress", "seen_intros", [])
	stars = cfg.get_value("progress", "stars", {})
	program_stars = cfg.get_value("progress", "program_stars", {})
	stars_spent = int(cfg.get_value("decor", "stars_spent", 0))
	decor_owned = cfg.get_value("decor", "owned", [])
	decor_selected = cfg.get_value("decor", "selected", {})
	sound_on = bool(cfg.get_value("settings", "sound_on", true))
	fx_on = bool(cfg.get_value("settings", "fx_on", true))
	install_id = str(cfg.get_value("feedback", "install_id", ""))
	playtime = float(cfg.get_value("progress", "playtime", 0.0))
	tasks_completed = int(cfg.get_value("progress", "tasks_completed", 0))
	feedback_pending = cfg.get_value("feedback", "pending", [])
	feedback_sent = int(cfg.get_value("feedback", "sent", 0))
	feedback_prompted = bool(cfg.get_value("feedback", "prompted", false))
	points = cfg.get_value("progress", "points", {})
	duel_rating = int(cfg.get_value("duel", "rating", 1000))
	duel_best = int(cfg.get_value("duel", "best", 1000))
	duel_wins = int(cfg.get_value("duel", "wins", 0))
	duel_losses = int(cfg.get_value("duel", "losses", 0))
	duel_star_day = str(cfg.get_value("duel", "star_day", ""))
	duel_stars_today = int(cfg.get_value("duel", "stars_today", 0))
	test_unlimited_stars = bool(cfg.get_value("test", "unlimited_stars", false))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "level", level)
	cfg.set_value("progress", "program", program)
	cfg.set_value("progress", "wallet", wallet.to_dict())
	cfg.set_value("progress", "seen_intros", seen_intros)
	cfg.set_value("progress", "stars", stars)
	cfg.set_value("progress", "program_stars", program_stars)
	cfg.set_value("decor", "stars_spent", stars_spent)
	cfg.set_value("decor", "owned", decor_owned)
	cfg.set_value("decor", "selected", decor_selected)
	cfg.set_value("settings", "sound_on", sound_on)
	cfg.set_value("settings", "fx_on", fx_on)
	cfg.set_value("feedback", "install_id", install_id)
	cfg.set_value("progress", "playtime", playtime)
	cfg.set_value("progress", "tasks_completed", tasks_completed)
	cfg.set_value("feedback", "pending", feedback_pending)
	cfg.set_value("feedback", "sent", feedback_sent)
	cfg.set_value("feedback", "prompted", feedback_prompted)
	cfg.set_value("progress", "points", points)
	cfg.set_value("duel", "rating", duel_rating)
	cfg.set_value("duel", "best", duel_best)
	cfg.set_value("duel", "wins", duel_wins)
	cfg.set_value("duel", "losses", duel_losses)
	cfg.set_value("duel", "star_day", duel_star_day)
	cfg.set_value("duel", "stars_today", duel_stars_today)
	cfg.set_value("test", "unlimited_stars", test_unlimited_stars)
	cfg.save(PATH)


## Zapisuje wynik; zwraca, ile NOWYCH gwiazdek gracz zdobył (poprawa wyniku też się liczy).
func record_stars(is_program: bool, number: int, earned: int) -> int:
	var d: Dictionary = program_stars if is_program else stars
	var before: int = d.get(number, 0)
	if earned > before:
		d[number] = earned
		return earned - before
	return 0


func total_stars() -> int:
	var n := 0
	for v in stars.values():
		n += int(v)
	for v in program_stars.values():
		n += int(v)
	return n


func unlimited_stars() -> bool:
	return test_unlimited_stars and OS.is_debug_build()


func stars_available() -> int:
	if unlimited_stars():
		return 99999
	return total_stars() - stars_spent


func decor_of(slot_id: String) -> String:
	return decor_selected.get(slot_id, Decor.default_item(slot_id))


func owns(item_id: String) -> bool:
	var it := Decor.item(item_id)
	if it.has("premium"):
		return decor_owned.has(item_id)
	return int(it.get("price", 0)) == 0 or decor_owned.has(item_id)


## Kupuje (jeśli trzeba) i ustawia ozdobę. Zwraca false, gdy brakuje gwiazdek.
func choose_decor(slot_id: String, item_id: String) -> bool:
	if not owns(item_id):
		if Decor.is_premium(item_id):
			return false  # pakiet kupuje się w sklepie (Store), nie za gwiazdki
		var price: int = Decor.item(item_id)["price"]
		if stars_available() < price:
			return false
		if not unlimited_stars():
			stars_spent += price
		decor_owned.append(item_id)
	decor_selected[slot_id] = item_id
	save()
	return true


## Zapisuje punkty za poziom (liczy się najlepszy wynik). Zwraca przyrost punktów.
func record_points(key: String, earned: int) -> int:
	var before: int = points.get(key, 0)
	if earned > before:
		points[key] = earned
		return earned - before
	return 0


func total_points() -> int:
	var n := 0
	for v in points.values():
		n += int(v)
	return n


func points_of(prefix: String) -> int:
	var n := 0
	for k in points:
		if str(k).begins_with(prefix):
			n += int(points[k])
	return n


## Gwiazdka za wygrany pojedynek (najwyżej Duel.MAX_STARS_PER_DAY dziennie). Zwraca liczbę przyznanych.
func award_duel_star() -> int:
	var today := Time.get_date_string_from_system()
	if duel_star_day != today:
		duel_star_day = today
		duel_stars_today = 0
	if duel_stars_today >= Duel.MAX_STARS_PER_DAY:
		return 0
	duel_stars_today += Duel.STARS_PER_WIN
	stars_spent -= Duel.STARS_PER_WIN  # gwiazdki z pojedynków zwiększają pulę do wydania
	return Duel.STARS_PER_WIN


## Odblokowuje ozdoby z kupionego pakietu wyglądu.
func unlock_pack(product_id: String) -> Array:
	var unlocked: Array = []
	for id in Decor.items_in_pack(product_id):
		if not decor_owned.has(id):
			decor_owned.append(id)
			unlocked.append(id)
	save()
	return unlocked

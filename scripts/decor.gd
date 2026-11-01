class_name Decor
extends RefCounted
## Katalog ozdób hali (tylko wygląd - nie dają przewagi w grze).
##  - "price": koszt w gwiazdkach (0 = wygląd domyślny, za darmo);
##  - "premium": identyfikator pakietu kupowanego za pieniądze (scripts/store.gd -> PRODUCTS).
## Rysowanie ozdób jest w main.gd (_draw_hall, _draw_box, _draw_robot).

const SLOTS := [
	{"id": "robot", "name": "Kolor robota", "items": [
		{"id": "robot_orange", "name": "Pomarańczowy", "price": 0, "color": "#ff9f1c"},
		{"id": "robot_blue", "name": "Niebieski", "price": 6, "color": "#3a86ff"},
		{"id": "robot_green", "name": "Zielony", "price": 12, "color": "#2ec27e"},
		{"id": "robot_red", "name": "Czerwony", "price": 20, "color": "#e63946"},
		{"id": "robot_chrome", "name": "Chrom", "price": 40, "color": "#c9d1db"},
		{"id": "robot_neon", "name": "Neonowy (mieni się)", "premium": "cosmetic_neon", "color": "#ff2bd6", "neon": true},
		{"id": "robot_gold", "name": "Złoty", "premium": "cosmetic_gala", "color": "#f2c14e", "gold": true},
	]},
	{"id": "boxes", "name": "Wygląd paczek", "items": [
		{"id": "boxes_carton", "name": "Kartony", "price": 0},
		{"id": "boxes_crate", "name": "Skrzynie drewniane", "price": 25},
		{"id": "boxes_metal", "name": "Pojemniki metalowe", "price": 35},
		{"id": "boxes_neon", "name": "Pojemniki neonowe", "premium": "cosmetic_neon"},
	]},
	{"id": "wall", "name": "Ściana hali", "items": [
		{"id": "wall_steel", "name": "Stalowa", "price": 0, "top": "#1b2027", "bottom": "#2c333d"},
		{"id": "wall_navy", "name": "Granatowa", "price": 8, "top": "#121a2e", "bottom": "#24324f"},
		{"id": "wall_brick", "name": "Ceglana", "price": 18, "top": "#2a1a17", "bottom": "#45281f", "brick": true},
		{"id": "wall_light", "name": "Jasna hala", "price": 28, "top": "#3a414b", "bottom": "#59626e"},
		{"id": "wall_neon", "name": "Hala neonowa", "premium": "cosmetic_neon", "top": "#0b0614", "bottom": "#1a0b2e", "neon_grid": true},
		{"id": "wall_future", "name": "Hala przyszłości", "premium": "cosmetic_future", "top": "#1d3557", "bottom": "#457b9d", "future": true},
	]},
	{"id": "floor", "name": "Posadzka", "items": [
		{"id": "floor_concrete", "name": "Beton", "price": 0, "color": "#252a31"},
		{"id": "floor_green", "name": "Żywica zielona", "price": 7, "color": "#1f3a2c"},
		{"id": "floor_grate", "name": "Kratka", "price": 14, "color": "#2b2f36", "grate": true},
		{"id": "floor_mirror", "name": "Lustrzana", "premium": "cosmetic_gala", "color": "#1a1f26", "mirror": true},
	]},
	{"id": "belt", "name": "Taśmociąg", "items": [
		{"id": "belt_gray", "name": "Szary", "price": 0, "color": "#343a43"},
		{"id": "belt_yellow", "name": "Żółty", "price": 8, "color": "#b8860b"},
		{"id": "belt_rollers", "name": "Rolkowy", "price": 15, "color": "#2a2f36", "rollers": true},
	]},
	{"id": "lights", "name": "Oświetlenie", "items": [
		{"id": "lights_none", "name": "Brak", "price": 0},
		{"id": "lights_lamps", "name": "Lampy przemysłowe", "price": 10},
		{"id": "lights_led", "name": "Pas LED", "price": 22},
		{"id": "lights_stage", "name": "Reflektory sceniczne", "premium": "cosmetic_gala"},
	]},
	{"id": "windows", "name": "Okna", "items": [
		{"id": "windows_none", "name": "Brak", "price": 0},
		{"id": "windows_day", "name": "Okna – dzień", "price": 12},
		{"id": "windows_night", "name": "Okna – noc z gwiazdami", "price": 20},
		{"id": "windows_aurora", "name": "Okna – zorza", "premium": "cosmetic_future"},
	]},
	{"id": "sign", "name": "Na ścianie", "items": [
		{"id": "sign_none", "name": "Nic", "price": 0},
		{"id": "sign_clock", "name": "Zegar", "price": 8},
		{"id": "sign_board", "name": "Tablica wyników", "price": 16},
	]},
	{"id": "plants", "name": "Zieleń", "items": [
		{"id": "plants_none", "name": "Brak", "price": 0},
		{"id": "plants_flower", "name": "Kwiatek", "price": 5},
		{"id": "plants_palm", "name": "Palmy", "price": 15},
	]},
	{"id": "arm", "name": "Roboty w tle", "items": [
		{"id": "arm_none", "name": "Brak", "price": 0},
		{"id": "arm_robot", "name": "Ramię przemysłowe", "price": 30},
		{"id": "arm_two", "name": "Dwa ramiona", "price": 45},
	]},
]


static func slot(slot_id: String) -> Dictionary:
	for s in SLOTS:
		if s["id"] == slot_id:
			return s
	return {}


static func item(item_id: String) -> Dictionary:
	for s in SLOTS:
		for it in s["items"]:
			if it["id"] == item_id:
				return it
	return {}


static func default_item(slot_id: String) -> String:
	return slot(slot_id)["items"][0]["id"]


static func is_premium(item_id: String) -> bool:
	return item(item_id).has("premium")


## Wszystkie ozdoby z danego pakietu (do odblokowania po zakupie).
static func items_in_pack(product_id: String) -> Array:
	var out: Array = []
	for s in SLOTS:
		for it in s["items"]:
			if it.get("premium", "") == product_id:
				out.append(it["id"])
	return out

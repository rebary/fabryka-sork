class_name Decor
extends RefCounted
## Katalog ozdób hali (tylko wygląd - nie dają przewagi w grze).
## Ozdoby kupuje się za gwiazdki zdobyte w zleceniach i programach.
## Pierwsza pozycja w każdym miejscu jest darmowa (wygląd domyślny).
## Ceny i nazwy można dowolnie zmieniać; rysowanie jest w main.gd (_draw_hall i _draw_robot).

const SLOTS := [
	{"id": "robot", "name": "Kolor robota", "items": [
		{"id": "robot_orange", "name": "Pomarańczowy", "price": 0, "color": "#ff9f1c"},
		{"id": "robot_blue", "name": "Niebieski", "price": 6, "color": "#3a86ff"},
		{"id": "robot_green", "name": "Zielony", "price": 12, "color": "#2ec27e"},
		{"id": "robot_red", "name": "Czerwony", "price": 20, "color": "#e63946"},
		{"id": "robot_chrome", "name": "Chrom", "price": 40, "color": "#c9d1db"},
	]},
	{"id": "wall", "name": "Ściana hali", "items": [
		{"id": "wall_steel", "name": "Stalowa", "price": 0, "top": "#1b2027", "bottom": "#2c333d"},
		{"id": "wall_navy", "name": "Granatowa", "price": 8, "top": "#121a2e", "bottom": "#24324f"},
		{"id": "wall_brick", "name": "Ceglana", "price": 18, "top": "#2a1a17", "bottom": "#45281f", "brick": true},
		{"id": "wall_light", "name": "Jasna hala", "price": 28, "top": "#3a414b", "bottom": "#59626e"},
	]},
	{"id": "floor", "name": "Posadzka", "items": [
		{"id": "floor_concrete", "name": "Beton", "price": 0, "color": "#252a31"},
		{"id": "floor_green", "name": "Żywica zielona", "price": 7, "color": "#1f3a2c"},
		{"id": "floor_grate", "name": "Kratka", "price": 14, "color": "#2b2f36", "grate": true},
	]},
	{"id": "lights", "name": "Oświetlenie", "items": [
		{"id": "lights_none", "name": "Brak", "price": 0},
		{"id": "lights_lamps", "name": "Lampy przemysłowe", "price": 10},
		{"id": "lights_led", "name": "Pas LED", "price": 22},
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
	{"id": "arm", "name": "Robot w tle", "items": [
		{"id": "arm_none", "name": "Brak", "price": 0},
		{"id": "arm_robot", "name": "Ramię przemysłowe", "price": 30},
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

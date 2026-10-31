class_name Look
extends RefCounted
## Wspólny wygląd: czcionki. Exo 2 (licencja SIL Open Font License, plik assets/fonts/OFL-Exo2.txt).

static var regular: FontVariation
static var bold: FontVariation


static func init() -> void:
	if regular != null:
		return
	var base: FontFile = load("res://assets/fonts/Exo2-Variable.ttf")
	regular = FontVariation.new()
	regular.base_font = base
	regular.variation_opentype = {"wght": 600}
	bold = FontVariation.new()
	bold.base_font = base
	bold.variation_opentype = {"wght": 800}
	# Domyślna czcionka dla całej gry (przyciski, napisy, tekst rysowany kodem).
	ThemeDB.fallback_font = regular

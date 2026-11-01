extends Node
## Sklep (zakupy w aplikacji) i reklamy za nagrodą (autoload "Store").
##
## UWAGA: obecnie działa WYŁĄCZNIE TRYB TESTOWY - zakup i reklama są symulowane,
## żadne pieniądze nie są pobierane i żadna reklama nie jest wyświetlana.
## Prawdziwe płatności (Google Play Billing) i reklamy (np. AdMob) podłączymy
## w osobnym kroku - wymagają konta Google Play Console, wtyczek Godota
## i testów na telefonie. Reszta gry korzysta tylko z sygnałów poniżej,
## więc podmiana trybu testowego na prawdziwy nie wymaga zmian w main.gd.

signal purchase_finished(product_id: String, success: bool)
signal ad_finished(rewarded: bool)

## Identyfikatory muszą być identyczne jak produkty utworzone w Google Play Console.
const PRODUCTS := {
	"hints_5": {"hints": 5, "title": "5 podpowiedzi"},
	"hints_15": {"hints": 15, "title": "15 podpowiedzi"},
	"hints_40": {"hints": 40, "title": "40 podpowiedzi"},
	# Pakiety wyglądu: tylko kosmetyka, jednorazowy zakup (w Google Play: produkt "nonconsumable").
	"cosmetic_neon": {"pack": true, "title": "Pakiet Neon", "desc": "neonowy robot, hala neonowa, pojemniki neonowe"},
	"cosmetic_gala": {"pack": true, "title": "Pakiet Gala", "desc": "złoty robot, lustrzana posadzka, reflektory sceniczne"},
	"cosmetic_future": {"pack": true, "title": "Pakiet Hala przyszłości", "desc": "hala przyszłości, okna z zorzą"},
}

var test_mode := true
var busy := false


## Cena do wyświetlenia. W prawdziwym sklepie pochodzi z Google Play (waluta gracza).
func price_text(product_id: String) -> String:
	if test_mode:
		return "TEST"
	return "?"


func purchase(product_id: String) -> void:
	if busy or not PRODUCTS.has(product_id):
		return
	busy = true
	if test_mode:
		await get_tree().create_timer(0.6).timeout
		busy = false
		purchase_finished.emit(product_id, true)


func show_rewarded_ad() -> void:
	if busy:
		return
	busy = true
	if test_mode:
		await get_tree().create_timer(1.5).timeout
		busy = false
		ad_finished.emit(true)

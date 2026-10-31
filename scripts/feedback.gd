extends Node
## Ankieta graczy (autoload "Feedback").
## Odpowiedzi trafiają do arkusza Google Sheets przez skrypt Google Apps Script
## (instrukcja: docs/05_ANKIETA_I_ANALIZA.md, kod skryptu: docs/ankieta/Code.gs).
## Bez internetu ankieta czeka w kolejce (zapisanej w Save) i wysyła się później.
##
## KONFIGURACJA: wklej adres wdrożonego skryptu (kończy się na /exec) i ten sam klucz,
## który ustawisz w Code.gs. Pusty adres = ankiety zapisują się tylko w kolejce na telefonie.

const ENDPOINT_URL := ""
const SHARED_KEY := "ZMIEN_MNIE"
const SCHEMA := 1

signal sent_ok(count: int)

var endpoint := ENDPOINT_URL  # można podmienić w testach
var http: HTTPRequest
var sending := false


func _ready() -> void:
	http = HTTPRequest.new()
	http.timeout = 15.0
	# Google Apps Script odpowiada przekierowaniem (302) pod adres z wynikiem.
	# Obsługujemy je sami: wynik pobieramy zwykłym GET.
	http.max_redirects = 0
	add_child(http)
	http.request_completed.connect(_on_completed)
	flush()


## Dodaje ankietę do kolejki i próbuje wysłać. answers = odpowiedzi z formularza.
func submit(answers: Dictionary, context: Dictionary) -> void:
	var entry := answers.duplicate()
	entry.merge(context)
	entry["schema"] = SCHEMA
	entry["uid"] = "%s-%d" % [Save.install_id, Time.get_unix_time_from_system()]
	entry["install_id"] = Save.install_id
	entry["version"] = str(ProjectSettings.get_setting("application/config/version", "?"))
	entry["device"] = OS.get_model_name()
	entry["os"] = "%s %s" % [OS.get_name(), OS.get_version()]
	entry["locale"] = OS.get_locale()
	entry["playtime_min"] = snappedf(Save.playtime / 60.0, 0.1)
	entry["client_time"] = Time.get_datetime_string_from_system(true)
	Save.feedback_pending.append(entry)
	Save.save()
	flush()


func pending_count() -> int:
	return Save.feedback_pending.size()


## Wysyła pierwszą ankietę z kolejki (kolejne po potwierdzeniu poprzedniej).
func flush() -> void:
	if sending or endpoint == "" or Save.feedback_pending.is_empty():
		return
	var body: Dictionary = Save.feedback_pending[0].duplicate()
	body["key"] = SHARED_KEY
	sending = true
	var err := http.request(endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		sending = false


func _on_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if code in [301, 302, 303, 307, 308]:
		var location := ""
		for h in headers:
			if h.to_lower().begins_with("location:"):
				location = h.substr(9).strip_edges()
		if location != "" and http.request(location) == OK:
			return  # czekamy na odpowiedź z adresu wyniku
	sending = false
	var ok := false
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		ok = data is Dictionary and data.get("ok", false)
	if not ok:
		return  # spróbujemy później (np. przy następnym otwarciu menu)
	Save.feedback_pending.pop_front()
	Save.feedback_sent += 1
	Save.save()
	sent_ok.emit(Save.feedback_sent)
	flush()

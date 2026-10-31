extends Node
## Zapis postępu gracza (autoload "Save" - dostępny z każdego skryptu jako Save).
## Plik: user://save.cfg (na Androidzie w prywatnym folderze aplikacji).

const PATH := "user://save.cfg"

var level: int = 1
var wallet := HintWallet.new()
var sound_on: bool = true
var seen_intros: Array = []  # utrudnienia, które gracz już poznał


func _ready() -> void:
	load_data()


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	level = maxi(1, int(cfg.get_value("progress", "level", 1)))
	wallet.from_dict(cfg.get_value("progress", "wallet", {}))
	sound_on = bool(cfg.get_value("settings", "sound_on", true))
	seen_intros = cfg.get_value("progress", "seen_intros", [])


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "level", level)
	cfg.set_value("progress", "wallet", wallet.to_dict())
	cfg.set_value("progress", "seen_intros", seen_intros)
	cfg.set_value("settings", "sound_on", sound_on)
	cfg.save(PATH)

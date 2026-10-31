extends Node
## Odtwarzanie efektów dźwiękowych (autoload "Sfx"). Użycie: Sfx.play("drop")

const NAMES := ["pick", "drop", "complete", "win", "click", "error", "hint", "reward"]
const POOL := 6

var streams := {}
var players: Array = []
var next := 0


func _ready() -> void:
	for n in NAMES:
		streams[n] = load("res://assets/sfx/%s.wav" % n)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func play(sound_name: String, pitch: float = 1.0) -> void:
	if not Save.sound_on or not streams.has(sound_name):
		return
	var p: AudioStreamPlayer = players[next]
	next = (next + 1) % POOL
	p.stream = streams[sound_name]
	p.pitch_scale = pitch
	p.play()

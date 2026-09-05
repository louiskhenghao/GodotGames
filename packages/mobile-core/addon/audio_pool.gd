class_name CoreAudioPool
extends Node
## Bounded polyphony for short game sounds; callers own the sound catalog.
var voices: Array[AudioStreamPlayer] = []
var cursor := 0
var enabled := true

func _ready() -> void:
	for i in 6:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -12
		add_child(voice)
		voices.append(voice)

func play(sound: AudioStream, pitch: float = 1.0) -> void:
	if not enabled: return
	var voice := voices[cursor]
	cursor = (cursor + 1) % voices.size()
	voice.stop()
	voice.stream = sound
	voice.pitch_scale = pitch
	voice.play()

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null

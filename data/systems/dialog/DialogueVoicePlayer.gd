class_name DialogueVoicePlayer
extends AudioStreamPlayer

var _random_number_gen := RandomNumberGenerator.new()

func _ready() -> void:
	_random_number_gen.randomize()

# We're gonna select a random pitch for each time the voice is played
func play_sound(from_position := 0.0) -> void:
	pitch_scale = _random_number_gen.randf_range(0.95, 1.08)
	super.play(from_position)

extends TriggerAction

@export var scene_to_load = "res://scenes/niveau2.tscn"

func execute() -> void:
	Fade.fade_to_scene(scene_to_load)

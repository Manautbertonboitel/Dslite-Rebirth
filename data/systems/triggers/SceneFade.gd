extends CanvasLayer

@onready var anim = $AnimationPlayer
var is_transitioning := false

func fade_to_scene(path):
	if is_transitioning:
		return

	is_transitioning = true

	anim.play("fade_out")
	await anim.animation_finished

	get_tree().change_scene_to_file(path)
	await get_tree().process_frame

	anim.play("fade_in")
	await anim.animation_finished

	is_transitioning = false

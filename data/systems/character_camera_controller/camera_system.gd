extends Area3D
@export var linked_camera : Camera3D

func _on_body_entered(body):
	
	if body is CharacterBody3D:
		print("body entered trigger zone")
		body.set_active_camera(linked_camera)
		print(linked_camera, "active")

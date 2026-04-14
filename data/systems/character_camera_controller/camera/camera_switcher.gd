extends Area3D

@export var linked_camera : PhantomCamera3D
@export var active_priority : int = 20
@export var inactive_priority : int = 0

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
			print("Player Character entered trigger zone")
			linked_camera.set_priority(active_priority)
			print(linked_camera, "active")

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
			print("Player Character exited trigger zone")
			linked_camera.set_priority(inactive_priority)
			print(linked_camera, "inactive")
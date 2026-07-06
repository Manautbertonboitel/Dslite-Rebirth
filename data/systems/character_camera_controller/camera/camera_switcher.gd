extends Area3D

@export var linked_camera : PhantomCamera3D
@export var active_priority : int = 20
@export var inactive_priority : int = 0

@export var use_player_path : bool = false
@export var player_path: Path3D

func _on_body_entered(body: Node3D) -> void:
#TODO méthode de détection à changer car si c'est un enemy ou un autre perso qui passe dans le trigger ça va quand même trigger 
	if body is CharacterBody3D: 
		print("Player Character entered trigger zone")
		linked_camera.set_priority(active_priority)
		print(linked_camera, "active")
			
		if use_player_path && player_path != null && body.has_method("set_path"):
			body.set_path(player_path)
			

func _on_body_exited(body: Node3D) -> void:
#TODO méthode de détection à changer car si c'est un enemy ou un autre perso qui passe dans le trigger ça va quand même trigger 
	if body is CharacterBody3D:
		print("Player Character exited trigger zone")
		linked_camera.set_priority(inactive_priority)
		print(linked_camera, "inactive")
		
		if use_player_path && player_path != null && body.has_method("set_path"):
			body.set_path(null)
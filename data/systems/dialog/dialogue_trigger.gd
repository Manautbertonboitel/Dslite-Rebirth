extends Area3D

@export var dialogue_manager : DialogueManager
@export var dialog_resource: Resource


func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body is CharacterBody3D:
		dialogue_manager.show_messages(dialog_resource.message_list)

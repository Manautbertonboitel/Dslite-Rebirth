extends Area3D

@export var dialogue_manager : DialogueManager
@export var message_list: Array[String]
var dialogue_position
var next_label


func _ready():
	body_entered.connect(_on_body_entered)
	dialogue_position = dialogue_manager.dialogue_position
	next_label = dialogue_manager.next_label

func _on_body_entered(body):
	
	if body.is_in_group("player"):
		dialogue_manager.show_messages(message_list, dialogue_position)

func _on_DialogueManager_message_completed() -> void:
	next_label.visible = true

func _on_DialogueManager_message_requested() -> void:
	next_label.visible = false

func _on_DialogueManager_finished() -> void:
	next_label.visible = false

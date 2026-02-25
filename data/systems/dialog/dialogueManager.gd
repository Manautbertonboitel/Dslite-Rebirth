class_name DialogueManager
extends Node

const DIALOGUE_SCENE := preload("res://data/systems/dialog/Dialogue.tscn")

signal message_requested
signal message_completed
signal finished

var _messages: Array = []
var _active_dialogue_offset: int = 0
var _is_active: bool = false

var cur_dialogue_instance: Dialogue

@export var dialogue_position: Vector2
@export var next_label: Label


func _input(event: InputEvent) -> void:
	if (
		event.is_pressed()
		and not event.is_echo()
		and event is InputEventKey
		and event.keycode == KEY_ENTER
		and _is_active
		and cur_dialogue_instance.message_is_fully_visible()
	):
		if _active_dialogue_offset < _messages.size() - 1:
			_active_dialogue_offset += 1
			_show_current()
		else:
			_hide()


func show_messages(message_list: Array, position: Vector2) -> void:
	if _is_active:
		return

	_is_active = true
	_messages = message_list
	_active_dialogue_offset = 0

	var dialogue := DIALOGUE_SCENE.instantiate()
	get_tree().current_scene.add_child(dialogue)

	dialogue.global_position = position
	dialogue.modulate.a = 0.0
	dialogue.message_completed.connect(_on_message_completed)

	cur_dialogue_instance = dialogue

	# Fade IN
	var tween := create_tween()
	tween.tween_property(dialogue, "modulate:a", 1.0, 0.2)

	await tween.finished

	_show_current()


func _show_current() -> void:
	message_requested.emit()
	cur_dialogue_instance.update_message(_messages[_active_dialogue_offset])


func _hide() -> void:
	cur_dialogue_instance.message_completed.disconnect(_on_message_completed)

	# Fade OUT
	var tween := create_tween()
	tween.tween_property(cur_dialogue_instance, "modulate:a", 0.0, 0.2)

	await tween.finished

	cur_dialogue_instance.queue_free()
	cur_dialogue_instance = null
	_is_active = false

	finished.emit()


func _on_message_completed() -> void:
	message_completed.emit()

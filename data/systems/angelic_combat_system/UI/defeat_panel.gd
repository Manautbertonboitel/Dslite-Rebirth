extends Control
class_name DefeatPanel

signal retry_pressed

@export var retry_button: Button

func _ready():
	visible = false
	if retry_button:
		retry_button.pressed.connect(_on_retry)

func _on_retry():
	retry_pressed.emit()

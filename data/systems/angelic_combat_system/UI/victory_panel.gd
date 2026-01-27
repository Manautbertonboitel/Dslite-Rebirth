extends Control
# Attach to a Panel/Control node with labels and button

signal continue_pressed

@export var xp_label: Label
@export var gold_label: Label
@export var items_label: Label
@export var continue_button: Button

func _ready():
	visible = false
	if continue_button:
		continue_button.pressed.connect(_on_continue)

func show_results(xp: int, gold: int, items: Array):
	visible = true
	
	if xp_label:
		xp_label.text = "XP Gained: %d" % xp
	if gold_label:
		gold_label.text = "Gold Gained: %d" % gold
	if items_label:
		var item_names = ""
		for item in items:
			item_names += item.item_name + "\n"
		items_label.text = "Items:\n" + item_names

func _on_continue():
	continue_pressed.emit()

extends Control

signal action_chosen(action)

func show_actions(hero):
	# Vider l’UI
	for child in $VBoxContainer.get_children():
		child.queue_free()
	
	for action in hero.actions:
		var btn = Button.new()
		btn.text = action.action_name
		btn.pressed.connect(func(): emit_signal("action_chosen", action))
		$VBoxContainer.add_child(btn)

	visible = true

extends Control

signal target_chosen(target)

func show_targets(enemies: Array):
	# Vider les anciens boutons
	for child in $VBoxContainer.get_children():
		child.queue_free()

	for enemy in enemies:
		if enemy.is_alive():
			var btn = Button.new()
			btn.text = enemy.character_name
			btn.pressed.connect(func():emit_signal("target_chosen", enemy))
			$VBoxContainer.add_child(btn)

	visible = true

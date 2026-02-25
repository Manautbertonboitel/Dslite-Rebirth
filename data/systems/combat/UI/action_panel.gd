extends Control

signal action_chosen(action: AttackAction)

func show_actions(fighter: Fighter):
	# Vider l’UI
	for child in $VBoxContainer.get_children():
		child.queue_free()
	
	if fighter.actions == null:
		print_debug("%s doesn't have any actions, Action UI isn't displayable" % fighter.character_name)
	else:
		for action in fighter.actions:
			var btn = Button.new()
			btn.text = action.action_name
			btn.pressed.connect(func(): emit_signal("action_chosen", action))
			$VBoxContainer.add_child(btn)

		visible = true

#TODO Afficher / griser le bouton ROLL selon si on est en dodge window ou non 

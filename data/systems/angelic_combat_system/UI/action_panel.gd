extends Control

signal action_chosen(action: Action)

func show_actions(hero: Fighter):
	# Vider l’UI
	for child in $VBoxContainer.get_children():
		child.queue_free()
	
	if hero.actions == null:
		print_debug("%s doesn't have any actions, Action UI isn't displayable" % hero.character_name)
	else:
		for action in hero.actions:
			var btn = Button.new()
			btn.text = action.action_name
			btn.pressed.connect(func(): emit_signal("action_chosen", action))
			$VBoxContainer.add_child(btn)

		visible = true

#TODO Afficher / griser le bouton ROLL selon si on est en dodge window ou non 
#func _process(delta):
#	if $"../CombatManager".dodge_window_active:
#		for action in hero.actions:
			

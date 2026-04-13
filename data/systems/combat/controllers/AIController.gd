class_name AIController
extends FighterController

var action: Action
var target: Fighter 

func take_turn(fighter: Fighter, combat_manager: CombatManager) -> void:
	action = choose_action(fighter)
	
	if not action.requires_target_selection:
		# Actions auto-ciblées (AOE, Flee, Self)
		combat_manager.submit_action(fighter, action, null)
		return
	else:
		# Actions nécessitant une sélection de cible
		var valid_targets: Array[Fighter] = action.get_valid_targets(fighter, combat_manager)

		if valid_targets.is_empty():
			push_error("No valid targets for this action")
			#TODO Que faire si la AI choisi une action pas utilisable car pas de valid targets ?
			return

		target = valid_targets.pick_random()

	if action == null or target == null:
		print("AI action or target null, skipped turn:", fighter.character_name)
		fighter.reset_atb()
		return

	combat_manager.submit_action(fighter, action, target)

func choose_action(fighter: Fighter) -> Action:
	if fighter.actions.is_empty():
		return null
	return fighter.actions.pick_random()
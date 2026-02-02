extends FighterController
class_name AIController

func take_turn(fighter: Fighter, combat_manager: CombatManager) -> void:
	var action: Action = choose_action(fighter)
	var target: Fighter = choose_target(fighter, combat_manager)

	if action == null or target == null:
		print("AI skipped turn:", fighter.character_name)
		fighter.reset_atb()
		return

	combat_manager.submit_action(fighter, target, action)


func choose_action(fighter: Fighter) -> Action:
	if fighter.actions.is_empty():
		return null
	return fighter.actions[0]


func choose_target(fighter: Fighter, combat_manager: Node) -> Fighter:
	var targets = combat_manager.get_hostile_targets(fighter)
	if targets.is_empty():
		return null
	return targets[0]

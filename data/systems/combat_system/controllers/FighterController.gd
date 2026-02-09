extends Node
class_name FighterController

func take_turn(fighter: Fighter, combat_manager: CombatManager) -> void:
	push_error("take_turn() must be implemented by subclass")

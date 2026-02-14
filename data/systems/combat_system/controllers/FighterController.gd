extends Node
class_name FighterController

func take_turn(fighter: Fighter, combat_manager: CombatManager) -> void:
	push_error("take_turn() must be implemented by subclass")

#TODO Vu que les IA ne vont plus dans la ready queue, peut-être plus besoin de séparer les controller en AIController et PlayerController

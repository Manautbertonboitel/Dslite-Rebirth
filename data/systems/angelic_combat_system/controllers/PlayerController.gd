extends Node
class_name PlayerController

func take_turn(fighter: Fighter, combat_manager: Node) -> void:
	# Player input → delegate to UI
	combat_manager.show_action_menu(fighter)

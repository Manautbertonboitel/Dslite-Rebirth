extends Node
class_name BattleState

var state_name: String

func _init() -> void:
	state_name = name

func enter(manager: CombatManager) -> void:
	pass

func update(manager: CombatManager, delta: float) -> void:
	pass

func exit(manager: CombatManager) -> void:
	pass

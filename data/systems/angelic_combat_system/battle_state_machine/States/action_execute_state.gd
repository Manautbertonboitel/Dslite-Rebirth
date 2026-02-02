extends BattleState
class_name ActionExecuteState

var state_name: String = "Action Execute State"

func enter(manager: CombatManager):
	manager.resolve_next_action()

func update(manager: CombatManager, delta: float):
	pass

func exit(manager: CombatManager):
	pass

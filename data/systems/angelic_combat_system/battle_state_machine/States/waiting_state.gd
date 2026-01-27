extends BattleState
class_name WaitingState

func enter(manager: CombatManager) -> void:
	pass

func update(manager: CombatManager, delta: float):

	if not manager.action_queue.is_empty():
		manager.state_machine.change_state(ActionExecuteState.new())
		return

func exit(manager: CombatManager) -> void:
	pass

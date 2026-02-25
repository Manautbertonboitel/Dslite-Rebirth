extends CombatState
class_name WaitingState

var state_name: String = "Waiting State"

func enter(manager: CombatManager) -> void:
	pass
	
func update(manager: CombatManager, delta: float):

	if not manager.action_queue.is_empty():
		manager.state_machine.change_state(manager.state_machine.action_execute_state)
		return

func exit(manager: CombatManager) -> void:
	pass

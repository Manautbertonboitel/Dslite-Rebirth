class_name WaitingState
extends CombatState

var state_name: String = "Waiting State"

func enter(_manager: CombatManager) -> void:
	pass
	
func update(manager: CombatManager, _delta: float):

	if not manager.action_queue.is_empty():
		manager.state_machine.change_state(manager.state_machine.action_execute_state)
		return

func exit(_manager: CombatManager) -> void:
	pass

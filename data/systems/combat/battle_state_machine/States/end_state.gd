# EndState.gd
extends CombatState
class_name EndState

var state_name: String = "End State"

func enter(manager: CombatManager):
	manager.set_time_paused(true)
	
func update(manager: CombatManager, delta: float):
	pass
	
func exit(manager: CombatManager):
	pass

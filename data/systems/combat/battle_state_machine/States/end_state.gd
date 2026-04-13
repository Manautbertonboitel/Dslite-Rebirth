# EndState.gd
extends CombatState
class_name EndState

var state_name: String = "End State"

func enter(manager: CombatManager):
	manager.set_time_paused(true)
	
func update(_manager: CombatManager, _delta: float):
	pass
	
func exit(_manager: CombatManager):
	pass

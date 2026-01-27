# EndState.gd
extends BattleState
class_name EndState

func enter(manager: CombatManager):
	manager.set_time_paused(true)
	
func update(manager: CombatManager, delta: float):
	pass
	
func exit(manager: CombatManager):
	pass

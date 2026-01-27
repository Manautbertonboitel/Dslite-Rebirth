# CheckState.gd
extends BattleState
class_name CheckState

func enter(manager: CombatManager):
	manager.evaluate_battle_state()

	if manager.state_machine.current_state is EndState:
		return

	manager.state_machine.change_state(WaitingState.new())

func update(manager: CombatManager, delta: float):
	pass
	
func exit(manager: CombatManager):
	pass

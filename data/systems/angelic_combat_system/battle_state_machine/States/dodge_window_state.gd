# ActionExecuteState.gd
extends BattleState
class_name DodgeWindowState

var state_name: String = "Action Execute State (Dodge Window Context)"

func enter(manager: CombatManager):
	pass

func update(manager: CombatManager, delta: float):
	# Dodge window timer
	if manager.dodge_window_active:
		manager.dodge_window_timer -= delta
		if manager.dodge_window_timer <= 0.0:
			manager.dodge_resolved.emit(false)

func exit(manager: CombatManager):
	pass

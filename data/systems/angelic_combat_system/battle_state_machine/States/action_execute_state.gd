# ActionExecuteState.gd
extends BattleState
class_name ActionExecuteState

func enter(manager: CombatManager):
	manager._resolve_next_action()

func update(manager: CombatManager, delta: float):
	# Dodge window timer
	if manager.dodge_window_active:
		manager.dodge_window_timer -= delta
		if manager.dodge_window_timer <= 0.0:
			manager.dodge_resolved.emit(false)

func exit(manager: CombatManager):
	pass

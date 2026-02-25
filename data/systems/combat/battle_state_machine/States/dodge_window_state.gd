extends CombatState
class_name DodgeWindowState

var state_name: String = "Dodge Window State"

func enter(combat_manager: CombatManager):
	print("[STATE] Entered Dodge Window")
	combat_manager.set_time_paused(false)  # Permettre aux joueurs d'agir

func update(combat_manager: CombatManager, delta: float):
	if not combat_manager.dodge_window_active:
		return
	
	combat_manager.dodge_window_timer -= delta
	
	if combat_manager.dodge_window_timer <= 0:
		# Timeout - personne n'a esquivé
		combat_manager.dodge_window_active = false
		combat_manager.dodge_resolved.emit(false)
		combat_manager.change_state(combat_manager.action_execute_state)

func exit(combat_manager: CombatManager):
	combat_manager.dodge_window_active = false

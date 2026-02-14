extends Node
class_name CombatStateMachine

var combat_manager: CombatManager
var current_state: CombatState

var waiting_state
var action_execute_state
var dodge_window_state
var end_state

func _init(mgr: CombatManager):
	combat_manager = mgr
	
	waiting_state = WaitingState.new()
	action_execute_state = ActionExecuteState.new()
	end_state = EndState.new()
	dodge_window_state = DodgeWindowState.new()

func update(delta: float) -> void:
	if current_state:
		current_state.update(combat_manager, delta)

func change_state(new_state: CombatState) -> void:

	if current_state:
		current_state.exit(combat_manager)

	current_state = new_state
	combat_manager.state_name = current_state.state_name
	current_state.enter(combat_manager)

extends Node
class_name BattleStateMachine

var combat_manager: CombatManager
var current_state: BattleState

var waiting_state: BattleState
var action_execute_state: BattleState
var end_state: BattleState

var states: Dictionary[String, BattleState] = {}

func _init(mgr: CombatManager):
	combat_manager = mgr
	
	waiting_state = WaitingState.new()
	action_execute_state = ActionExecuteState.new()
	end_state = EndState.new()

func update(delta: float) -> void:
	if current_state:
		current_state.update(combat_manager, delta)

func change_state(new_state: BattleState) -> void:

	if current_state:
		print("Transitioning from %s state to %s state" % [current_state.state_name, new_state.state_name])
		current_state.exit(combat_manager)

	current_state = new_state
	current_state.enter(combat_manager)

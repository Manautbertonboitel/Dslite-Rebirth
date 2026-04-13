class_name CombatManager
extends Node
## Gestion générale du combat


class PositionMapping extends Node:
## Sous classe pour gérer les positionnement des persos dans la croix de positions
	var up: Node3D
	var right: Node3D
	var down: Node3D
	var left: Node3D
	
	func get_pos_node(pos: Formation.Position) -> Node3D:
		match pos:
			Formation.Position.UP: return up
			Formation.Position.RIGHT: return right
			Formation.Position.DOWN: return down
			Formation.Position.LEFT: return left
		return null
	
	func is_valid() -> bool:
		return up != null and right != null and down != null and left != null


# --------------------------------------------------------------------
# VARIABLES
# --------------------------------------------------------------------

signal dodge_resolved(result: float)

# CONSTANTS TODO replace them by real animations
const ACTION_ANIMATION_TIME: float = 0.5
const DAMAGE_DELAY_TIME: float = 0.2

# STATE MACHINE
var state_machine: CombatStateMachine

# STATE DATA (used by states) TODO transform in sub states or contexts
var dodge_window_active: bool = false
var dodge_window_timer: float = 0.0

var pending_attack_caster: Fighter = null
var pending_attack_target: Fighter = null
var pending_attack_action: AttackAction = null

# CORE COMBAT CONTEXT
var fighters: Array[Fighter] = []
var current_player_character: Fighter = null

# QUEUES & FLOW CONTROL
var ready_queue: Array[Fighter] = []
var action_queue: Array[ActionRequest] = []

# TIME & FLOW FLAGS
var time_paused: bool = false

# VICTORY EVALUATION & REWARDS
var victory_condition: VictoryCondition = DefaultVictoryCondition.new()
var defeated_enemies_data: Array[FighterData] = []

# FORMATION & POSITIONS
var hero_formation: Formation = Formation.new()
var enemy_formation: Formation = Formation.new()

var hero_position_mapping: PositionMapping
var enemy_position_mapping: PositionMapping

# 3D VISUAL SETUP
@export_group("3D Visual Setup")
@export var models_container: Node3D

@export_subgroup("Hero Positions")
@export var hero_pos_up: Node3D
@export var hero_pos_right: Node3D
@export var hero_pos_down: Node3D
@export var hero_pos_left: Node3D

@export_subgroup("Enemy Positions")
@export var enemy_pos_up: Node3D
@export var enemy_pos_right: Node3D
@export var enemy_pos_down: Node3D
@export var enemy_pos_left: Node3D

# UI
@export_subgroup("UI")
@export var action_panel: Control
@export var target_panel: Control
@export var defeat_panel: Control
@export var victory_panel: Control
@export var heroes_ui_container: HBoxContainer
@export var enemies_ui_container: HBoxContainer
@export var character_ui_prefab: PackedScene

# DEBUG
@export_subgroup("DEBUG")
@export var fighter_ui_queue: VBoxContainer
@export var action_ui_queue: VBoxContainer
var debug_queue_enabled: bool = false
var debug_dodge_window_timer_enabled: bool = false
var debug_formation_enabled: bool = false
@export var state_debug: Label

# --------------------------------------------------------------------
# INITIALIZATION & VALIDATION
# --------------------------------------------------------------------

func _ready() -> void:
	if not _validate_setup():
		push_error("[SETUP] Combat Manager setup failed! Check inspector assignments.")
		return
	
	_initialize_position_mappings()

	state_machine = CombatStateMachine.new(self)
	
	start_battle(
		GameManager.combat_heroes_pool,
		GameManager.combat_enemies_pool,
		GameManager.combat_atb_advantage
	)


func _validate_setup() -> bool:
	"""Validate all required nodes are assigned correctly"""
	var errors: Array[String] = []
	
	# Check UI components
	if not action_panel:
		errors.append("[SETUP] action_panel is not assigned")
	if not target_panel:
		errors.append("[SETUP] target_panel is not assigned")
	if not models_container:
		errors.append("[SETUP] models_container is not assigned")
	
	# Check hero positions
	if not hero_pos_up:
		errors.append("[SETUP] hero_pos_up is not assigned")
	if not hero_pos_right:
		errors.append("[SETUP] hero_pos_right is not assigned")
	if not hero_pos_down:
		errors.append("[SETUP] hero_pos_down is not assigned")
	if not hero_pos_left:
		errors.append("[SETUP] hero_pos_left is not assigned")
	
	# Check enemy positions
	if not enemy_pos_up:
		errors.append("[SETUP] enemy_pos_up is not assigned")
	if not enemy_pos_right:
		errors.append("[SETUP] enemy_pos_right is not assigned")
	if not enemy_pos_down:
		errors.append("[SETUP] enemy_pos_down is not assigned")
	if not enemy_pos_left:
		errors.append("[SETUP] enemy_pos_left is not assigned")
	
	if not errors.is_empty():
		push_error("[SETUP] Combat Manager validation errors:\n  - " + "\n  - ".join(errors))
		return false
	
	return true


func _initialize_position_mappings() -> void:
	hero_position_mapping = PositionMapping.new()
	hero_position_mapping.up = hero_pos_up
	hero_position_mapping.right = hero_pos_right
	hero_position_mapping.down = hero_pos_down
	hero_position_mapping.left = hero_pos_left
	
	enemy_position_mapping = PositionMapping.new()
	enemy_position_mapping.up = enemy_pos_up
	enemy_position_mapping.right = enemy_pos_right
	enemy_position_mapping.down = enemy_pos_down
	enemy_position_mapping.left = enemy_pos_left
	
	if not hero_position_mapping.is_valid():
		push_error("[SETUP] Hero position mapping incomplete!")
	if not enemy_position_mapping.is_valid():
		push_error("[SETUP] Enemy position mapping incomplete!")


# --------------------------------------------------------------------
# BATTLE START
# --------------------------------------------------------------------

func start_battle(heroes_pool: FighterPool, enemies_pool: FighterPool, atb_advantage: bool):
	print("=== Combat Start ===")

	fighters.clear()
	ready_queue.clear()
	defeated_enemies_data.clear()

	for data in heroes_pool.fighters:
		_spawn_fighter(data, Faction.Type.PLAYER, heroes_ui_container, atb_advantage)

	for data in enemies_pool.fighters:
		_spawn_fighter(data, Faction.Type.ENEMY, enemies_ui_container, false)

	if debug_formation_enabled and OS.is_debug_build():
		print("\n📍 Hero Formation:")
		print(hero_formation.get_formation_visual_string())
		print("\n📍 Enemy Formation:")
		print(enemy_formation.get_formation_visual_string())

	for fighter in fighters:
		fighter.ready_to_act.connect(_on_fighter_ready)
		fighter.died.connect(_on_fighter_died)
		
	state_machine.change_state(state_machine.waiting_state)


func _spawn_fighter(data: FighterData, faction: Faction.Type, ui_container: HBoxContainer, atb_advantage: bool) -> void:
	# Create fighter logic node
	var fighter: Fighter = data.instantiate()
	if not fighter:
		push_error("Failed to instantiate fighter from data: %s" % data.character_name)
		return
	
	add_child(fighter)
	fighter.faction = faction
	
	# Assign controller
	if faction == Faction.Type.PLAYER:
		fighter.controller = PlayerController.new()
	else:
		fighter.controller = AIController.new()

	# Get formation and position mapping
	var formation: Formation
	var position_mapping: PositionMapping
	
	if faction == Faction.Type.PLAYER:
		formation = hero_formation
		position_mapping = hero_position_mapping
	else:
		formation = enemy_formation
		position_mapping = enemy_position_mapping

	# Find first available slot
	var assigned_position = formation.find_first_empty_slot()
	
	if assigned_position == null:
		push_error("No available formation slot for %s" % data.character_name)
		fighter.queue_free()
		return
	
	# Assign to formation
	if not formation.assign_fighter(fighter, assigned_position):
		push_error("Failed to assign %s to formation" % data.character_name)
		fighter.queue_free()
		return

	# Spawn 3D visual representation
	if data.fighter_3d_scene and models_container:
		var visuals: FighterVisuals = FighterVisuals.new()
		models_container.add_child(visuals)
		
		if visuals.setup(data, fighter):
			fighter.set_visuals(visuals)
			
			# Position the visual at the formation position
			var target_node: Node3D = position_mapping.get_pos_node(assigned_position)
			if target_node:
				visuals.set_initial_position(target_node.global_transform)
			else:
				push_warning("No position node for %s at %s" % [
					data.character_name, 
					Formation.Position.keys()[assigned_position]
				])
		else:
			push_warning("Failed to setup 3D visuals for %s" % data.character_name)
			visuals.queue_free()

	# ATB advantage
	if atb_advantage:
		fighter.atb = 50.0

	# Create UI display
	if character_ui_prefab:
		var ui: Node = character_ui_prefab.instantiate()
		ui_container.add_child(ui)
		ui.fighter = fighter

	fighters.append(fighter)
	print("[SPAWN] %s added to %s formation at %s position" % [
		fighter.character_name,
		"HERO" if faction == Faction.Type.PLAYER else "ENEMY",
		Formation.Position.keys()[assigned_position]
	])


# --------------------------------------------------------------------
# PROCESS LOOP
# --------------------------------------------------------------------

func _process(delta):
	# Handle dodge window countdown
	if dodge_window_active:
		dodge_window_timer -= delta

		if debug_dodge_window_timer_enabled and OS.is_debug_build():
			if int(dodge_window_timer * 2) != int((dodge_window_timer + delta) * 2):
				print("⏰ Dodge window: %.1fs remaining" % dodge_window_timer)

		if dodge_window_timer <= 0.0:
			dodge_resolved.emit(false)

	if not ready_queue.is_empty() and not ready_queue[0].is_chosing:
		process_next_ready_fighter()

	# TODO Pas trop sûr à quoi ça sert ça, pk on utilise pas le _process() de la state machine
	state_machine.update(delta)
	
	
# --------------------------------------------------------------------
# TIME MANAGEMENT
# --------------------------------------------------------------------

func set_time_paused(value: bool) -> void:
	if time_paused == value:
		return
	time_paused = value
	for fighter in fighters:
		fighter.pause_atb(time_paused)


# --------------------------------------------------------------------
# TURN FLOW
# --------------------------------------------------------------------

func _on_fighter_ready(fighter: Fighter) -> void:
	if not fighter.is_alive():
		return
	
	if fighter.controller is PlayerController:
		# Player fighters go into ready_queue
		if not ready_queue.has(fighter):
			ready_queue.append(fighter)
			update_ready_queue_debug()
	
	# AI fighters bypass the ready_queue and submits action directly
	elif fighter.controller is AIController:
		fighter.controller.take_turn(fighter, self)
	
	else:
		print("WTF c'est ni un PlayerController ni un AIController qui est ready à faire une action ya un gros pb la team")


func process_next_ready_fighter() -> void:

	# Clean up dead fighters from queue
	while not ready_queue.is_empty() and not ready_queue[0].is_alive():
		var dead_fighter = ready_queue.pop_front()
		print("[FIGHTER QUEUE] Skipped and Removed dead fighter from queue: %s" % dead_fighter.character_name)
		update_ready_queue_debug()
	
	if ready_queue.is_empty():
		return

	# On récupère le premier fighter de la ready queue
	current_player_character = ready_queue[0]

	ready_queue[0].controller.take_turn(ready_queue[0], self)


# --------------------------------------------------------------------
# ACTION CHOSE AND REQUEST FLOW
# --------------------------------------------------------------------

func show_action_menu(fighter: Fighter):
	action_panel.show_actions(fighter)
	action_panel.action_chosen.connect(_on_action_chosen, CONNECT_ONE_SHOT)


func _on_action_chosen(action: Action) -> void:
	if action == null:
		return
	
	action_panel.visible = false
	ready_queue[0].selected_action = action
	
	if not action.can_execute(ready_queue[0], self):
		print("Action '%s' cannot be executed" % action.action_name)
		action_panel.show_actions(ready_queue[0])
		action_panel.action_chosen.connect(_on_action_chosen, CONNECT_ONE_SHOT)
		return
	
	if not action.requires_target_selection:
		# Actions auto-ciblées (AOE, Flee, Self)
		submit_action(ready_queue[0], action, null)
		ready_queue[0].is_chosing = false
		ready_queue.pop_front()
	else:
		# Actions nécessitant une sélection de cible
		var valid_targets: Array[Fighter] = action.get_valid_targets(ready_queue[0], self)
		
		if valid_targets.is_empty():
			print("No valid targets for this action")
			action_panel.show_actions(ready_queue[0])
			action_panel.action_chosen.connect(_on_action_chosen, CONNECT_ONE_SHOT)
			return
		
		target_panel.show_targets(valid_targets)
		target_panel.target_chosen.connect(_on_target_chosen, CONNECT_ONE_SHOT)


func _on_target_chosen(target: Fighter):
	if target == null:
		return
		
	target_panel.visible = false
	
	submit_action(ready_queue[0], ready_queue[0].selected_action, target)
	ready_queue[0].is_chosing = false
	ready_queue.pop_front()

func submit_action(caster: Fighter, action: Action, target: Fighter):
	if action.can_bypass_action_queue:
		action.execute(caster, self, target)
		#ready_queue.pop_front()
		#current_player_character.is_chosing = false
	else:
		var action_request: ActionRequest = ActionRequest.new(caster, action, target)
		action_queue.append(action_request)
		
		update_action_queue_debug()
	
	
# --------------------------------------------------------------------
# DODGE MANAGEMENT
# --------------------------------------------------------------------

func start_dodge_window(caster: Fighter, target: Fighter, duration: float):
	print("[DODGE WINDOW] %s is attacking %s - ROLL to dodge!" % [caster.character_name, target.character_name])

	dodge_window_active = true
	dodge_window_timer = duration

	# Show visual indicators
	if target.visuals:
		target.visuals.show_dodge_indicator()

	pending_attack_target = target
	pending_attack_caster = caster

	# set_time_paused(false)


#func _execute_dodge_action(fighter: Fighter) -> void:
#
#	var formation: Formation = hero_formation if fighter.faction == Faction.Type.PLAYER else enemy_formation
#	var position_mapping: PositionMapping = hero_position_mapping if fighter.faction == Faction.Type.PLAYER else enemy_position_mapping
#
#	if not formation.can_dodge():
#		return
#
#	# Perform the dodge
#	formation.dodge_clockwise()
#	
#	# Update 3D visual positions
#	formation.update_visual_positions(position_mapping, ACTION_ANIMATION_TIME)
#	
#	dodge_resolved.emit(true)
#	
#	# Clear visual indicators
#	if pending_attack_target and pending_attack_target.visuals:
#		pending_attack_target.visuals.hide_dodge_indicator()
#	if pending_attack_caster and pending_attack_caster.visuals:
#		pending_attack_caster.visuals.clear_attack_indicator()
#		
#	pending_attack_target = null
#	pending_attack_caster = null
#	
#	fighter.reset_atb()
#	evaluate_battle_state()


# --------------------------------------------------------------------
# DEATH & VICTORY
# --------------------------------------------------------------------

func _on_fighter_died(fighter: Fighter):
	print("[DEATH] %s has died" % fighter.character_name)
	
	# Record defeated enemies for rewards
	if fighter.faction == Faction.Type.ENEMY and fighter.original_data:
		if not defeated_enemies_data.has(fighter.original_data):
			defeated_enemies_data.append(fighter.original_data)
	
	# Remove from formation
	var formation: Formation = hero_formation if fighter.faction == Faction.Type.PLAYER else enemy_formation
	formation.remove_fighter(fighter)
	
	# Remove from ready queue if present
	if ready_queue.has(fighter):
		ready_queue.erase(fighter)
		print("[FIGHTER QUEUE] Removed dead fighter from queue: %s" % fighter.character_name)
	
	# If this was the current character, reset
	if current_player_character == fighter:
		current_player_character = null
		#state = BattleState.WAITING
	
	if debug_formation_enabled and OS.is_debug_build():
		formation.print_formation_state()


func evaluate_battle_state():

	var result: VictoryCondition.Result = victory_condition.evaluate(fighters)

	match result:
		VictoryCondition.Result.ONGOING:
			state_machine.change_state(state_machine.waiting_state)
			pass
		VictoryCondition.Result.VICTORY:
			end_battle(true)
		VictoryCondition.Result.DEFEAT:
			end_battle(false)


func end_battle(victory: bool):

	state_machine.change_state(state_machine.end_state)

	if victory:
		victory_panel.visible = true
		victory_panel.continue_pressed.connect(_on_victory_continue)
	else:
		defeat_panel.visible = true
		defeat_panel.retry_pressed.connect(_on_defeat_retry)


func _on_victory_continue():
	GameManager.end_combat(true, defeated_enemies_data)


func _on_defeat_retry():
	GameManager.end_combat(false, [])


# --------------------------------------------------------------------
# DEBUG
# --------------------------------------------------------------------

func update_ready_queue_debug() -> void:	
	for child in fighter_ui_queue.get_children():
		child.queue_free()
		
	for fighter: Fighter in ready_queue:
		var lbl: Label = Label.new()
		lbl.text = fighter.character_name
		fighter_ui_queue.add_child(lbl)
			

func update_action_queue_debug() -> void:
	for child in action_ui_queue.get_children():
		child.queue_free()
		
	for action_request: ActionRequest in action_queue:
		var lbl: Label = Label.new()
		lbl.text = action_request.action.action_name
		action_ui_queue.add_child(lbl)

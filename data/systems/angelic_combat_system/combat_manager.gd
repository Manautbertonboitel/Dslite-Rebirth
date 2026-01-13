extends Node

enum BattleState {
	START,
	WAITING,
	ACTION_SELECT,
	ACTION_EXECUTE,
	CHECK,
	END
}

const ACTION_ANIMATION_TIME = 0.5
const DAMAGE_DELAY_TIME = 0.2
const DODGE_WINDOW_DURATION = 5.0

# --------------------------------------------------------------------
# POSITION MAPPING (NEW)
# --------------------------------------------------------------------

class PositionMapping:
	var up: Node3D
	var right: Node3D
	var down: Node3D
	var left: Node3D
	
	func get_node(pos: Formation.Position) -> Node3D:
		match pos:
			Formation.Position.UP: return up
			Formation.Position.RIGHT: return right
			Formation.Position.DOWN: return down
			Formation.Position.LEFT: return left
		return null
	
	func is_valid() -> bool:
		return up != null and right != null and down != null and left != null

# --------------------------------------------------------------------
# CORE STATE
# --------------------------------------------------------------------

var fighters: Array[Fighter] = []
var ready_queue: Array[Fighter] = []

var state: BattleState = BattleState.START
var current_character: Fighter = null
var time_paused: bool = false

# Rewards
var defeated_enemies_data: Array[FighterData] = []

# Victory evaluation
var victory_condition: VictoryCondition = DefaultVictoryCondition.new()

# UI
@export var action_panel: Control
@export var target_panel: Control
@export var defeat_panel: Control
@export var victory_panel: Control
@export var heroes_ui_container: VBoxContainer
@export var enemies_ui_container: VBoxContainer
@export var character_ui_prefab: PackedScene

# 3D VISUALS (NEW)
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

var hero_position_mapping: PositionMapping
var enemy_position_mapping: PositionMapping

# FORMATION
var hero_formation: Formation = Formation.new()
var enemy_formation: Formation = Formation.new()

# DODGE WINDOW
var dodge_window_active: bool = false
var dodge_window_timer: float = 0.0
var pending_attack_caster: Fighter = null
var pending_attack_target: Fighter = null
var pending_attack_action: Action = null

# INTERRUPT HANDLING
var interrupted_player: Fighter = null
var player_was_selecting: bool = false

# DEBUG
var debug_queue_enabled: bool = true
var debug_dodge_window_timer_enabled: bool = false
var debug_formation_enabled: bool = false

# --------------------------------------------------------------------
# INITIALIZATION & VALIDATION
# --------------------------------------------------------------------

func _ready():
	if not _validate_setup():
		push_error("❌ Combat Manager setup failed! Check inspector assignments.")
		return
	
	_initialize_position_mappings()
	
	var heroes_pool = GameManager.combat_heroes_pool
	var enemies_pool = GameManager.combat_enemies_pool
	var atb_advantage = GameManager.combat_atb_advantage

	assert(heroes_pool != null, "Heroes pool is null")
	assert(enemies_pool != null, "Enemies pool is null")

	start_battle(heroes_pool, enemies_pool, atb_advantage)


func _validate_setup() -> bool:
	"""Validate all required nodes are assigned correctly"""
	var errors: Array[String] = []
	
	# Check UI components
	if not action_panel:
		errors.append("action_panel is not assigned")
	if not target_panel:
		errors.append("target_panel is not assigned")
	if not models_container:
		errors.append("models_container is not assigned")
	
	# Check hero positions
	if not hero_pos_up:
		errors.append("hero_pos_up is not assigned")
	if not hero_pos_right:
		errors.append("hero_pos_right is not assigned")
	if not hero_pos_down:
		errors.append("hero_pos_down is not assigned")
	if not hero_pos_left:
		errors.append("hero_pos_left is not assigned")
	
	# Check enemy positions
	if not enemy_pos_up:
		errors.append("enemy_pos_up is not assigned")
	if not enemy_pos_right:
		errors.append("enemy_pos_right is not assigned")
	if not enemy_pos_down:
		errors.append("enemy_pos_down is not assigned")
	if not enemy_pos_left:
		errors.append("enemy_pos_left is not assigned")
	
	if not errors.is_empty():
		push_error("Combat Manager validation errors:\n  - " + "\n  - ".join(errors))
		return false
	
	return true


func _initialize_position_mappings() -> void:
	"""Set up position mappings from exported Node3D references"""
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
		push_error("Hero position mapping incomplete!")
	if not enemy_position_mapping.is_valid():
		push_error("Enemy position mapping incomplete!")


# --------------------------------------------------------------------
# BATTLE START
# --------------------------------------------------------------------

func start_battle(heroes_pool: FighterPool, enemies_pool: FighterPool, atb_advantage: bool):
	print("=== Combat Start ===")

	state = BattleState.START
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

	state = BattleState.WAITING


func _spawn_fighter(data: FighterData, faction: Faction.Type, ui_container: VBoxContainer, atb_advantage: bool) -> void:
	"""Spawn a fighter with logic, UI, and 3D visuals"""
	
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
		var visuals = FighterVisuals.new()
		models_container.add_child(visuals)
		
		if visuals.setup(data, fighter):
			fighter.set_visuals(visuals)
			
			# Position the visual at the formation position
			var target_node = position_mapping.get_node(assigned_position)
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
		var ui = character_ui_prefab.instantiate()
		ui_container.add_child(ui)
		ui.fighter = fighter

	fighters.append(fighter)
	print("✅ [SPAWN] %s added to %s formation at %s" % [
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
			_execute_pending_attack()

	if state == BattleState.WAITING and not ready_queue.is_empty():
		process_next_ready_fighter()


func set_time_paused(value: bool):
	if time_paused == value:
		return
	time_paused = value
	for fighter in fighters:
		fighter.pause_atb(time_paused)


func _validate_state(expected: BattleState, context: String) -> bool:
	if state != expected:
		push_error("Invalid state in %s: expected %s, got %s" % [
			context, 
			BattleState.keys()[expected], 
			BattleState.keys()[state]
		])
		return false
	return true


# --------------------------------------------------------------------
# TURN FLOW
# --------------------------------------------------------------------

func _on_fighter_ready(fighter: Fighter):
	if not fighter.is_alive():
		return

	# AI fighters can interrupt
	if fighter.controller is AIController:
		if not ready_queue.has(fighter):
			ready_queue.append(fighter)
			print("➕ [QUEUE] AI added: %s" % fighter.character_name)
			_print_queue_snapshot()
		
		if state == BattleState.WAITING:
			return
		
		_process_ai_turn_immediate(fighter)
	else:
		# Player fighters go into queue normally
		if not ready_queue.has(fighter):
			ready_queue.append(fighter)
			print("➕ [QUEUE] PLAYER added: %s" % fighter.character_name)
			_print_queue_snapshot()


func process_next_ready_fighter():
	if not _validate_state(BattleState.WAITING, "process_next_ready_fighter"):
		return

	# Clean up dead fighters from queue
	while not ready_queue.is_empty() and not ready_queue[0].is_alive():
		var dead_fighter = ready_queue.pop_front()
		print("💀 [QUEUE] Skipping dead fighter: %s" % dead_fighter.character_name)
	
	if ready_queue.is_empty():
		return

	current_character = ready_queue.pop_front()
	print("⚡ [QUEUE] Processing: %s" % current_character.character_name)
	_print_queue_snapshot()

	begin_turn(current_character)


func _process_ai_turn_immediate(fighter: Fighter):
	print("⚠️ [QUEUE] AI INTERRUPT: %s" % fighter.character_name)
	_print_queue_snapshot()

	if current_character and current_character.controller is PlayerController and state == BattleState.ACTION_SELECT:
		interrupted_player = current_character
		player_was_selecting = true
		print("💾 [INTERRUPT] Saving player context: %s" % interrupted_player.character_name)

	var previous_character = current_character
	current_character = fighter

	var action: Action = fighter.controller.choose_action(fighter)
	var target: Fighter = fighter.controller.choose_target(fighter, self)

	if action == null or target == null:
		print("AI skipped turn:", fighter.character_name)
		fighter.reset_atb()
		current_character = previous_character
		return

	state = BattleState.ACTION_SELECT
	submit_action(fighter, target, action)


func begin_turn(fighter: Fighter):
	if not _validate_state(BattleState.WAITING, "begin_turn"):
		return

	state = BattleState.ACTION_SELECT
	print("🎮 [TURN START] %s begins turn" % fighter.character_name)
	_print_queue_snapshot()

	fighter.controller.take_turn(fighter, self)


# --------------------------------------------------------------------
# PLAYER FLOW
# --------------------------------------------------------------------

func show_action_menu(fighter: Fighter):
	if not _validate_state(BattleState.ACTION_SELECT, "show_action_menu"):
		return

	action_panel.show_actions(fighter)
	action_panel.action_chosen.connect(_on_action_chosen, CONNECT_ONE_SHOT)


func _on_action_chosen(action):
	if not _validate_state(BattleState.ACTION_SELECT, "_on_action_chosen"):
		return

	if action == null:
		push_error("Null action chosen")
		state = BattleState.WAITING
		return

	action_panel.visible = false

	if action is RollAction:
		execute_roll_action(current_character)
	else:
		current_character.selected_action = action
		var targets = get_hostile_targets(current_character)
		target_panel.show_targets(targets)
		target_panel.target_chosen.connect(_on_target_chosen, CONNECT_ONE_SHOT)


func _on_target_chosen(target: Fighter):
	if not _validate_state(BattleState.ACTION_SELECT, "_on_target_chosen"):
		return

	target_panel.visible = false
	submit_action(current_character, target, current_character.selected_action)


# --------------------------------------------------------------------
# ACTION EXECUTION (ASYNC)
# --------------------------------------------------------------------

func submit_action(caster: Fighter, target: Fighter, action: Action):
	execute_action_async(caster, target, action)


func execute_action_async(caster: Fighter, target: Fighter, action) -> void:
	if not _validate_state(BattleState.ACTION_SELECT, "execute_action_async"):
		return

	state = BattleState.ACTION_EXECUTE

	# Check if this is an enemy attacking a player - trigger dodge window
	if caster.faction == Faction.Type.ENEMY and target.faction == Faction.Type.PLAYER:
		_start_dodge_window(caster, target, action)
		return

	await action.execute(caster, target)

	caster.reset_atb()
	state = BattleState.CHECK
	evaluate_battle_state()

	if state != BattleState.END:
		state = BattleState.WAITING


func execute_roll_action(fighter: Fighter):
	if not _validate_state(BattleState.ACTION_SELECT, "execute_roll_action"):
		return

	var formation = hero_formation if fighter.faction == Faction.Type.PLAYER else enemy_formation
	var position_mapping = hero_position_mapping if fighter.faction == Faction.Type.PLAYER else enemy_position_mapping

	if not formation.can_roll():
		print("Cannot roll with only 1 alive fighter")
		state = BattleState.WAITING
		return

	state = BattleState.ACTION_EXECUTE
	
	var is_dodging = false
	if dodge_window_active and fighter.faction == Faction.Type.PLAYER:
		is_dodging = true

	# Perform the roll
	formation.roll_clockwise()
	
	# Update 3D visual positions
	formation.update_visual_positions(position_mapping)
	
	if debug_formation_enabled and OS.is_debug_build():
		print("Formation rolled! Revolt count: %d" % formation.revolt_count)
		formation.print_formation_state()

	if is_dodging:
		fighter.reset_atb()
		_cancel_pending_attack_with_dodge()
		return

	await get_tree().create_timer(ACTION_ANIMATION_TIME).timeout

	fighter.reset_atb()
	state = BattleState.CHECK
	evaluate_battle_state()

	if state != BattleState.END:
		state = BattleState.WAITING


# --------------------------------------------------------------------
# DODGE MANAGEMENT
# --------------------------------------------------------------------

func _start_dodge_window(caster: Fighter, target: Fighter, action: Action):
	print("=== DODGE WINDOW OPENED ===")
	print("%s is attacking %s - ROLL to dodge!" % [caster.character_name, target.character_name])

	dodge_window_active = true
	dodge_window_timer = DODGE_WINDOW_DURATION
	pending_attack_caster = caster
	pending_attack_target = target
	pending_attack_action = action

	# Show visual indicators
	if target.visuals:
		target.visuals.show_dodge_indicator()
	if caster.visuals:
		caster.visuals.show_attack_windup(target.visuals)

	set_time_paused(false)
	state = BattleState.WAITING

	# Restore interrupted player
	if player_was_selecting and interrupted_player and interrupted_player.is_alive():
		print("🔄 [RESTORE] Returning to player: %s" % interrupted_player.character_name)
		current_character = interrupted_player
		state = BattleState.ACTION_SELECT
		player_was_selecting = false
		interrupted_player = null


func _execute_pending_attack():
	print("=== Dodge window expired - attack hits! ===")

	dodge_window_active = false
	
	# Clear visual indicators
	if pending_attack_target and pending_attack_target.visuals:
		pending_attack_target.visuals.hide_dodge_indicator()
	if pending_attack_caster and pending_attack_caster.visuals:
		pending_attack_caster.visuals.clear_attack_indicator()

	state = BattleState.ACTION_EXECUTE
	await pending_attack_action.execute(pending_attack_caster, pending_attack_target)

	pending_attack_caster.reset_atb()
	_clear_pending_attack()

	state = BattleState.CHECK
	evaluate_battle_state()

	if state != BattleState.END:
		state = BattleState.WAITING


func _cancel_pending_attack_with_dodge():
	print("=== DODGED! Attack missed! ===")

	dodge_window_active = false
	
	# Clear visual indicators
	if pending_attack_target and pending_attack_target.visuals:
		pending_attack_target.visuals.hide_dodge_indicator()
	if pending_attack_caster and pending_attack_caster.visuals:
		pending_attack_caster.visuals.clear_attack_indicator()

	print("%s's attack was dodged!" % pending_attack_caster.character_name)

	pending_attack_caster.reset_atb()
	_clear_pending_attack()

	state = BattleState.CHECK
	evaluate_battle_state()

	if state != BattleState.END:
		state = BattleState.WAITING


func _clear_pending_attack():
	"""Helper to clear pending attack data"""
	pending_attack_caster = null
	pending_attack_target = null
	pending_attack_action = null


# --------------------------------------------------------------------
# RELATIONSHIPS & TARGETING
# --------------------------------------------------------------------

func get_hostile_targets(source: Fighter) -> Array[Fighter]:
	var result: Array[Fighter] = []
	for f in fighters:
		if f.is_alive() and is_hostile(source, f):
			result.append(f)
	return result


func is_hostile(a: Fighter, b: Fighter) -> bool:
	return a.faction != b.faction


# --------------------------------------------------------------------
# DEATH & VICTORY
# --------------------------------------------------------------------

func _on_fighter_died(fighter: Fighter):
	print("💀 [DEATH] %s has died" % fighter.character_name)
	
	# Record defeated enemies for rewards
	if fighter.faction == Faction.Type.ENEMY and fighter.original_data:
		if not defeated_enemies_data.has(fighter.original_data):
			defeated_enemies_data.append(fighter.original_data)
	
	# Remove from formation
	var formation = hero_formation if fighter.faction == Faction.Type.PLAYER else enemy_formation
	formation.remove_fighter(fighter)
	
	# Remove from ready queue if present
	if ready_queue.has(fighter):
		ready_queue.erase(fighter)
		print("🗑️ [QUEUE] Removed dead fighter from queue: %s" % fighter.character_name)
	
	# If this was the current character, reset
	if current_character == fighter:
		current_character = null
		state = BattleState.WAITING
	
	if debug_formation_enabled and OS.is_debug_build():
		formation.print_formation_state()


func evaluate_battle_state():
	var result = victory_condition.evaluate(fighters)

	match result:
		VictoryCondition.Result.ONGOING:
			pass
		VictoryCondition.Result.VICTORY:
			end_battle(true)
		VictoryCondition.Result.DEFEAT:
			end_battle(false)


func end_battle(victory: bool):
	state = BattleState.END
	set_time_paused(true)

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

func _print_queue_snapshot():
	if not debug_queue_enabled or not OS.is_debug_build():
		return

	print("\n╔════════════════════════════════════════")
	print("║          READY QUEUE STATUS            ")
	print("╠════════════════════════════════════════")
	print("║ Current State: %-23s" % BattleState.keys()[state])
	print("║ Active Fighter: %-22s" % (current_character.character_name if current_character else "None"))
	print("║ Queue Size: %-27d" % ready_queue.size())
	print("╠════════════════════════════════════════")

	if ready_queue.size() == 0:
		print("║ Queue is EMPTY                         ")
	else:
		for i in range(ready_queue.size()):
			var f = ready_queue[i]
			var type_str = "PLAYER" if f.controller is PlayerController else "AI    "
			var alive_str = "✓" if f.is_alive() else "✗"
			print("║ Pos %d: %-15s [%s] %s ATB:%-3d" % [
				i + 1,
				f.character_name,
				type_str,
				alive_str,
				int(f.atb)
			])

	print("╚════════════════════════════════════════\n")

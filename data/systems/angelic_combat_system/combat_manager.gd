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
const DODGE_WINDOW_DURATION = 10.0  # Time window to dodge (adjust as needed)

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

# Victory evaluation (can be swapped later)
var victory_condition: VictoryCondition = DefaultVictoryCondition.new()

# UI
@export var action_panel: Control
@export var target_panel: Control
@export var defeat_panel: Control
@export var victory_panel: Control
@export var heroes_ui_container: VBoxContainer
@export var enemies_ui_container: VBoxContainer
@export var character_ui_prefab: PackedScene

# FORMATION
var hero_formation: Formation = Formation.new()
var enemy_formation: Formation = Formation.new()

# DODGE WINDOW
var dodge_window_active: bool = false
var dodge_window_timer: float = 0.0
var pending_attack_caster: Fighter = null
var pending_attack_target: Fighter = null
var pending_attack_action: Action = null

# DEBUG
var debug_queue_enabled: bool = true
var debug_dodge_window_timer_enabled: bool = false
var debug_formation_enabled: bool = false

# WIPWIPWIPWIWPWIPIWPIWPIW
var interrupted_player: Fighter = null
var player_was_selecting: bool = false

# --------------------------------------------------------------------
# INITIALIZATION
# --------------------------------------------------------------------

func _ready():
	var heroes_pool = GameManager.combat_heroes_pool
	var enemies_pool = GameManager.combat_enemies_pool
	var atb_advantage = GameManager.combat_atb_advantage

	assert(heroes_pool != null)
	assert(enemies_pool != null)

	start_battle(heroes_pool, enemies_pool, atb_advantage)


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

	if debug_formation_enabled:
		print("\nHero Formation:")
		print(hero_formation.get_formation_visual_string())
		print("\nEnemy Formation:")
		print(enemy_formation.get_formation_visual_string())

	for fighter in fighters:
		fighter.ready_to_act.connect(_on_fighter_ready)
		fighter.died.connect(_on_fighter_died)

	state = BattleState.WAITING


func _spawn_fighter(data: FighterData, faction: Faction.Type, ui_container: VBoxContainer, atb_advantage: bool) -> void:
	
	var fighter: Fighter = data.instantiate()
	add_child(fighter)

	fighter.faction = faction
	
	if faction == Faction.Type.PLAYER:
		fighter.controller = PlayerController.new()
	else:
		fighter.controller = AIController.new()

	# Assign to formation's positions
	var formation

	if faction == Faction.Type.PLAYER:
		formation = hero_formation 
	else: 
		formation = enemy_formation

	var pos_index = formation.get_fighters().size()  # 0, 1, 2, 3...
	var positions = [Formation.Position.UP, Formation.Position.RIGHT, Formation.Position.DOWN, Formation.Position.LEFT]

	if pos_index < positions.size():
		formation.assign_fighter(fighter, positions[pos_index])

	if atb_advantage:
		fighter.atb = 50.0

	if character_ui_prefab:
		var ui = character_ui_prefab.instantiate()
		ui_container.add_child(ui)
		ui.fighter = fighter

	fighters.append(fighter)


# --------------------------------------------------------------------
# PROCESS LOOP
# --------------------------------------------------------------------

func _process(delta):
# Handle dodge window countdown
	if dodge_window_active:
		dodge_window_timer -= delta

		# Debug output every 0.5 seconds
		if debug_dodge_window_timer_enabled:
			if int(dodge_window_timer * 2) != int((dodge_window_timer + delta) * 2):
				print("Dodge window: %.1fs remaining" % dodge_window_timer)

		if dodge_window_timer <= 0.0:
			# Window expired - execute the attack
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
		push_error("Invalid state in %s: expected %s, got %s" % [context, BattleState.keys()[expected], BattleState.keys()[state]])
		return false
	return true

# --------------------------------------------------------------------
# TURN FLOW
# --------------------------------------------------------------------

func _on_fighter_ready(fighter: Fighter):
	if not fighter.is_alive():
		return

	# If it's an AI fighter, process immediately (bypass queue)
	if fighter.controller is AIController:
		if not ready_queue.has(fighter):
			ready_queue.append(fighter)
			print("➕ [QUEUE] AI added: %s" % fighter.character_name)
			_print_queue_snapshot()
		
		# If we're in WAITING state, process normally through queue
		if state == BattleState.WAITING:
			return
		
		# Otherwise, interrupt and process AI turn immediately
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

	current_character = ready_queue.pop_front()
	print("⚡ [QUEUE] Processing: %s" % current_character.character_name)
	_print_queue_snapshot()  # ← ADD THIS

	if not current_character.is_alive():
		current_character.reset_atb()
		return

	begin_turn(current_character)

func _process_ai_turn_immediate(fighter: Fighter):
	print("⚠️  [QUEUE] AI INTERRUPT: %s" % fighter.character_name)
	_print_queue_snapshot()  # ← ADD THIS

	if current_character and current_character.controller is PlayerController and state == BattleState.ACTION_SELECT:
		interrupted_player = current_character
		player_was_selecting = true
		print("💾 [INTERRUPT] Saving player context: %s" % interrupted_player.character_name)

	# Store current state to restore later if needed
	var previous_state = state
	var previous_character = current_character

	# Temporarily set this as current character
	current_character = fighter

	# Let AI choose action and target
	var action: Action = fighter.controller.choose_action(fighter)
	var target: Fighter = fighter.controller.choose_target(fighter, self)

	if action == null or target == null:
		print("AI skipped turn:", fighter.character_name)
		fighter.reset_atb()
		current_character = previous_character
		return

	# AI attacks directly - this will trigger dodge window
	state = BattleState.ACTION_SELECT  # Set proper state for execute_action_async
	submit_action(fighter, target, action)

	# After attack completes, state will be reset by execute_action_async
	# Don't restore previous_character - let the system continue naturally


func begin_turn(fighter: Fighter):
	if not _validate_state(BattleState.WAITING, "begin_turn"):
		return

	state = BattleState.ACTION_SELECT
	print("🎮 [TURN START] %s begins turn" % fighter.character_name)
	_print_queue_snapshot()  # ← ADD THIS

	fighter.controller.take_turn(fighter, self)


# --------------------------------------------------------------------
# PLAYER FLOW
# --------------------------------------------------------------------

func show_action_menu(fighter: Fighter):
	if not _validate_state(BattleState.ACTION_SELECT, "show_action_menu"):
		return

	# set_time_paused(true)
	action_panel.show_actions(fighter)
	action_panel.action_chosen.connect(_on_action_chosen, CONNECT_ONE_SHOT)


func _on_action_chosen(action):
	if not _validate_state(BattleState.ACTION_SELECT, "_on_action_chosen"):
		return

	if action == null:
		push_error("Null action chosen")
		state = BattleState.WAITING
		time_paused = false
		return

	action_panel.visible = false

	if action is RollAction:
		# Roll doesn't need target selection
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
	# set_time_paused(false)

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

	# Check if this is an enemy attacking a player
	if caster.faction == Faction.Type.ENEMY and target.faction == Faction.Type.PLAYER:
		# Start dodge window instead of executing immediately
		_start_dodge_window(caster, target, action)
		return  # Don't execute yet - wait for dodge or timeout

	# Always await the execution
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

	if not formation.can_roll():
		print("Cannot roll with only 1 fighter")
		state = BattleState.WAITING  # Reset state
		return

	state = BattleState.ACTION_EXECUTE
	
	# Check if this roll is during a dodge window
	var is_dodging = false
	if dodge_window_active and fighter.faction == Faction.Type.PLAYER:
		is_dodging = true

	# Perform the roll animation/logic
	formation.roll_clockwise()
	print("Formation rolled! Revolt count: %d" % formation.revolt_count)
	print("\nHero Formation:")
	if debug_formation_enabled:
		print(hero_formation.get_formation_visual_string())

	# If dodging, cancel the pending attack
	if is_dodging:
		fighter.reset_atb()
		_cancel_pending_attack_with_dodge()
		return  # Early exit - dodge handling is done

	# Small delay for animation
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

	# DON'T pause time - players need ATB to charge for roll
	set_time_paused(false)

	# Optional: Show visual indicator to player
	# e.g., flash the target's UI, show "DODGE!" text, etc.

	state = BattleState.WAITING  # ← ADD THIS LINE

	# If we interrupted a player, restore their turn
	if player_was_selecting and interrupted_player and interrupted_player.is_alive():
		print("🔄 [RESTORE] Returning to player: %s" % interrupted_player.character_name)
		current_character = interrupted_player
		state = BattleState.ACTION_SELECT
		# The action panel should still be visible for them
		player_was_selecting = false
		interrupted_player = null


func _execute_pending_attack():
	print("=== Dodge window expired - attack hits! ===")

	dodge_window_active = false

	# Store current state
	var previous_state = state
	
	# Temporarily set to EXECUTE for the attack
	state = BattleState.ACTION_EXECUTE

	# Execute the attack
	await pending_attack_action.execute(pending_attack_caster, pending_attack_target)

	pending_attack_caster.reset_atb()

	# Clear pending data
	pending_attack_caster = null
	pending_attack_target = null
	pending_attack_action = null

	state = BattleState.CHECK
	evaluate_battle_state()

	if state != BattleState.END:
		state = BattleState.WAITING


func _cancel_pending_attack_with_dodge():
	print("=== DODGED! Attack missed! ===")

	dodge_window_active = false

	# Attack is cancelled - no damage dealt
	print("%s's attack was dodged!" % pending_attack_caster.character_name)

	pending_attack_caster.reset_atb()

	# Clear pending data
	pending_attack_caster = null
	pending_attack_target = null
	pending_attack_action = null

	state = BattleState.CHECK
	evaluate_battle_state()

	if state != BattleState.END:
		state = BattleState.WAITING

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
	if fighter.faction == Faction.Type.ENEMY and fighter.original_data:
		if not defeated_enemies_data.has(fighter.original_data):
			defeated_enemies_data.append(fighter.original_data)


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


func _print_queue_snapshot():
	if not debug_queue_enabled:
		return

	print("\n╔════════════════════════════════════════")
	print("║          READY QUEUE STATUS")
	print("╠════════════════════════════════════════")
	print("║ Current State: %-23s" % BattleState.keys()[state])
	print("║ Active Fighter: %-22s" % (current_character.character_name if current_character else "None"))
	print("║ Queue Size: %-27d" % ready_queue.size())
	print("╠════════════════════════════════════════")

	if ready_queue.size() == 0:
		print("║ Queue is EMPTY")
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

extends Node

enum BattleState {
	START,
	WAITING,
	ACTION_SELECT,
	ACTION_EXECUTE,
	CHECK,
	END
}

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

func _process(_delta):
	for fighter in fighters:
		fighter.pause_atb(time_paused)

	if state == BattleState.WAITING and not ready_queue.is_empty():
		process_next_ready_fighter()


# --------------------------------------------------------------------
# TURN FLOW
# --------------------------------------------------------------------

func _on_fighter_ready(fighter: Fighter):
	assert(state == BattleState.WAITING)
	if fighter.is_alive() and not ready_queue.has(fighter):
		ready_queue.append(fighter)


func process_next_ready_fighter():
	assert(state == BattleState.WAITING)

	current_character = ready_queue.pop_front()

	if not current_character.is_alive():
		current_character.reset_atb()
		return

	begin_turn(current_character)


func begin_turn(fighter: Fighter):
	assert(state == BattleState.WAITING)

	state = BattleState.ACTION_SELECT
	print("Turn:", fighter.character_name)

	fighter.controller.take_turn(fighter, self)


# --------------------------------------------------------------------
# PLAYER FLOW
# --------------------------------------------------------------------

func show_action_menu(fighter: Fighter):
	assert(state == BattleState.ACTION_SELECT)

	time_paused = true
	action_panel.show_actions(fighter)
	action_panel.action_chosen.connect(_on_action_chosen, CONNECT_ONE_SHOT)


func _on_action_chosen(action):
	assert(state == BattleState.ACTION_SELECT)

	action_panel.visible = false
	current_character.selected_action = action

	var targets = get_hostile_targets(current_character)
	target_panel.show_targets(targets)
	target_panel.target_chosen.connect(_on_target_chosen, CONNECT_ONE_SHOT)


func _on_target_chosen(target: Fighter):
	assert(state == BattleState.ACTION_SELECT)

	target_panel.visible = false
	time_paused = false

	execute_action_async(
		current_character,
		target,
		current_character.selected_action
	)


# --------------------------------------------------------------------
# ACTION EXECUTION (ASYNC)
# --------------------------------------------------------------------

func execute_action_async(
	caster: Fighter,
	target: Fighter,
	action
) -> void:
	assert(state == BattleState.ACTION_SELECT)

	state = BattleState.ACTION_EXECUTE

	action.execute(caster, target)

	# ---- THIS IS THE IMPORTANT PART YOU NOTICED ----
	if action.has_signal("completed"):
		await action.completed

	caster.reset_atb()

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
	time_paused = true

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

extends Node
enum BattleState { START, WAITING, ACTION_SELECT, ACTION_EXECUTE, CHECK, END }

var fighters: Array[Fighter] = []  # Tous les personnages (alliés + ennemis)
var ready_queue: Array[Fighter] = [] # Personnages avec ATB pleine, prêts à agir
var state = BattleState.START
var current_character: Fighter = null
# TODO sûrement désactiver ça si on veut un combat bcp plus dynamique et pouvoir  esquiver les attaques
var time_paused: bool = false # Pour pause ATB pendant sélection d'actions de chaque perso.

# TODO FORMATION SYSTEM 
#var hero_formation: Formation
#var enemy_formation: Formation
#
# TODO TEAM RESOURCES 
#var hero_resources: TeamResources
#var enemy_resources: TeamResources

# REWARDS - Only enemies actually defeated
var defeated_enemies_data: Array[FighterData] = []

#UI References
@export var action_panel : Control
@export var target_panel : Control
@export var defeat_panel : Control
@export var victory_panel : Control
@export var heroes_ui_container : VBoxContainer
@export var enemies_ui_container : VBoxContainer
@export var character_ui_prefab : PackedScene

func _ready():
	# Get combat data from GameManager
	var heroes_pool = GameManager.combat_heroes_pool
	var enemies_pool = GameManager.combat_enemies_pool
	var atb_advantage = GameManager.combat_atb_advantage
	
	if enemies_pool == null and heroes_pool == null: 
		print("Combat couldn't start, no heroes and no enemies")
		return
	elif enemies_pool == null:
		print("Combat couldn't start, no enemies")
		return
	elif heroes_pool == null:
		print("Combat couldn't start, no heroes")
		return
		
	if heroes_ui_container == null or enemies_ui_container == null:
		print("UI is missing")
		return
	
	start_battle(heroes_pool, enemies_pool, atb_advantage)

func start_battle(heroes_pool: FighterPool, enemies_pool: FighterPool, atb_advantage: bool):
	print("=== Combat Start (ATB System) ===")
	print("Player ATB Advantage: ", atb_advantage)

	var heroes_data = heroes_pool.fighters
	var enemies_data = enemies_pool.fighters

	# Clear defeated list (only fill when enemies actually die)
	defeated_enemies_data.clear()
	
	# Create heroes (merged instantiation + UI)
	var heroes: Array[Fighter] = []
	for data in heroes_data:
		var hero = instantiate_fighter_with_ui(
			data,
			heroes_ui_container,
			atb_advantage
		)
		if hero:
			heroes.append(hero)
	
	# Create enemies (merged instantiation + UI)
	var enemies: Array[Fighter] = []
	for data in enemies_data:
		var enemy = instantiate_fighter_with_ui(
			data,
			enemies_ui_container,
			false  # Enemies don't get advantage
		)
		if enemy:
			enemies.append(enemy)
	
	# Connect fighter signals
	for fighter in fighters:
		fighter.ready_to_act.connect(_on_fighter_ready)
		
		# Connect death signal for reward tracking
		if fighter.is_enemy:
			fighter.tree_exiting.connect(_on_enemy_died.bind(fighter))
		
		print("Fighter: %s | HP=%d | Enemy=%s" % [
			fighter.character_name,
			fighter.hp,
			fighter.is_enemy
		])
		
	state = BattleState.WAITING
	print("\n=== ATB bars charging... ===")

func instantiate_fighter_with_ui(data: FighterData, ui_container: VBoxContainer, atb_advantage: bool) -> Fighter:
	"""
	Create fighter instance AND its UI in one function
	Returns the fighter instance
	"""
	# 1. Instantiate fighter
	var fighter = data.instantiate()
	if fighter == null:
		push_error("Failed to instantiate fighter: %s" % data.character_name)
		return null
	
	add_child(fighter)
	
	# 2. TODO Add standard actions
	#ensure_has_basic_actions(fighter, not data.is_enemy)
	
	# 3. Apply ATB advantage if applicable
	if atb_advantage:
		fighter.atb = 50.0
	
	# 4. Create UI immediately
	if character_ui_prefab:
		var ui = character_ui_prefab.instantiate()
		ui_container.add_child(ui)
		ui.fighter = fighter
	else:
		push_warning("No character_ui_prefab set!")
	
	# 5. Add to fighters list
	fighters.append(fighter)
	
	return fighter

func _on_enemy_died(enemy: Fighter):
	"""
	Called when an enemy dies (tree_exiting signal)
	Only adds to defeated list if enemy actually died in combat
	"""
	if not enemy.is_alive() and enemy.original_data:
		# Check if not already in list
		if not defeated_enemies_data.has(enemy.original_data):
			defeated_enemies_data.append(enemy.original_data)
			print("💀 Enemy defeated: %s (Rewards will be granted)" % enemy.character_name)

func _process(_delta):
	# Pause ATB pendant la sélection d'action
	if time_paused:
		for fighter in fighters:
			fighter.set_process(false)
	else:
		for fighter in fighters:
			fighter.set_process(true)
	
	# Traiter la queue des personnages prêts
	if state == BattleState.WAITING and ready_queue.size() > 0:
		process_next_ready_fighter()

func _on_fighter_ready(fighter):
	if not fighter.is_alive():
		return
	
	# Ajouter à la queue des prêts s'il n'y est pas déjà
	if not ready_queue.has(fighter):
		ready_queue.append(fighter)
		print("\n>>> %s is ready to act! (ATB: 100)" % fighter.character_name)

func process_next_ready_fighter():
	if ready_queue.size() == 0:
		return
	
	current_character = ready_queue.pop_front()
	
	if not current_character.is_alive():
		current_character.reset_atb()
		process_next_ready_fighter()
		return
	
	state = BattleState.ACTION_SELECT
	print("\n=== %s's turn! ===" % current_character.character_name)
	
	if current_character.is_enemy:
		# IA simple = attaque un héros vivant
		var target = get_first_hero_alive()
		if target != null:
			var action = current_character.actions[0]
			execute_action(current_character, target, action)
		else:
			print("Plus aucun héros à attaquer !")
			end_battle(false)
	else:
		# Joueur → pause ATB et affiche menu
		time_paused = true
		show_action_menu(current_character)

func show_action_menu(fighter: Fighter):
	"""Show action selection menu"""
	if action_panel:
		action_panel.show_actions(fighter)
		action_panel.action_chosen.connect(_on_action_chosen, CONNECT_ONE_SHOT)

func _on_action_chosen(action):
	action_panel.visible = false
	current_character.selected_action = action
	
	# Afficher la liste des cibles
	var enemies = fighters.filter(func(c): return c.is_enemy and c.is_alive())
	target_panel.show_targets(enemies)
	target_panel.target_chosen.connect(_on_target_chosen, CONNECT_ONE_SHOT)

func _on_target_chosen(target):
	target_panel.visible = false
	time_paused = false  # Reprendre l'ATB
	execute_action(current_character, target, current_character.selected_action)

func get_first_hero_alive():
	for c in fighters:
		if not c.is_enemy and c.is_alive():
			return c
	return null
	
func get_first_enemy_alive():
	for c in fighters:
		if c.is_enemy and c.is_alive():
			return c
	return null

func execute_action(caster, target, action):
	state = BattleState.ACTION_EXECUTE
	action.execute(caster, target)
	
	# Réinitialiser l'ATB du personnage qui vient d'agir
	caster.reset_atb()
	print(">>> %s's ATB reset to 0" % caster.character_name)
	
	# Vérifier victoire/défaite
	check_victory()
	
	# Retour en attente
	if state != BattleState.END:
		state = BattleState.WAITING

func check_victory():
	var heroes_alive = fighters.any(func(c): return not c.is_enemy and c.is_alive())
	var enemies_alive = fighters.any(func(c): return c.is_enemy and c.is_alive())

	if not heroes_alive:
		end_battle(false)
	elif not enemies_alive:
		end_battle(true)

func end_battle(victory: bool):
	state = BattleState.END
	time_paused = true
	
	for fighter in fighters:
		fighter.set_process(false)
	
	if victory:
		print("\n*** VICTORY! ***")
		print("Defeated enemies: %d" % defeated_enemies_data.size())
		for enemy_data in defeated_enemies_data:
			print("  - %s" % enemy_data.character_name)
		
		if victory_panel:
			victory_panel.visible = true
			victory_panel.continue_pressed.connect(_on_victory_continue)
	else:
		print("\n--- DEFEAT ---")
		if defeat_panel:
			defeat_panel.visible = true
			defeat_panel.retry_pressed.connect(_on_defeat_retry)

func _on_victory_continue():
	# Calculate and pass defeated enemies data to GameManager for rewards
	GameManager.end_combat(true, defeated_enemies_data)

func _on_defeat_retry():
	# TODO Handle defeat - could restart battle or return to checkpoint
	GameManager.end_combat(false, [])

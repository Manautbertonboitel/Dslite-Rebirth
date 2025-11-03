extends Node
enum BattleState { START, WAITING, ACTION_SELECT, ACTION_EXECUTE, CHECK, END }

var fighters = []          # Tous les personnages (alliés + ennemis)
var ready_queue = []       # Personnages avec ATB pleine, prêts à agir
var state = BattleState.START
var current_character = null
var time_paused = false    # Pour pause ATB pendant sélection

@export var heroes_pool : FighterPool
@export var enemies_pool : FighterPool
@export var action_panel : Control
@export var target_panel : Control
@export var heroes_ui_container : VBoxContainer
@export var enemies_ui_container : VBoxContainer
@export var character_ui_prefab : PackedScene

func _ready():
	start_battle(heroes_pool, enemies_pool)

func start_battle(_heroes_pool: FighterPool, _enemies_pool: FighterPool):
	print("=== Combat Start (ATB System) ===")
	
	if _enemies_pool == null and _heroes_pool == null: 
		print("Combat couldn't start, no heroes and no enemies")
		return
	elif _enemies_pool == null:
		print("Combat couldn't start, no enemies")
		return
	elif _heroes_pool == null:
		print("Combat couldn't start, no heroes")
		return

	# Récupérer les arrays de fighters
	var heroes_data = _heroes_pool.fighters
	var enemies_data = _enemies_pool.fighters

	# Instancier chaque fighter
	var heroes = []
	for data in heroes_data:
		var hero = data.instantiate()
		heroes.append(hero)
		add_child(hero)  # Ajouter au scene tree pour _process
		
	var enemies = []
	for data in enemies_data:
		var enemy = data.instantiate()
		enemies.append(enemy)
		add_child(enemy)  # Ajouter au scene tree pour _process
	
	fighters = heroes + enemies
	

	if heroes_ui_container == null or enemies_ui_container == null:
		return 
		
	# Créer l'UI pour chaque héros
	for hero in heroes:
		var hero_ui = character_ui_prefab.instantiate()
		heroes_ui_container.add_child(hero_ui)
		hero_ui.fighter = hero
	
	# Créer l'UI pour chaque ennemi
	for enemy in enemies:
		var enemy_ui = character_ui_prefab.instantiate()
		enemies_ui_container.add_child(enemy_ui)
		enemy_ui.fighter = enemy
	
	# Connecter le signal ready_to_act de chaque fighter
	for fighter in fighters:
		fighter.ready_to_act.connect(_on_fighter_ready)
		print("Loaded fighter: ", fighter.character_name, " | HP=", fighter.hp, " | Speed=", fighter.atb_speed, " | enemy=", fighter.is_enemy)
		
	
	state = BattleState.WAITING
	print("\n=== ATB bars charging... ===")

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
			end_battle()
	else:
		# Joueur → pause ATB et affiche menu
		time_paused = true
		action_panel.show_actions(current_character)
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
		end_battle()
		print("\n--- DEFEAT... ---")
	elif not enemies_alive:
		end_battle()
		print("\n*** VICTORY! ***")

func end_battle():
	state = BattleState.END
	time_paused = true
	# Arrêter tous les fighters
	for fighter in fighters:
		fighter.set_process(false)

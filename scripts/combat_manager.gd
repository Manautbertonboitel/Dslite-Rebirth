extends Node
enum BattleState { START, TURN, ACTION, CHECK, END }

var fighters = []          # Tous les personnages (alliés + ennemis)
var turn_queue = []          # Ordre de tour (FIFO)
var state = BattleState.START
var current_character = null

@export var heroesPool : FighterPool
@export var enemiesPool : FighterPool

func _ready():
	start_battle(heroesPool, enemiesPool)

func start_battle(heroes_pool: FighterPool, enemies_pool: FighterPool):
	print("=== Combat Start ===")
	
	if enemies_pool == null and heroes_pool == null: 
		print("Combat couldn't start, no heroes and no enemies")
		return
	elif enemies_pool == null:
		print("Combat couldn't start, no enemies")
		return
	elif heroes_pool == null:
		print("Combat couldn't start, no heroes")
		return

	# Récupérer les arrays de fighters
	var heroes_data = heroes_pool.fighters
	var enemies_data = enemies_pool.fighters

	# Instancier chaque fighter si ce sont des scènes
	var heroes = []
	for data in heroes_data:
		print("heroes data is PackedScene")
		heroes.append(data.instantiate())
		
	var enemies = []
	for data in enemies_data:
		print("Enemy data is PackedScene")
		enemies.append(data.instantiate())
	
	fighters = heroes + enemies
	fighters.shuffle()
	
	turn_queue = fighters.duplicate()  # Au début, on met tout le monde dans la queue

	state = BattleState.TURN
	
	for character in turn_queue:
		print("Loaded fighter: ", character.characterName, " | HP=", character.hp, " | enemy=", character.is_enemy)
	
	next_turn()

func next_turn():
	if state == BattleState.END:
		return

	if turn_queue.size() == 0:
		turn_queue = fighters.filter(func(c): return c.is_alive())
		# Tous ont joué → recommencer un round
	
	if turn_queue.size() == 0:
		# Tous morts (match nul ?)
		state = BattleState.END
		print("Combat ended, nobody alive...")
		return

	current_character = turn_queue.pop_front()

	if not current_character.is_alive():
		next_turn()
		return

	print("\nC'est au tour de %s !" % current_character.characterName)

	if current_character.is_enemy:
		# IA simple = attaque un héros vivant
		
		#var target = fighters[0]  # on attaque toujours le premier héros
		var target = get_first_hero_alive()
		if target != null:
			var action = current_character.actions[0]
			execute_action(current_character, target, action)
		else:
			print("Plus aucun héros à attaquer !")
	else:
		# Joueur → pour test on attaque toujours l'ennemi
		var target = get_first_enemy_alive()
		if target != null:
			var action = current_character.actions[0]
			execute_action(current_character, target, action)
		else:
			print("Plus aucun ennemi à attaquer !")

func get_first_hero_alive():
	for c in fighters:
		if not c.is_enemy and c.is_alive():
			return c
	return null  # si aucun héros vivant
	
func get_first_enemy_alive():
	for c in fighters:
		if c.is_enemy and c.is_alive():
			return c
	return null  # si aucun ennemi vivant

func execute_action(caster, target, action):
	state = BattleState.ACTION
	action.execute(caster, target)

	# Vérifier victoire/défaite
	check_victory()

	# Si le combat n'est pas fini, remettre caster en fin de queue
	if state != BattleState.END:
		turn_queue.append(caster)
		state = BattleState.TURN
		next_turn()

func check_victory():
	var heroes_alive = fighters.any(func(c): return not c.is_enemy and c.is_alive())
	var enemies_alive = fighters.any(func(c): return c.is_enemy and c.is_alive())

	if not heroes_alive:
		state = BattleState.END
		print("\n--- Défaite... ---")
	elif not enemies_alive:
		state = BattleState.END
		print("\n*** Victoire ! ***")

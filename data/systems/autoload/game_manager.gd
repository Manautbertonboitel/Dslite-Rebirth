extends Node

# === PLAYER PARTY DATA ===
var player_party: Array[PartyMember] = []  # Array of PartyMember resources
var player_inventory: Array[ItemData] = []  # Items collected
var player_gold: int = 0

# === COMBAT TRANSITION DATA ===
var combat_heroes_pool: FighterPool = null
var combat_enemies_pool: FighterPool = null
var combat_atb_advantage: bool = false  # True if player attacked first
var return_scene_path: String = ""
var return_position: Vector3 = Vector3.ZERO
var return_rotation: Vector3 = Vector3.ZERO
const RETURN_TO_WORLD_ANIMATION_TIME = 0.5

# === LOOT TABLES ===
var loot_tables: Dictionary = {}  # Key: table_name, Value: LootTable resource

# === TRIGGER MANAGEMENT ===
var defeated_triggers: Dictionary = {}  # Key: trigger_id, Value: timestamp

func _ready():
	
	# Load loot tables (you'll create these as resources)
	load_loot_tables()
	
	# Initialize default party if empty (for testing)
	if player_party.is_empty():
		initialize_default_party()

func initialize_default_party():
	player_party.clear()

	var lapine_data: FighterData = load(
		"res://data/characters/lapine/DT_Lapine.tres"
	)
	var lapine_2_data: FighterData = load(
		"res://data/characters/lapine_2/DT_Lapine_2.tres"
	)

	var member_1 := PartyMember.new()
	member_1.base_data = lapine_data

	var member_2 := PartyMember.new()
	member_2.base_data = lapine_2_data

	player_party.append(member_1)
	player_party.append(member_2)

	print("Initialized default party with PartyMembers")

func load_loot_tables():
	# Load your loot table resources
	# Example: loot_tables["forest"] = load("res://data/loot/forest_loot.tres")
	pass

# === COMBAT INITIATION ===
func start_combat(enemies_pool: FighterPool, atb_advantage: bool = false):
	# Save current scene info
	var current_scene = get_tree().current_scene
	return_scene_path = current_scene.scene_file_path
	
	# Get player position from the world
	var player = get_tree().get_first_node_in_group("player")
	if player:
		return_position = player.global_position
		return_rotation = player.rotation
	
	# Setup combat data
	combat_enemies_pool = enemies_pool
	combat_atb_advantage = atb_advantage
	
	# Create heroes pool from party
	combat_heroes_pool = FighterPool.new()
	combat_heroes_pool.fighters.clear()

	for member in player_party:
		combat_heroes_pool.fighters.append(
			member.create_fighter_data()
		)
	
# --------------------------------------------------------------------
# TRANSITION
# --------------------------------------------------------------------
	# Use transition instead of direct scene change
	await TransitionManager.transition_to_combat()
	
	# Optional: Show enemy name
	if enemies_pool.fighters.size() > 0:
		#TODO actuellement on affiche que le name du premier enemy de la pool, faudrait les afficher tous (oupas mdr)
		var enemy_name = enemies_pool.fighters[0].character_name
		TransitionManager.show_encounter_text(enemy_name)

# === COMBAT END ===
func end_combat(victory: bool, defeated_enemies: Array):
	if victory:
		# Calculate rewards
		var xp_gained = calculate_xp(defeated_enemies)
		var gold_gained = calculate_gold(defeated_enemies)
		var items_looted = roll_loot(defeated_enemies)
		
		# Apply rewards
		award_xp(xp_gained)
		player_gold += gold_gained
		
		for item in items_looted:
			player_inventory.append(item)
		
		# Show results (you can add a results screen here)
		print("\n=== VICTORY REWARDS ===")
		print("XP Gained: ", xp_gained)
		print("Gold Gained: ", gold_gained)
		print("Items Looted: ", items_looted.size())
	else:
		print("\n=== DEFEAT ===")
		# Handle defeat (respawn, game over, etc.)
	
	# Return to world after a delay (or button press)
	await get_tree().create_timer(RETURN_TO_WORLD_ANIMATION_TIME).timeout
	return_to_world()

func calculate_xp(defeated_enemies: Array) -> int:
	var total_xp = 0
	for enemy_data in defeated_enemies:
		if enemy_data is FighterData:
			# Assuming FighterData has an xp_reward property
			total_xp += enemy_data.get("xp_reward")  # Default 50 if not set
	return total_xp

func calculate_gold(defeated_enemies: Array) -> int:
	var total_gold = 0
	for enemy_data in defeated_enemies:
		if enemy_data is FighterData:
			total_gold += enemy_data.get("gold_reward")
	return total_gold

func roll_loot(defeated_enemies: Array) -> Array[ItemData]:
	var looted_items: Array[ItemData] = []
	
	for enemy_data in defeated_enemies:
		if enemy_data is FighterData:
			var loot_table_name = enemy_data.get("loot_table")
			if loot_tables.has(loot_table_name):
				var table = loot_tables[loot_table_name]
				var item = table.roll_item()
				if item:
					looted_items.append(item)
	
	return looted_items

func award_xp(total_xp: int):
	for member in player_party:
		member.add_xp(total_xp)

func return_to_world():
	# Clear combat data
	combat_heroes_pool = null
	combat_enemies_pool = null
	combat_atb_advantage = false
	
	# Return to saved scene
	if return_scene_path != "":
		get_tree().change_scene_to_file(return_scene_path)
		# Position will be restored in the world scene's _ready()

# === TRIGGER MANAGEMENT - make sure the player doens't encounter the same triggers (e.g. enemy teams or closed already looted chests) ===
func register_defeated_trigger(trigger_id: String) -> void:
	defeated_triggers[trigger_id] = Time.get_unix_time_from_system()

func is_trigger_defeated(trigger_id: String) -> bool:
	return defeated_triggers.has(trigger_id)

func get_trigger_defeat_time(trigger_id: String) -> float:
	return defeated_triggers.get(trigger_id, 0.0)

func clear_defeated_trigger(trigger_id: String) -> void:
	defeated_triggers.erase(trigger_id)

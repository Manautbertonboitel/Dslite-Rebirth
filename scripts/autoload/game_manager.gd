extends Node
# AutoLoad: Project > Project Settings > AutoLoad > Add this script as "GameManager"

# === SAVING ===
const SAVE_PATH = "C/Users/Manaut/Desktop"
var auto_save_timer: Timer
var autosave: bool = true

# === PLAYER PARTY DATA ===
var player_party: Array[FighterData] = []  # Array of FighterData resources
var player_inventory: Array[ItemData] = []  # Items collected
var player_gold: int = 0

# === COMBAT TRANSITION DATA ===
var combat_heroes_pool: FighterPool = null
var combat_enemies_pool: FighterPool = null
var combat_atb_advantage: bool = false  # True if player attacked first
var return_scene_path: String = ""
var return_position: Vector3 = Vector3.ZERO
var return_rotation: Vector3 = Vector3.ZERO

# === LOOT TABLES ===
var loot_tables: Dictionary = {}  # Key: table_name, Value: LootTable resource

# === TRIGGER MANAGEMENT ===
var defeated_triggers: Dictionary = {}  # Key: trigger_id, Value: timestamp

func _ready():
	# Auto-save every 5 minutes
	if autosave:
		auto_save_timer = Timer.new()
		auto_save_timer.wait_time = 300.0
		if auto_save_timer.timeout.connect(save_game):
			print("game successfully saved")
		else:
			print("problem happened during autosave")
		add_child(auto_save_timer)
		auto_save_timer.start()
	else:
		print("autosave disabled")
	
	# Load loot tables (you'll create these as resources)
	load_loot_tables()
	
	# Initialize default party if empty (for testing)
	if player_party.is_empty():
		initialize_default_party()

func initialize_default_party():
	# Load your default heroes here
	# Example: player_party.append(load("res://data/heroes/hero1.tres"))
	player_party = [
		load("res://data/heroes/hero1.tres"),
		load("res://data/heroes/hero2.tres")
	]
	print("Warning: No party loaded, initialize your heroes!")

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
	combat_heroes_pool.fighters = player_party.duplicate()
	
	# Transition to combat scene
	# get_tree().change_scene_to_file("res://scenes/combat/combat_scene.tscn")
	
	# Use transition instead of direct scene change
	await TransitionManager.transition_to_combat({
		"enemy_team": enemies_pool,
		"atb_advantage": atb_advantage
	})
	
	# Optional: Show enemy name
	if enemies_pool.fighters.size() > 0:
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
	await get_tree().create_timer(2.0).timeout
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
	for hero_data in player_party:
		if hero_data is FighterData:
			var old_level = hero_data.get("level")
			hero_data.add_xp(total_xp)  # You'll implement this in FighterData
			var new_level = hero_data.get("level")
			
			if new_level > old_level:
				print("%s leveled up to %d!" % [hero_data.character_name, new_level])

func return_to_world():
	# Clear combat data
	combat_heroes_pool = null
	combat_enemies_pool = null
	combat_atb_advantage = false
	
	# Return to saved scene
	if return_scene_path != "":
		get_tree().change_scene_to_file(return_scene_path)
		# Position will be restored in the world scene's _ready()

func register_defeated_trigger(trigger_id: String) -> void:
	defeated_triggers[trigger_id] = Time.get_unix_time_from_system()

func is_trigger_defeated(trigger_id: String) -> bool:
	return defeated_triggers.has(trigger_id)

func get_trigger_defeat_time(trigger_id: String) -> float:
	return defeated_triggers.get(trigger_id, 0.0)

func clear_defeated_trigger(trigger_id: String) -> void:
	defeated_triggers.erase(trigger_id)

# === SAVE/LOAD ===
func save_game() -> bool:
	"""
	Save game data to file
	Returns true if successful
	"""
	var save_data = {
		"version": "1.0",  # For future compatibility
		"timestamp": Time.get_unix_time_from_system(),
		
		# Player data
		"gold": player_gold,
		"position": {
			"x": return_position.x,
			"y": return_position.y,
			"z": return_position.z
		},
		"rotation": {
			"x": return_rotation.x,
			"y": return_rotation.y,
			"z": return_rotation.z
		},
		"current_scene": return_scene_path,
		
		# Party data (heroes)
		"party": serialize_party(),
		
		# Inventory
		"inventory": serialize_inventory(),
		
		# World state
		"defeated_triggers": defeated_triggers,
		
		# Add more as needed:
		# "quest_flags": quest_flags,
		# "unlocked_areas": unlocked_areas,
	}
	
	# Convert to JSON
	var json_string = JSON.stringify(save_data, "\t")  # Pretty print with tabs
	
	# Write to file
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for writing: %s" % FileAccess.get_open_error())
		return false
	
	file.store_string(json_string)
	file.close()
	
	print("Game saved successfully to: %s" % SAVE_PATH)
	return true

func load_game() -> bool:
	"""
	Load game data from file
	Returns true if successful
	"""
	if not FileAccess.file_exists(SAVE_PATH):
		push_error("Save file not found: %s" % SAVE_PATH)
		return false
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open save file for reading: %s" % FileAccess.get_open_error())
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	# Parse JSON
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse save file JSON")
		return false
	
	var save_data = json.data
	
	# Validate version (for future compatibility)
	if not save_data.has("version"):
		push_error("Invalid save file format")
		return false
	
	# Load player data
	player_gold = save_data.get("gold", 0)
	
	if save_data.has("position"):
		var pos = save_data.position
		return_position = Vector3(pos.x, pos.y, pos.z)
	
	if save_data.has("rotation"):
		var rot = save_data.rotation
		return_rotation = Vector3(rot.x, rot.y, rot.z)
	
	return_scene_path = save_data.get("current_scene", "res://scenes/world/open_world.tscn")
	
	# Load party
	if save_data.has("party"):
		deserialize_party(save_data.party)
	
	# Load inventory
	if save_data.has("inventory"):
		deserialize_inventory(save_data.inventory)
	
	# Load world state
	defeated_triggers = save_data.get("defeated_triggers", {})
	
	print("Game loaded successfully!")
	return true

func serialize_party() -> Array:
	"""Convert party to saveable format"""
	var party_data = []
	
	for fighter_data in player_party:
		if fighter_data == null:
			continue
		
		# Save all relevant stats
		var fighter_dict = {
			"resource_path": fighter_data.resource_path,  # Path to .tres file
			"level": fighter_data.level,
			"current_xp": fighter_data.current_xp,
			"max_hp": fighter_data.max_hp,
			"base_attack": fighter_data.base_attack,
			"base_defense": fighter_data.base_defense,
			"atb_speed": fighter_data.atb_speed,
			# Add any custom modifications here
		}
		party_data.append(fighter_dict)
	
	return party_data

func deserialize_party(party_data: Array) -> void:
	"""Restore party from saved data"""
	player_party.clear()
	
	for fighter_dict in party_data:
		# Load the base resource
		var resource_path = fighter_dict.get("resource_path", "")
		if resource_path == "":
			continue
		
		var fighter_data = load(resource_path) as FighterData
		if fighter_data == null:
			push_error("Failed to load fighter resource: %s" % resource_path)
			continue
		
		# Create a working copy
		var fighter_copy = fighter_data.duplicate_fighter_data()
		
		# Restore saved stats
		fighter_copy.level = fighter_dict.get("level", 1)
		fighter_copy.current_xp = fighter_dict.get("current_xp", 0)
		fighter_copy.max_hp = fighter_dict.get("max_hp", 100)
		fighter_copy.base_attack = fighter_dict.get("base_attack", 10)
		fighter_copy.base_defense = fighter_dict.get("base_defense", 5)
		fighter_copy.atb_speed = fighter_dict.get("atb_speed", 1.0)
		
		player_party.append(fighter_copy)

func serialize_inventory() -> Array:
	"""Convert inventory to saveable format"""
	var inventory_data = []
	
	for item in player_inventory:
		if item == null:
			continue
		
		inventory_data.append({
			"resource_path": item.resource_path,
			# If you track quantities separately, add here:
			# "quantity": item_quantities[item],
		})
	
	return inventory_data

func deserialize_inventory(inventory_data: Array) -> void:
	"""Restore inventory from saved data"""
	player_inventory.clear()
	
	for item_dict in inventory_data:
		var resource_path = item_dict.get("resource_path", "")
		if resource_path == "":
			continue
		
		var item = load(resource_path) as ItemData
		if item:
			player_inventory.append(item)

# === UTILITY FUNCTIONS ===

func has_save_file() -> bool:
	"""Check if a save file exists"""
	return FileAccess.file_exists(SAVE_PATH)

func delete_save_file() -> bool:
	"""Delete the save file"""
	if FileAccess.file_exists(SAVE_PATH):
		var dir = DirAccess.open("user://")
		var err = dir.remove(SAVE_PATH)
		return err == OK
	return false

func get_save_timestamp() -> String:
	"""Get human-readable save time"""
	if not FileAccess.file_exists(SAVE_PATH):
		return "No save file"
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return "Error reading save"
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return "Corrupted save"
	
	var save_data = json.data
	var timestamp = save_data.get("timestamp", 0)
	
	var datetime = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%04d-%02d-%02d %02d:%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute
	]

extends Resource
class_name FighterData

# === BASE STATS ===
@export var character_name: String = "Fighter"
@export var is_enemy: bool = false
@export var fighter_scene: PackedScene  # Scene to instantiate

# === COMBAT STATS ===
@export var max_hp: int = 100
@export var base_attack: int = 10
@export var base_defense: int = 5
@export var atb_speed: float = 1.0

# === ACTIONS ===
@export var available_actions: Array[Action] = []  # Actions this fighter can use

# === PROGRESSION (Heroes only) ===
@export var level: int = 1
@export var current_xp: int = 0
@export var xp_to_next_level: int = 100

# === STAT GROWTH (Heroes only) ===
@export var hp_growth: int = 10  # HP gained per level
@export var attack_growth: int = 2
@export var defense_growth: int = 1
@export var speed_growth: float = 0.05

# === REWARDS (Enemies only) ===
@export var xp_reward: int = 50
@export var gold_reward: int = 10
@export var loot_table: String = "common"  # Which loot table to use

func instantiate() -> Node:
	"""Create a Fighter instance from this data"""
	if fighter_scene == null:
		push_error("No fighter_scene set for %s" % character_name)
		return null

	var instance = fighter_scene.instantiate()
	# demande à l'instance de se configurer depuis ce Resource
	if instance.has_method("setup_from_data"):
		instance.setup_from_data(self)
	else:
		push_error("Instantiated scene doesn't implement setup_from_data()")

	return instance

func add_xp(xp_amount: int):
	"""Add XP and handle leveling up"""
	if is_enemy:
		return  # Enemies don't level up
	
	current_xp += xp_amount
	
	# Check for level up
	while current_xp >= xp_to_next_level:
		level_up()

func level_up():
	"""Increase level and stats"""
	level += 1
	current_xp -= xp_to_next_level
	
	# Increase stats
	max_hp += hp_growth
	base_attack += attack_growth
	base_defense += defense_growth
	atb_speed += speed_growth
	
	# Calculate next level XP requirement (exponential curve)
	xp_to_next_level = int(100 * pow(1.5, level - 1))
	
	print("%s reached level %d!" % [character_name, level])

func get_current_hp() -> int:
	"""Get current HP (stored in instance, not data)"""
	# This is handled by the Fighter instance
	return max_hp

func duplicate_fighter_data() -> FighterData:
	"""Create a true copy of this data"""
	var copy = self.duplicate(true)
	
	#old actions auto copy code:
	#copy.available_actions = available_actions.duplicate(true)
	
	# Manually deep copy the actions array
	copy.available_actions = []
	for action in available_actions:
		if action != null:
			copy.available_actions.append(action.duplicate(true))
			
	return copy

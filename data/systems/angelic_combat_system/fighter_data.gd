extends Resource
class_name FighterData

# --------------------------------------------------------------------
# IDENTITY
# --------------------------------------------------------------------

@export var character_name: String = "Fighter"

@export var faction: Faction.Type = Faction.Type.ENEMY

@export var fighter_scene: PackedScene

@export var fighter_3d_scene: PackedScene  # NEW: 3D visual representation


# --------------------------------------------------------------------
# COMBAT STATS (BASE TEMPLATE)
# --------------------------------------------------------------------

@export var base_hp: int = 100
@export var max_hp: int = 100
@export var base_attack: int = 10
@export var base_defense: int = 5
@export var base_atb: float = 0.0
@export var base_atb_speed: float = 1.0


# --------------------------------------------------------------------
# ACTIONS
# --------------------------------------------------------------------

@export var actions: Array[Action] = []


# --------------------------------------------------------------------
# REWARDS (DATA ONLY)
# --------------------------------------------------------------------

@export var xp_reward: int = 0
@export var gold_reward: int = 0
@export var loot_table: String = ""


# --------------------------------------------------------------------
# INSTANTIATION
# --------------------------------------------------------------------

func instantiate() -> Fighter:
	if fighter_scene == null:
		push_error("No fighter_scene set for %s" % character_name)
		return null

	var instance = fighter_scene.instantiate()
	if not instance.has_method("setup_from_data"):
		push_error("Fighter scene does not implement setup_from_data()")
		return null

	instance.setup_from_data(self)
	return instance


# --------------------------------------------------------------------
# DUPLICATION
# --------------------------------------------------------------------

func duplicate_fighter_data() -> FighterData:
	var copy: FighterData = duplicate(true)
	return copy

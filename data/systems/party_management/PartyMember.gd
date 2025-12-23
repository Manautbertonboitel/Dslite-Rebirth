extends Resource
class_name PartyMember

@export var base_data: FighterData

var level: int = 1
var current_xp: int = 0
var xp_to_next_level: int = 100

func add_xp(amount: int) -> void:
	current_xp += amount
	while current_xp >= xp_to_next_level:
		level_up()

func level_up() -> void:
	level += 1
	current_xp -= xp_to_next_level
	xp_to_next_level = int(100 * pow(1.5, level - 1))

	print("%s reached level %d" % [base_data.character_name, level])

func create_fighter_data() -> FighterData:
	var copy = base_data.duplicate_fighter_data()

	copy.max_hp += level * 10
	copy.base_attack += level * 2
	copy.base_defense += level * 1
	copy.base_atb_speed += level * 0.05

	return copy

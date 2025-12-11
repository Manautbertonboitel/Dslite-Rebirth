extends Node
class_name Fighter

# référence vers le FighterData original (utile pour récompenses, xp, etc.)
var original_data : Resource = null

# === BASE STATS ===
var character_name: String
var is_enemy: bool

# === COMBAT STATS ===
var hp : int
var max_hp: int
var attack: int
var defense: int
var atb: float
var atb_speed: float
var atb_ready: bool

# === ACTIONS ===
var actions: Array[Action] = []  # Actions this fighter can use
var selected_action : Resource = null

signal ready_to_act(combatant)

# Méthode appelée par FighterData.instantiate() pour initialiser l'instance
func setup_from_data(data: FighterData) -> void:
	original_data = data
	
	# === BASE STATS setup ===
	character_name = data.character_name
	is_enemy = data.is_enemy
	
	# === COMBAT STATS setup ===
	hp = data.hp
	max_hp = data.max_hp
	
	# hp check
	if hp > max_hp:
		hp = max_hp
		print_debug("WARNING, %s HPs were superior to their max HP value" % character_name)
		
	attack = data.base_attack
	defense = data.base_defense
	atb = data.atb
	atb_speed = data.atb_speed

	# === ACTIONS setup ===
	actions = []
	for a in data.actions:
		if a != null:
			actions.append(a.duplicate(true))

func _ready():
	# si hp n'est pas initialisé, s'assurer qu'il vaut max_hp
	if hp == null:
		print_debug("hp null from data, fallback to max hp")
		hp = max_hp

func _process(delta: float) -> void:
	# si atb_ready on ne recharge pas
	if atb_ready:
		return
	# la logique ATB : atb augmente selon atb_speed et le delta
	atb += atb_speed * delta
	if atb >= 100.0:
		atb = 100.0
		atb_ready = true
		emit_signal("ready_to_act", self)

func reset_atb() -> void:
	atb = 0.0
	atb_ready = false

func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	print("%s subit %d dégâts (HP restants : %d)" % [character_name, amount, hp])

func is_alive() -> bool:
	return hp > 0

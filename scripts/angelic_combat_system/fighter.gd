# Fighter.gd
extends Node
class_name Fighter

# === BASE STATS ===
@export var character_name: String = "Fighter"
@export var is_enemy: bool = false

# === COMBAT STATS ===
var hp : int = 100
@export var max_hp: int = 100
@export var attack: int = 10
@export var defense: int = 5
@export var atb_speed: float = 1.0

# === ACTIONS ===
@export var actions: Array[Action] = []  # Actions this fighter can use
var selected_action : Resource = null

var atb: float = 0.0
var atb_ready: bool = false

signal ready_to_act(combatant)

# référence vers le FighterData original (utile pour récompenses, xp, etc.)
var original_data : Resource = null

# Méthode appelée par FighterData.instantiate() pour initialiser l'instance
func setup_from_data(data: FighterData) -> void:
	original_data = data
	
	character_name = data.character_name
	is_enemy = data.is_enemy
	max_hp = data.max_hp
	hp = max_hp
	attack = data.base_attack
	defense = data.base_defense
	atb_speed = data.atb_speed
	
	# Dupliquer profondément les actions
	actions = []
	for a in data.available_actions:
		if a != null:
			actions.append(a.duplicate(true))

	# autres initialisations si nécessaire (level, xp, ...)
	# level, current_xp, etc. restent dans le FighterData original — si tu veux les modifier en combat,
	# tu peux soit les mettre ici, soit appeler des fonctions sur original_data.

func _ready():
	# si hp n'est pas initialisé, s'assurer qu'il vaut max_hp
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

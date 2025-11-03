extends Node
class_name Fighter

@export var character_name : String = "Unnamed"

@export var is_enemy : bool = false

@export var max_hp : int = 100
@export var hp : int = 100
@export var max_mp : int = 100
@export var mp : int = 100
@export var attack: int = 10
@export var defense: int = 10

@export var actions : Array[Resource] = []  # liste d’actions (qu’on configure dans l’Inspector)
var selected_action : Resource = null  # action en cours choisie par le joueur

@export var atb_speed: float = 25.0
var atb: float = 0.0
var atb_ready: bool = false
signal ready_to_act(combatant)

func _ready():
	hp = max_hp
	mp = max_mp

func _process(delta):
	if atb_ready:
		return
	atb += atb_speed * delta
	if atb >= 100:
		atb = 100
		atb_ready = true
		emit_signal("ready_to_act", self)

func reset_atb():
	atb = 0
	atb_ready = false

func take_damage(amount: int):
	hp = max(0, hp - amount)
	print("%s subit %d dégâts (HP restants : %d)" % [character_name, amount, hp])

func is_alive() -> bool:
	return hp > 0

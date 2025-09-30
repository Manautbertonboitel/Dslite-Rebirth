extends Node
class_name Fighter

@export var characterName : String
@export var max_hp : int
@export var hp : int
@export var max_mp : int
@export var mp : int
@export var is_enemy : bool = false
@export var actions : Array[Resource] = []  # liste d’actions (qu’on configure dans l’Inspector)

func _ready():
	hp = max_hp
	mp = max_mp

func take_damage(amount: int):
	hp = max(0, hp - amount)
	print("%s subit %d dégâts (HP restants : %d)" % [characterName, amount, hp])

func is_alive() -> bool:
	return hp > 0

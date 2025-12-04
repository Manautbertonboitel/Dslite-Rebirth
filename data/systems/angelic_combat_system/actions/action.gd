extends Resource
class_name Action

@export var action_name : String
@export var power : int
@export var cost : int = 0

func execute(caster, target):
	print("%s utilise %s sur %s !" % [caster.character_name, action_name, target.character_name])
	target.take_damage(power)

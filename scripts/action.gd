extends Resource
class_name Action

@export var actionName : String
@export var power : int
@export var cost : int = 0

func execute(caster, target):
	print("%s utilise %s sur %s !" % [caster.characterName, actionName, target.characterName])
	target.take_damage(power)

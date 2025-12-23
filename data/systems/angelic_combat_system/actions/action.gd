extends Resource
class_name Action

signal completed

@export var action_name: String
@export var power: int
@export var cost: int = 0

func execute(caster: Fighter, target: Fighter) -> void:
	print("%s uses %s on %s" % [
		caster.character_name,
		action_name,
		target.character_name
	])

	# Example: simulate animation time
	await caster.get_tree().create_timer(0.5).timeout

	target.take_damage(power)

	await caster.get_tree().create_timer(0.2).timeout
	emit_signal("completed")

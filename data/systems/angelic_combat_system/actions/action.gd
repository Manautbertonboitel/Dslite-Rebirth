extends Resource
class_name Action

signal completed
signal request_dodge_window(
	caster: Fighter,
	target: Fighter,
	duration: float
)

const ACTION_ANIMATION_TIME = 0.5
const DAMAGE_DELAY_TIME = 0.2
const DODGE_WINDOW_DURATION = 5.0

@export var action_name: String
@export var power: int
@export var cost: int = 0

func execute(caster: Fighter, target: Fighter, combat_manager: CombatManager) -> void:
#	print("%s uses %s on %s" % [caster.character_name, action_name, target.character_name])

	# Example: simulate animation time
#	await caster.get_tree().create_timer(ACTION_ANIMATION_TIME).timeout
#
#	await caster.get_tree().create_timer(DAMAGE_DELAY_TIME).timeout
	

	# windup
	await _play_windup(caster)

	# hit 1
	if caster.faction == Faction.Type.ENEMY and target.faction == Faction.Type.PLAYER:
		request_dodge_window.emit(caster, target, DODGE_WINDOW_DURATION)
		var dodged = await _wait_for_dodge_result(combat_manager)
		if not dodged:
			print("=== Dodge window expired - attack hits! ===")
			target.take_damage(power)
	else:
		target.take_damage(power)
		
	# hit 2
#	emit_signal("request_dodge_window", caster, target, 0.2)
#	dodged = await _wait_for_dodge_result()
#	if not dodged:
#		target.take_damage(power)
		
	emit_signal("completed") 
	
func _play_windup(caster: Fighter):
	await caster.get_tree().create_timer(ACTION_ANIMATION_TIME).timeout
	
func _wait_for_dodge_result(combat_manager) -> bool:
	return await combat_manager.dodge_resolved

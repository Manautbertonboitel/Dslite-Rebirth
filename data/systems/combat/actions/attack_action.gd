class_name AttackAction
extends Action

signal request_dodge_window(caster: Fighter, target: Fighter, duration: float)

const ACTION_WINDUP_TIME = 0.5
const DAMAGE_DELAY_TIME = 0.5
const DODGE_WINDOW_DURATION = 5.0

@export var power: int = 0
@export var cost: int = 0


func _init():
	pass
#	targeting_type = TargetingType.SINGLE_HOSTILE
#	requires_target_selection = true
	
	

func can_execute(caster: Fighter, combat_manager: CombatManager) -> bool:
	return caster.hp > 0 and get_valid_targets(caster, combat_manager).size() > 0


func execute(caster: Fighter, combat_manager: CombatManager, target: Fighter) -> void:
	if target == null or not target.is_alive():
		push_error("AttackAction requires a valid target")
		completed.emit()
		return
	
	await _play_windup(caster)

	if caster.faction == Faction.Type.ENEMY and target.faction == Faction.Type.PLAYER:
		request_dodge_window.emit(caster, target, DODGE_WINDOW_DURATION)
		var dodged = await combat_manager.dodge_resolved
		if not dodged:
			print("=== Dodge window expired - attack hits! ===")
			target.visuals.hide_dodge_indicator()
			caster.visuals.clear_attack_indicator()
			await _play_hit_animation(caster)
			target.take_damage(power)
	else:
		await _play_hit_animation(caster)
		target.take_damage(power)
		
	completed.emit()
	
func _play_windup(caster: Fighter):
	await caster.get_tree().create_timer(ACTION_WINDUP_TIME).timeout

func _play_hit_animation(caster: Fighter):
	await caster.get_tree().create_timer(DAMAGE_DELAY_TIME).timeout

extends Action
class_name RollAction

func execute(caster: Fighter, combat_manager: CombatManager, target: Fighter, ) -> void:
	# Roll doesn't need a target, but we keep signature compatible
	print("%s initiates ROLL" % caster.character_name)
	
	# No animation delay needed - handled by combat_manager
	emit_signal("completed")

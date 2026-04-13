class_name RollAction
extends Action

func can_execute(caster: Fighter, combat_manager: CombatManager) -> bool:
	# Peut seulement esquiver pendant une dodge window
	if not combat_manager.dodge_window_active and combat_manager.state_machine.current_state == ActionExecuteState:
		print("Cannot roll - attack hits!")
		return false
#	elif combat_manager.pending_attack_target != combat_manager.current_character:
#		print("You are not the target of this attack!")
#		return false
	
	# Vérifier si la formation permet l'esquive (besoin de 2+ fighters vivants)
	var formation: Formation = combat_manager.hero_formation if caster.faction == Faction.Type.PLAYER else combat_manager.enemy_formation
	return formation.can_dodge()

func execute(caster: Fighter, combat_manager: CombatManager, _target: Fighter = null) -> void:
	# ("target" ne sera jamais utilisé logiquement pour une action de roll / dodge, donc renamed en _target pour éviter les warnings)
	
	print("%s initiates ROLL" % caster.character_name)
	
	var formation: Formation = combat_manager.hero_formation if caster.faction == Faction.Type.PLAYER else combat_manager.enemy_formation
	var position_mapping: CombatManager.PositionMapping = combat_manager.hero_position_mapping if caster.faction == Faction.Type.PLAYER else combat_manager.enemy_position_mapping
	
	# Effectuer l'esquive dans la formation
	formation.dodge_clockwise()
	
	# Mettre à jour les positions visuelles 3D
	formation.update_visual_positions(position_mapping, combat_manager.ACTION_ANIMATION_TIME)
	
	# Informer que l'esquive a réussi
	combat_manager.dodge_resolved.emit(true)
	
	# Nettoyer les indicateurs visuels
	if combat_manager.pending_attack_target and combat_manager.pending_attack_target.visuals:
		combat_manager.pending_attack_target.visuals.hide_dodge_indicator()
	if combat_manager.pending_attack_caster and combat_manager.pending_attack_caster.visuals:
		combat_manager.pending_attack_caster.visuals.clear_attack_indicator()
	
	combat_manager.pending_attack_target = null
	combat_manager.pending_attack_caster = null

	caster.reset_atb()
	combat_manager.evaluate_battle_state()
	# Pas besoin de "combat_manager.action_queue.pop_front()" comme dans attack_action.gd, car ici on a bypass la action_queue pour lancer l'action
	
	combat_manager.update_action_queue_debug()
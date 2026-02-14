class_name ActionExecuteState
extends CombatState

var state_name: String = "Action Execute State"

func enter(combat_manager: CombatManager):		
	var request: ActionRequest = combat_manager.action_queue[0]

	# Vérifier si le caster est vivant
	if not request.caster.is_alive():
		combat_manager.action_queue.pop_front()
		combat_manager.evaluate_battle_state()
		return

	# Vérifier si l'action peut être exécutée
	if not request.action.can_execute(request.caster, combat_manager):
		print("Action cannot be executed: %s" % request.action.action_name)
		combat_manager.action_queue.pop_front()
		combat_manager.evaluate_battle_state()
		return


	# Connexion dodge window
	if request.action is AttackAction:
		request.action.request_dodge_window.connect(combat_manager._start_dodge_window)
	
	# Exécution de l'action
	await request.action.execute(request.caster, combat_manager, request.target)
	
	# Déconnexion dodge window
	if request.action is AttackAction:
		if request.action.request_dodge_window.is_connected(combat_manager._start_dodge_window):
			request.action.request_dodge_window.disconnect(combat_manager._start_dodge_window)
	
	combat_manager.action_queue.pop_front()
	request.caster.reset_atb()
	combat_manager.update_action_queue()
	combat_manager.evaluate_battle_state()

func update(manager: CombatManager, delta: float):
	pass

func exit(manager: CombatManager):
	pass

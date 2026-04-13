class_name ActionExecuteState
extends CombatState

var state_name: String = "Action Execute State"
var combat_manager: CombatManager
var request: ActionRequest

func enter(mgr: CombatManager):		
	combat_manager = mgr
	request = combat_manager.action_queue[0]

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

	#request.action.completed.connect(_on_action_completed)
	
	# Exécution de l'action
	# warning "(REDUNDANT_AWAIT)" en cours de fix -> github.com/godotengine/godot/pull/110996 (ça met un warning alors qu'on met bien des await dans la method qui hérite)
	await request.action.execute(request.caster, combat_manager, request.target)

func update(_manager: CombatManager, _delta: float):
	pass

func exit(_manager: CombatManager):
	# reset des variables au cas où, je sais pas si c'est utile mais au moins c'est la
	combat_manager = null
	request = null
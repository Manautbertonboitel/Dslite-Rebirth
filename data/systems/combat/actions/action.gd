@abstract 
class_name Action
extends Resource

# ignore le warning, ce signal est bien utilisé dans les class qui hérient de action.gd
signal completed

# Types de ciblage
enum TargetingType {
	SINGLE_HOSTILE,      # 1 ennemi
	SINGLE_ALLY,         # 1 allié TODO peut-être rajouter pour 2 alliés ou ennemies seulement si jamais, ou custom (choisir 3 alliés sur 4 par ex), etc.
	ALL_HOSTILES,        # Tous les ennemis ("AOE")
	ALL_ALLIES,          # Tous les alliés ("AOE")
	SELF,                # Soi-même
	NONE                 # Pas de cible (fuite ou autre sort ne necessitant pas de ciblage particulier)
}

@export var action_name: String
@export var can_bypass_action_queue: bool = false
@export var requires_target_selection: bool = true  # false pour AOE/Flee/Self
@export var targeting_type: TargetingType = TargetingType.SINGLE_HOSTILE

# s'assurer que son implémentation return bien true ou false dans les class qui héritent
@abstract func can_execute(caster: Fighter, combat_manager: CombatManager) -> bool

# Execute l'action - selected_target est null pour AOE/Flee/Self"""
@abstract func execute(caster: Fighter, combat_manager: CombatManager, target: Fighter) -> void


func get_valid_targets(caster: Fighter, combat_manager: CombatManager) -> Array[Fighter]:
	"""Retourne les cibles valides selon le type de ciblage"""
	match targeting_type:
		TargetingType.SINGLE_HOSTILE:
			return get_hostile_targets(caster, combat_manager)
		TargetingType.SINGLE_ALLY:
			return get_allied_targets(caster, combat_manager)
		TargetingType.ALL_HOSTILES:
			return get_hostile_targets(caster, combat_manager)
		TargetingType.ALL_ALLIES:
			return get_allied_targets(caster, combat_manager)
		TargetingType.SELF:
			return [caster]
		TargetingType.NONE:
			return []
	return []

func get_hostile_targets(source: Fighter, mgr: CombatManager) -> Array[Fighter]:
	var result: Array[Fighter] = []
	for f in mgr.fighters:
		if f.is_alive() and is_hostile(source, f):
			result.append(f)
	return result
	
func get_allied_targets(source: Fighter, mgr: CombatManager) -> Array[Fighter]:
	var result: Array[Fighter] = []
	for f in mgr.fighters:
		if f.is_alive() and not is_hostile(source, f):
			result.append(f)
	return result

func is_hostile(a: Fighter, b: Fighter) -> bool:
	return a.faction != b.faction
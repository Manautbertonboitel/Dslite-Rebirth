class_name Action
extends Resource

signal completed

@export var action_name: String
@export var can_bypass_action_queue: bool = false

# Types de ciblage
enum TargetingType {
	SINGLE_HOSTILE,      # 1 ennemi
	SINGLE_ALLY,         # 1 allié TODO peut-être rajouter pour 2 alliés / ennemies si jamais, ou custom, etc.
	ALL_HOSTILES,        # Tous les ennemis (AOE)
	ALL_ALLIES,          # Tous les alliés (AOE)
	SELF,                # Soi-même
	NONE                 # Pas de cible (fuite)
}

@export var targeting_type: TargetingType = TargetingType.SINGLE_HOSTILE
@export var requires_target_selection: bool = true  # false pour AOE/Flee/Self

# Méthodes que chaque action doit implémenter
func can_execute(caster: Fighter, combat_manager: CombatManager) -> bool:
	return true

func get_valid_targets(caster: Fighter, combat_manager: CombatManager) -> Array[Fighter]:
	"""Retourne les cibles valides selon le type de ciblage"""
	match targeting_type:
		TargetingType.SINGLE_HOSTILE:
			return combat_manager.get_hostile_targets(caster)
		TargetingType.SINGLE_ALLY:
			return combat_manager.get_allied_targets(caster)
		TargetingType.ALL_HOSTILES:
			return combat_manager.get_hostile_targets(caster)
		TargetingType.ALL_ALLIES:
			return combat_manager.get_allied_targets(caster)
		TargetingType.SELF:
			return [caster]
		TargetingType.NONE:
			return []
	return []

func execute(caster: Fighter, combat_manager: CombatManager, target: Fighter) -> void:
	"""Execute l'action - selected_target est null pour AOE/Flee/Self"""
	push_error("Must implement execute() in derived class")

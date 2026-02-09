@abstract
extends Node
class_name BattleState

@abstract func enter(manager: CombatManager) -> void

@abstract func update(manager: CombatManager, delta: float) -> void

@abstract func exit(manager: CombatManager) -> void

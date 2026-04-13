@abstract
class_name FighterController
extends Node


@abstract func take_turn(fighter: Fighter, combat_manager: CombatManager) -> void
# take_turn() must be implemented by subclass

#TODO Vu que les IA ne vont plus dans la ready queue, peut-être plus besoin de séparer les controller en AIController et PlayerController

class_name ActionRequest
extends RefCounted

var caster: Fighter
var action: Action
var target: Fighter  # Peut être null pour AOE/Flee

func _init(p_caster: Fighter, p_action: Action, p_target: Fighter):
	caster = p_caster
	action = p_action
	target = p_target

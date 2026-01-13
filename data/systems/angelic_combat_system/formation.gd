extends RefCounted
class_name Formation

enum Position { UP, RIGHT, DOWN, LEFT }

var slots: Dictionary = {
	Position.UP: null,
	Position.RIGHT: null, 
	Position.DOWN: null,
	Position.LEFT: null
}

var revolt_count: int = 0

# --------------------------------------------------------------------
# FIGHTER MANAGEMENT
# --------------------------------------------------------------------

func assign_fighter(fighter: Fighter, pos: Position) -> bool:
	"""Assign a fighter to a position. Returns false if slot is occupied."""
	if slots[pos] != null:
		push_warning("Formation slot %s already occupied" % Position.keys()[pos])
		return false
	
	slots[pos] = fighter
	fighter.formation_position = pos
	return true


func remove_fighter(fighter: Fighter) -> bool:
	"""Remove a fighter from the formation. Returns true if found and removed."""
	for pos in slots:
		if slots[pos] == fighter:
			slots[pos] = null
			fighter.formation_position = -1  # Invalid position marker
			print("🗑️ [FORMATION] Removed %s from %s" % [fighter.character_name, Position.keys()[pos]])
			return true
	return false


func find_first_empty_slot() -> Variant:
	"""Returns first empty Position enum value, or null if all full"""
	for pos in [Position.UP, Position.RIGHT, Position.DOWN, Position.LEFT]:
		if slots[pos] == null:
			return pos
	return null


func get_fighter_at(pos: Position) -> Fighter:
	"""Get fighter at specific position, returns null if empty"""
	return slots.get(pos, null)


# --------------------------------------------------------------------
# FORMATION QUERIES
# --------------------------------------------------------------------

func get_fighters() -> Array[Fighter]:
	"""Get all fighters in formation (including dead ones)"""
	var result: Array[Fighter] = []
	for pos in [Position.UP, Position.RIGHT, Position.DOWN, Position.LEFT]:
		if slots[pos]:
			result.append(slots[pos])
	return result


func get_alive_fighters() -> Array[Fighter]:
	"""Get only living fighters in formation"""
	var result: Array[Fighter] = []
	for pos in slots:
		if slots[pos] and slots[pos].is_alive():
			result.append(slots[pos])
	return result


func can_roll() -> bool:
	"""Check if formation can roll (needs 2+ alive fighters)"""
	return get_alive_fighters().size() > 1


func is_empty() -> bool:
	"""Check if formation has no fighters at all"""
	return get_fighters().is_empty()


func get_occupied_positions() -> Array:
	"""Get list of Position enums that have fighters"""
	var result: Array = []
	for pos in slots:
		if slots[pos] != null:
			result.append(pos)
	return result


# --------------------------------------------------------------------
# FORMATION MANIPULATION
# --------------------------------------------------------------------

func roll_clockwise():
	"""Rotate all fighters clockwise around formation"""
	var temp = slots[Position.UP]
	slots[Position.UP] = slots[Position.LEFT]
	slots[Position.LEFT] = slots[Position.DOWN]
	slots[Position.DOWN] = slots[Position.RIGHT]
	slots[Position.RIGHT] = temp
	
	# Update each fighter's position reference
	for pos in slots:
		if slots[pos]:
			slots[pos].formation_position = pos
	
	revolt_count += 1
	print("🔄 [FORMATION] Rolled clockwise (count: %d)" % revolt_count)


# --------------------------------------------------------------------
# VISUAL UPDATES
# --------------------------------------------------------------------

func update_visual_positions(position_mapping) -> void:
	"""Update 3D visuals for all fighters based on current formation"""
	for pos in slots:
		var fighter = slots[pos]
		if fighter and fighter.visuals and is_instance_valid(fighter.visuals):
			var target_node = position_mapping.get_node(pos)
			if target_node:
				fighter.visuals.move_to(target_node.global_transform, 0.3)


# --------------------------------------------------------------------
# DEBUG
# --------------------------------------------------------------------

func get_formation_visual_string() -> String:
	"""Debug: Visual representation of formation"""
	var up = slots[Position.UP].character_name if slots[Position.UP] else "-"
	var right = slots[Position.RIGHT].character_name if slots[Position.RIGHT] else "-"
	var down = slots[Position.DOWN].character_name if slots[Position.DOWN] else "-"
	var left = slots[Position.LEFT].character_name if slots[Position.LEFT] else "-"
	
	return """
	    %s
	%s  +  %s
	    %s
	""" % [up, left, right, down]


func print_formation_state() -> void:
	"""Debug: Print detailed formation state"""
	print("=== Formation State ===")
	print("Revolt Count: %d" % revolt_count)
	print("Total Fighters: %d" % get_fighters().size())
	print("Alive Fighters: %d" % get_alive_fighters().size())
	for pos in [Position.UP, Position.RIGHT, Position.DOWN, Position.LEFT]:
		var fighter = slots[pos]
		var status = ""
		if fighter:
			status = "%s (HP: %d/%d) %s" % [
				fighter.character_name,
				fighter.hp,
				fighter.max_hp,
				"💀" if not fighter.is_alive() else "✓"
			]
		else:
			status = "EMPTY"
		print("  %s: %s" % [Position.keys()[pos], status])
	print("======================")

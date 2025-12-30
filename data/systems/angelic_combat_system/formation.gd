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

func assign_fighter(fighter: Fighter, pos: Position):
	slots[pos] = fighter
	fighter.formation_position = pos

func roll_clockwise():
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

func get_fighters() -> Array[Fighter]:
	var result: Array[Fighter] = []
	for pos in [Position.UP, Position.RIGHT, Position.DOWN, Position.LEFT]:
		if slots[pos]:
			result.append(slots[pos])
	return result

func can_roll() -> bool:
	return get_fighters().size() > 1

func get_formation_visual_string() -> String:
	"""Debug: Visual representation of formation"""
	var up = "X" if slots[Position.UP] else "-"
	var right = "X" if slots[Position.RIGHT] else "-"
	var down = "X" if slots[Position.DOWN] else "-"
	var left = "X" if slots[Position.LEFT] else "-"
	
	return """
	  %s
	%s + %s
	  %s
	""" % [up, left, right, down]

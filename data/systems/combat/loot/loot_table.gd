# === LOOT TABLE RESOURCE ===
extends Resource
class_name LootTable

@export var table_name: String = "Common Loot"
@export var loot_entries: Array[LootEntry] = []

func roll_item() -> ItemData:
	"""Roll for a random item based on drop rates"""
	if loot_entries.is_empty():
		return null
	
	# Calculate total weight
	var total_weight = 0.0
	for entry in loot_entries:
		total_weight += entry.drop_chance
	
	# Roll
	var roll = randf() * total_weight
	var current_weight = 0.0
	
	for entry in loot_entries:
		current_weight += entry.drop_chance
		if roll <= current_weight:
			return entry.item
	
	return null  # No item dropped

# === LOOT ENTRY (Used inside LootTable) ===
extends Resource
class_name LootEntry

@export var item: ItemData
@export_range(0.0, 100.0) var drop_chance: float = 50.0  # Weight for random roll

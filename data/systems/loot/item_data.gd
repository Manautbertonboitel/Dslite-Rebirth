# === ITEM DATA RESOURCE ===
extends Resource
class_name ItemData

@export var item_name: String = "Item"
@export var description: String = ""
@export var icon: Texture2D
@export_enum("Consumable", "Equipment", "KeyItem", "Material") var item_type: String = "Material"
@export var value: int = 10
@export var stack_size: int = 99  # How many can stack in inventory

# For consumables
@export var hp_restore: int = 0
@export var mp_restore: int = 0

# For equipment
@export var attack_bonus: int = 0
@export var defense_bonus: int = 0
@export var speed_bonus: float = 0.0

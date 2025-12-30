extends Node
class_name Fighter

# --------------------------------------------------------------------
# DATA & IDENTITY
# --------------------------------------------------------------------

var original_data: FighterData = null
var character_name: String

var faction: Faction.Type

var formation_position: int = -1  # Formation.Position enum value

# Controller (PlayerController or AIController)
var controller = null


# --------------------------------------------------------------------
# COMBAT STATS
# --------------------------------------------------------------------

var hp: int
var max_hp: int
var attack: int
var defense: int

var atb: float
var atb_speed: float
var atb_ready: bool = false
var atb_paused: bool = false


# --------------------------------------------------------------------
# ACTIONS
# --------------------------------------------------------------------

var actions: Array[Action] = []
var selected_action: Action = null


# --------------------------------------------------------------------
# SIGNALS
# --------------------------------------------------------------------

signal ready_to_act(fighter)
signal died(fighter)


# --------------------------------------------------------------------
# INITIALIZATION
# --------------------------------------------------------------------

func setup_from_data(data: FighterData) -> void:
	original_data = data

	character_name = data.character_name
	
	#factions are always setup outside this code (Faction is a runtime combat property, not a data-template property.), here is only a fallback
	if faction == null:
		faction = data.faction

	hp = data.base_hp
	max_hp = data.max_hp
	hp = min(hp, max_hp)

	attack = data.base_attack
	defense = data.base_defense

	atb = data.base_atb
	atb_speed = data.base_atb_speed
	atb_ready = false

	actions.clear()
	for a in data.actions:
		if a != null:
			actions.append(a.duplicate(true))


func _ready():
	#JE SAIS PLUS POURQUOI J'AI FAIT ÇA
	if hp <= 0:
		hp = max_hp


# --------------------------------------------------------------------
# ATB LOGIC
# --------------------------------------------------------------------

func _process(delta: float) -> void:
	if atb_paused or atb_ready:
		return

	atb += atb_speed * delta
	if atb >= 100.0:
		atb = 100.0
		atb_ready = true
		emit_signal("ready_to_act", self)


func pause_atb(paused: bool) -> void:
	atb_paused = paused


func reset_atb() -> void:
	atb = 0.0
	atb_ready = false


# --------------------------------------------------------------------
# DAMAGE & DEATH
# --------------------------------------------------------------------

func take_damage(amount: int) -> void:
	if not is_alive():
		return

	hp = max(0, hp - amount)
	print("%s takes %d damage (HP: %d)" % [character_name, amount, hp])

	if hp == 0:
		_die()


func _die() -> void:
	print("%s died" % character_name)
	emit_signal("died", self)


func is_alive() -> bool:
	return hp > 0

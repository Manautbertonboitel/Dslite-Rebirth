extends Control
class_name CharacterATBDisplay

# Référence vers le Fighter que ce display représente
var fighter: Fighter = null

# Références vers les nodes enfants
@onready var name_label = $NameLabel
@onready var hp_label = $HPLabel
#@onready var mp_label = $MPLabel
@onready var atb_bar = $ATBBar

func setup(f: Fighter):
	fighter = f
	# Configuration initiale de la ProgressBar
	atb_bar.min_value = 0
	atb_bar.max_value = 100
	atb_bar.value = 0
	update_display()  # ← On veut afficher TOUT DE SUITE les infos
	
func _process(_delta):
	if fighter == null:
		return  # Pas de fighter assigné, on fait rien
	# Mettre à jour tous les labels
	update_display()

func update_display():
	# TODO: on va remplir ça ensemble
	name_label.text = fighter.character_name
	hp_label.text = "HP: %d/%d" % [fighter.hp, fighter.max_hp]
	#mp_label.text = "MP: %d/%d" % [fighter.mp, fighter.max_mp]
	atb_bar.value = fighter.atb
	
	# Si mort, griser l'affichage
	if not fighter.is_alive():
		modulate = Color(1, 1, 1, 0.3)  # Semi-transparent
	else:
		modulate = Color(1, 1, 1, 1)    # Normal

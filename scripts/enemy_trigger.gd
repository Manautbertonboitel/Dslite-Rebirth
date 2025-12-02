extends Area3D

@export var enemy_team: FighterPool
@export var trigger_id: String = ""  # Unique ID for this trigger (set in inspector!)
@export var respawns: bool = false  # Does this trigger come back?
@export var respawn_time: float = 300.0  # 5 minutes (for respawning enemies)

func _ready():
	# Auto-generate ID if not set (uses scene path + name)
	if trigger_id == "":
		trigger_id = get_path()
	
	# Check if already defeated
	if GameManager.is_trigger_defeated(trigger_id):
		if respawns:
			# Check if enough time has passed
			var time_defeated = GameManager.get_trigger_defeat_time(trigger_id)
			var time_elapsed = Time.get_unix_time_from_system() - time_defeated
			
			if time_elapsed < respawn_time:
				queue_free()  # Not respawned yet
				return
			else:
				# Respawn! Clear the defeated flag
				GameManager.clear_defeated_trigger(trigger_id)
		else:
			queue_free()  # Permanently defeated
			return
	
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player"):
		if enemy_team == null:
			push_error("No enemy team configured for trigger %s" % name)
			return
		
		print("Combat triggered: %s" % trigger_id)
		
		# Register as defeated BEFORE starting combat
		# (in case combat scene fails to load)
		GameManager.register_defeated_trigger(trigger_id)
		
		# Start combat
		GameManager.start_combat(enemy_team, false)

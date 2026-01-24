extends Node3D
class_name FighterVisuals

## Handles all 3D visual representation for a Fighter
## Separates rendering concerns from game logic

var fighter: Fighter
var model: Node3D
var position_tween: Tween

# Visual effect nodes (you can extend these)
var dodge_indicator: Node3D = null
var attack_indicator: Node3D = null

signal death_animation_completed

# --------------------------------------------------------------------
# SETUP
# --------------------------------------------------------------------

func setup(fighter_data: FighterData, fighter_ref: Fighter) -> bool:
	"""Initialize the visual representation. Returns false if setup fails."""
	fighter = fighter_ref
	
	if not fighter_data.fighter_3d_scene:
		push_warning("No 3D scene for fighter: %s" % fighter_data.character_name)
		return false
	
	model = fighter_data.fighter_3d_scene.instantiate()
	if not model:
		push_error("Failed to instantiate 3D scene for: %s" % fighter_data.character_name)
		return false
	
	add_child(model)
	return true


# --------------------------------------------------------------------
# POSITIONING
# --------------------------------------------------------------------

func set_initial_position(target_transform: Transform3D) -> void:
	"""Set position instantly without animation"""
	global_transform = target_transform


func move_to(target_transform: Transform3D, duration: float) -> void:
	"""Smoothly move to target position"""
	if not is_instance_valid(self):
		return
	
	# Kill existing tween to prevent conflicts
	if position_tween and position_tween.is_valid():
		position_tween.kill()
	
	position_tween = create_tween()
	position_tween.set_ease(Tween.EASE_IN_OUT)
	position_tween.set_trans(Tween.TRANS_CUBIC)
	position_tween.tween_property(self, "global_position", target_transform.origin, duration)
	position_tween.parallel().tween_property(self, "global_rotation", target_transform.basis.get_euler(), duration)


# --------------------------------------------------------------------
# DEATH HANDLING
# --------------------------------------------------------------------

func play_death_animation() -> void:
	"""Play death effect and clean up"""
	if not is_instance_valid(self) or not is_instance_valid(model):
		return
	
	# Cancel any ongoing movement
	if position_tween and position_tween.is_valid():
		position_tween.kill()
	
	# Example death animation: fade out and fall
	var death_tween = create_tween()
	death_tween.set_parallel(true)
	
	# Fade out
	if model.has_method("set_transparency"):
		death_tween.tween_method(
			func(value): _set_model_alpha(value),
			1.0, 0.0, 1.0
		)
	
	# Fall down
	death_tween.tween_property(model, "position:y", model.position.y - 2.0, 1.0)
	
	# Cleanup after animation
	death_tween.chain().tween_callback(func():
		death_animation_completed.emit()
		queue_free()
	)


func _set_model_alpha(alpha: float) -> void:
	"""Helper to set transparency on model materials"""
	if not is_instance_valid(model):
		return
	
	# This is a simplified approach - adjust based on your model structure
	for child in model.get_children():
		if child is MeshInstance3D:
			var material = child.get_active_material(0)
			if material:
				material = material.duplicate()
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.albedo_color.a = alpha
				child.set_surface_override_material(0, material)


# --------------------------------------------------------------------
# VISUAL EFFECTS
# --------------------------------------------------------------------

func show_dodge_indicator() -> void:
	"""Show visual effect indicating this fighter needs to dodge"""
	if dodge_indicator:
		return  # Already showing
	
	# Example: Create a pulsing ring around the fighter
	# You can replace this with your own effect
	dodge_indicator = _create_simple_ring(Color.RED)
	add_child(dodge_indicator)
	
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(dodge_indicator, "scale", Vector3.ONE * 1.2, 0.5)
	pulse_tween.tween_property(dodge_indicator, "scale", Vector3.ONE * 0.8, 0.5)


func hide_dodge_indicator() -> void:
	"""Remove dodge indicator"""
	if dodge_indicator and is_instance_valid(dodge_indicator):
		dodge_indicator.queue_free()
		dodge_indicator = null


func show_attack_windup(target_visual: FighterVisuals) -> void:
	"""Show visual effect for incoming attack"""
	if not is_instance_valid(target_visual):
		return
	
	# Example: Draw line or projectile path
	# This is a placeholder - implement based on your game's style
	pass


func clear_attack_indicator() -> void:
	"""Remove attack indicator"""
	if attack_indicator and is_instance_valid(attack_indicator):
		attack_indicator.queue_free()
		attack_indicator = null


# --------------------------------------------------------------------
# HELPERS
# --------------------------------------------------------------------

func _create_simple_ring(color: Color) -> MeshInstance3D:
	"""Create a simple ring mesh for indicators"""
	var mesh_instance = MeshInstance3D.new()
	var torus_mesh = TorusMesh.new()
	torus_mesh.inner_radius = 0.8
	torus_mesh.outer_radius = 1.0
	torus_mesh.rings = 32
	torus_mesh.ring_segments = 16
	
	mesh_instance.mesh = torus_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	mesh_instance.set_surface_override_material(0, material)
	
	mesh_instance.position.y = 0.1  # Slightly above ground
	# mesh_instance.rotation.x = PI / 2  # Lay flat
	
	return mesh_instance


func cleanup() -> void:
	"""Force cleanup of all visual elements"""
	hide_dodge_indicator()
	clear_attack_indicator()
	
	if position_tween and position_tween.is_valid():
		position_tween.kill()
	
	if is_instance_valid(model):
		model.queue_free()
	
	queue_free()

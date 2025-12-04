# === COMBAT TRANSITION MANAGER (Add to autoload) ===
# Create: res://autoload/transition_manager.gd
# Add to AutoLoad as "TransitionManager"

extends CanvasLayer

enum TransitionType {
	SWIRL,        # FF7-style swirl
	SHATTER,      # Screen shatters
	FADE,         # Simple fade
	WIPE,         # Wipe from side
	ZOOM_IN,      # Zoom to black
}

@export var transition_type: TransitionType = TransitionType.ZOOM_IN
@export var transition_duration: float = 1.5

var animation_player: AnimationPlayer
var color_rect: ColorRect
var shader_rect: ColorRect
var is_transitioning: bool = false

signal transition_finished

func _ready():
	# Create UI elements
	setup_transition_ui()
	
	# Create animations
	setup_animations()

func setup_transition_ui():
	# Black overlay
	color_rect = ColorRect.new()
	color_rect.color = Color.BLACK
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.visible = false
	add_child(color_rect)
	
	# Shader overlay (for fancy effects)
	shader_rect = ColorRect.new()
	shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	shader_rect.visible = false
	add_child(shader_rect)
	
	# Animation player
	animation_player = AnimationPlayer.new()
	add_child(animation_player)

func setup_animations():
	# Simple fade animation
	var fade_anim = Animation.new()
	fade_anim.length = transition_duration
	
	# Track for color_rect visibility
	var track_vis = fade_anim.add_track(Animation.TYPE_VALUE)
	fade_anim.track_set_path(track_vis, ".:color_rect:visible")
	fade_anim.track_insert_key(track_vis, 0.0, true)
	
	# Track for color_rect alpha
	var track_alpha = fade_anim.add_track(Animation.TYPE_VALUE)
	fade_anim.track_set_path(track_alpha, ".:color_rect:color:a")
	fade_anim.track_insert_key(track_alpha, 0.0, 0.0)
	fade_anim.track_insert_key(track_alpha, transition_duration, 1.0)
	fade_anim.track_set_interpolation_type(track_alpha, Animation.INTERPOLATION_CUBIC)
	
	animation_player.add_animation_library("fade_out", fade_anim)

func transition_to_combat(combat_data: Dictionary):
	"""
	Start transition animation, then load combat
	combat_data should contain: enemy_team, atb_advantage
	"""
	if is_transitioning:
		return
	
	is_transitioning = true
	
	# Play transition animation
	match transition_type:
		TransitionType.FADE:
			await play_fade_transition()
		TransitionType.SWIRL:
			await play_swirl_transition()
		TransitionType.SHATTER:
			await play_shatter_transition()
		TransitionType.ZOOM_IN:
			await play_zoom_transition()
		_:
			await play_fade_transition()
	
	# Actually change scene
	get_tree().change_scene_to_file("res://data/maps/combat/combat_arena_1.tscn")
	
	# Fade in combat scene
	await play_fade_in()
	
	is_transitioning = false
	transition_finished.emit()

func transition_from_combat():
	"""Return to world with fade in"""
	if is_transitioning:
		return
	
	is_transitioning = true
	
	# Fade out combat
	await play_fade_transition()
	
	# Change back to world
	get_tree().change_scene_to_file(GameManager.return_scene_path)
	
	# Fade in world
	await play_fade_in()
	
	is_transitioning = false
	transition_finished.emit()

# === TRANSITION EFFECTS ===

func play_fade_transition() -> void:
	"""Simple fade to black"""
	color_rect.visible = true
	color_rect.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, transition_duration * 0.5)
	await tween.finished

func play_fade_in() -> void:
	"""Fade from black"""
	color_rect.visible = true
	color_rect.modulate.a = 1.0
	
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 0.0, transition_duration * 0.5)
	await tween.finished
	
	color_rect.visible = false

func play_swirl_transition() -> void:
	"""FF7-style swirl effect (using shader)"""
	shader_rect.visible = true
	
	# Apply swirl shader
	var shader_material = ShaderMaterial.new()
	shader_material.shader = preload("res://data/effects/swirl_transition.gdshader")
	shader_rect.material = shader_material
	
	# Animate shader parameter
	var tween = create_tween()
	tween.tween_method(
		func(value): shader_material.set_shader_parameter("progress", value),
		0.0, 1.0, transition_duration
	)
	await tween.finished
	
	shader_rect.visible = false

func play_shatter_transition() -> void:
	"""Screen shatter effect"""
	# Capture current screen
	var viewport = get_viewport()
	var img = viewport.get_texture().get_image()
	var texture = ImageTexture.create_from_image(img)
	
	# Create shatter particles
	var particles = create_shatter_particles(texture)
	add_child(particles)
	particles.emitting = true
	
	# Fade to black while particles animate
	await play_fade_transition()
	
	# Cleanup
	particles.queue_free()

func play_zoom_transition() -> void:
	"""Zoom camera into black point"""
	var viewport = get_viewport()
	var camera = viewport.get_camera_3d()
	
	if camera:
		var original_fov = camera.fov
		var tween = create_tween()
		tween.tween_property(camera, "fov", 5.0, transition_duration * 0.7)
		tween.parallel().tween_method(
			func(value): color_rect.modulate.a = value,
			0.0, 1.0, transition_duration * 0.7
		)
		await tween.finished
		
		# Restore FOV for combat scene
		camera.fov = original_fov
	else:
		# Fallback to fade if no camera
		await play_fade_transition()

func create_shatter_particles(texture: Texture2D) -> GPUParticles2D:
	"""Create particle effect for shatter"""
	var particles = GPUParticles2D.new()
	particles.amount = 50
	particles.lifetime = 1.0
	particles.explosiveness = 1.0
	particles.texture = texture
	
	# Configure material
	var material = ParticleProcessMaterial.new()
	material.gravity = Vector3(0, 980, 0)
	material.initial_velocity_min = 100
	material.initial_velocity_max = 300
	material.angular_velocity_min = -360
	material.angular_velocity_max = 360
	particles.process_material = material
	
	return particles

# === BATTLE ENCOUNTER TEXT ===

func show_encounter_text(enemy_name: String):
	"""Show 'Enemy Appeared!' text during transition"""
	var label = Label.new()
	label.text = "%s appeared!" % enemy_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	
	# Style
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	
	add_child(label)
	
	# Animate
	label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	await tween.finished
	
	label.queue_free()

extends CharacterBody3D

@export_group("Movement")
@export var move_speed := 8.0
@export var acceleration := 20.0
@export var rotation_speed := 12.0
@export var jump_impulse := 12.0

@export var attack_range: float = 3.0
@export var attack_raycast: RayCast3D

var _gravity := -30.0
@export var _current_camera : Camera3D = null   # caméra fixe active

@onready var _skin: SophiaSkin = %SophiaSkin

var _last_input := Vector2.ZERO           # dernier input (WASD)
var _current_move_direction := Vector3.ZERO  # direction monde calculée

func _ready():
	add_to_group("player")
	
	# Restore position after combat
	if GameManager.return_position != Vector3.ZERO:
		global_position = GameManager.return_position
		rotation = GameManager.return_rotation
		GameManager.return_position = Vector3.ZERO  # Clear

func _physics_process(delta: float) -> void:
	if _current_camera == null:
		return

	# --- 1. Lire l'input
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# --- 2. Recalculer la direction seulement si l'input a changé
	if raw_input != _last_input:
		_last_input = raw_input

		if raw_input != Vector2.ZERO:
			# Transformer l’input caméra -> monde
			var forward := _current_camera.global_basis.z
			forward.y = 0
			forward = forward.normalized()

			var right := _current_camera.global_basis.x
			right.y = 0
			right = right.normalized()

			_current_move_direction = (forward * raw_input.y + right * raw_input.x).normalized()
		else:
			_current_move_direction = Vector3.ZERO

	# --- 3. Déplacement
	var y_velocity := velocity.y
	velocity.y = 0
	velocity = velocity.move_toward(_current_move_direction * move_speed, acceleration * delta)
	velocity.y = y_velocity + _gravity * delta
	
		# Saut
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y += jump_impulse

	move_and_slide()

	# --- 4. Rotation du skin
	if _current_move_direction.length() > 0.01:
		var target_rot = atan2(_current_move_direction.x, _current_move_direction.z)
		_skin.rotation.y = lerp_angle(_skin.rotation.y, target_rot, rotation_speed * delta)

	if Input.is_action_just_pressed("jump"):
		_skin.jump()
	elif not is_on_floor() and velocity.y < 0:
		_skin.fall()
	elif is_on_floor():
		var ground_speed := velocity.length()
		if ground_speed > 0.0:
			_skin.move()
		else:
			_skin.idle()
			
	# Attack input
	if Input.is_action_just_pressed("attack"):  # Map this in Input Map
		perform_attack()

func perform_attack():
	"""Attack an enemy in range - triggers combat with advantage"""
	print("Player attacks!")
	
	# Raycast or sphere check for enemies
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = attack_range
	query.shape = sphere
	query.transform = global_transform
	query.collision_mask = 2  # Assuming enemies are on layer 2
	
	var results = space_state.intersect_shape(query)
	
	if results.size() > 0:
		var enemy = results[0].collider
		if enemy.has_method("take_preemptive_hit"):
			enemy.take_preemptive_hit()
	else:
		print("No enemy in range")

func set_active_camera(cam: Camera3D) -> void:
	if _current_camera:
		_current_camera.current = false
	_current_camera = cam
	if _current_camera:
		_current_camera.current = true

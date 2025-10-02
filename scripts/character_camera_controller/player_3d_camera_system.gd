extends CharacterBody3D

@export_group("Movement")
@export var move_speed := 8.0
@export var acceleration := 20.0
@export var rotation_speed := 12.0
@export var jump_impulse := 12.0

var _last_movement_direction := Vector3.BACK 
var _gravity := -30.0
@export var _current_camera : Camera3D = null   # caméra fixe active

@onready var _skin: SophiaSkin = %SophiaSkin

func set_active_camera(cam: Camera3D) -> void:
	# Appelé depuis un trigger pour changer de caméra
	if _current_camera:
		_current_camera.current = false
	_current_camera = cam
	if _current_camera:
		_current_camera.current = true


func _physics_process(delta: float) -> void:
	if _current_camera == null:
		return # pas de caméra active = pas de mouvement

	# Input WASD
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Récupère orientation de la caméra fixe
	var forward := _current_camera.global_basis.z
	forward = forward.normalized()

	var right := _current_camera.global_basis.x
	right = right.normalized()

	# Calcule la direction en monde à partir de l’input
	var move_direction := (forward * raw_input.y + right * raw_input.x).normalized()

	# Gère la vitesse
	var y_velocity := velocity.y
	velocity.y = 0.0
	velocity = velocity.move_toward(move_direction * move_speed, acceleration * delta)
	velocity.y = y_velocity + _gravity * delta

	# Saut
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y += jump_impulse

	move_and_slide()

	# Rotation + animations
	if move_direction.length() > 0.5:
		_last_movement_direction = move_direction
	var target_angle := Vector3.BACK.signed_angle_to(_last_movement_direction, Vector3.UP)
	_skin.global_rotation.y = lerp_angle(_skin.rotation.y, target_angle, rotation_speed * delta)

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

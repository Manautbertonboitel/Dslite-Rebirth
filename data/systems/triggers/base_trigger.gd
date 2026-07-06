extends Area3D

enum trigger_action {DOOR, DIALOG, COMBAT, INTERACT}
@export var selected_trigger_action: trigger_action

@export var prompt_ui: Control
@export var prompt_ui_world_pos: Node3D

var player_in = false
var screen_pos
var camera

@export_group("Door Trigger")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var is_door: bool = false
@export_dir var scene_path
@export var target_spawn_id: String

@export_group("Dialog Trigger")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var is_dialog: bool = false
@export var dialog_resource: Resource

@export_group("Combat Trigger")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var is_combat: bool = false

@export_group("Interact Trigger")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var is_interact: bool = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	camera = get_viewport().get_camera_3d()
	prompt_ui.visible = false

func _on_body_entered(body):
	if body is CharacterBody3D:
		player_in = true
		reposition_prompt_ui()
		prompt_ui.visible = true

func _on_body_exited(body):
	if body is CharacterBody3D:
		player_in = false
		prompt_ui.visible = false

func _process(delta):
	if player_in:
		reposition_prompt_ui()
		
		if Input.is_action_just_pressed("interact"):
			_execute_trigger_action()

func _execute_trigger_action():
	match selected_trigger_action:
		trigger_action.DOOR:
			prompt_ui.visible = false
			GameManager.target_spawn_id = target_spawn_id
			SceneFade.fade_to_scene(scene_path)
		trigger_action.COMBAT:
			print("COMBATTRIGGER ")
		trigger_action.DIALOG:
			prompt_ui.visible = false
			DialogueManager.show_messages(dialog_resource.message_list)

func reposition_prompt_ui():
		screen_pos = camera.unproject_position(prompt_ui_world_pos.global_transform.origin)
		prompt_ui.global_position = screen_pos
		

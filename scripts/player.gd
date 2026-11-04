extends CharacterBody3D

# Полноценный FPS-контроллер с инерцией, фонариком, сканером и взаимодействием

const SoundSynthScript = preload("res://scripts/sound_synth.gd")
const InteractiveObjScript = preload("res://scripts/interactive_object.gd")

const WALK_SPEED: float = 4.8
const SPRINT_SPEED: float = 8.2
const CROUCH_SPEED: float = 2.4
const JUMP_VELOCITY: float = 5.2
const MOUSE_SENSITIVITY: float = 0.0022
const BOB_FREQ: float = 2.4
const BOB_AMP: float = 0.06

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_speed: float = WALK_SPEED
var is_crouching: bool = false
var is_sprinting: bool = false
var bob_timer: float = 0.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var flashlight: SpotLight3D = $CameraPivot/Camera3D/Flashlight
@onready var interact_ray: RayCast3D = $CameraPivot/Camera3D/InteractRay
@onready var sound_synth: Node = $SoundSynth

var flashlight_enabled: bool = true
var scanner_cooldown: float = 0.0
const SCANNER_COOLDOWN_TIME: float = 3.5

@export var prompt_label: Label
@export var battery_bar: ProgressBar
@export var scanner_bar: ProgressBar
@export var note_panel: PanelContainer
@export var note_title_lbl: Label
@export var note_content_lbl: Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if flashlight:
		flashlight.visible = flashlight_enabled
	
	Game.note_opened.connect(_on_note_opened)
	Game.note_closed.connect(_on_note_closed)

func _unhandled_input(event: InputEvent) -> void:
	if Game.is_note_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("pause") or event.is_action_pressed("jump"):
			Game.close_note()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -deg_to_rad(82.0), deg_to_rad(82.0))

	if event.is_action_pressed("flashlight"):
		flashlight_enabled = !flashlight_enabled
		if flashlight:
			flashlight.visible = flashlight_enabled
		if sound_synth and sound_synth.has_method("play_click"):
			sound_synth.play_click()

	if event.is_action_pressed("scan") and scanner_cooldown <= 0.0:
		_trigger_scanner()

	if event.is_action_pressed("interact"):
		if interact_ray and interact_ray.is_colliding():
			var collider = interact_ray.get_collider()
			if collider and collider.has_method("interact"):
				collider.interact()

	if event.is_action_pressed("pause"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Game.is_note_open:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	is_crouching = Input.is_action_pressed("crouch")
	var target_cam_height = 0.9 if is_crouching else 1.65
	camera_pivot.position.y = lerpf(camera_pivot.position.y, target_cam_height, delta * 10.0)

	is_sprinting = Input.is_action_pressed("sprint") and not is_crouching and is_on_floor()

	if is_crouching:
		current_speed = CROUCH_SPEED
	elif is_sprinting:
		current_speed = SPRINT_SPEED
	else:
		current_speed = WALK_SPEED

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction != Vector3.ZERO:
		velocity.x = lerpf(velocity.x, direction.x * current_speed, delta * 8.5)
		velocity.z = lerpf(velocity.z, direction.z * current_speed, delta * 8.5)
		if is_on_floor():
			bob_timer += delta * (BOB_FREQ * 1.5 if is_sprinting else BOB_FREQ)
			var bob_offset = Vector3(cos(bob_timer * 0.5) * BOB_AMP * 0.5, sin(bob_timer) * BOB_AMP, 0)
			camera.position = bob_offset
	else:
		velocity.x = lerpf(velocity.x, 0.0, delta * 10.0)
		velocity.z = lerpf(velocity.z, 0.0, delta * 10.0)
		camera.position = camera.position.lerp(Vector3.ZERO, delta * 6.0)

	move_and_slide()

	if flashlight_enabled and flashlight and flashlight.visible:
		if not Game.use_battery(delta * 1.8):
			flashlight.visible = false
			flashlight_enabled = false

	if scanner_cooldown > 0.0:
		scanner_cooldown = maxf(0.0, scanner_cooldown - delta)
		if scanner_bar:
			scanner_bar.value = 1.0 - (scanner_cooldown / SCANNER_COOLDOWN_TIME)
	elif scanner_bar:
		scanner_bar.value = 1.0

	_update_interact_prompt()

func _update_interact_prompt() -> void:
	if not prompt_label:
		return
	if interact_ray and interact_ray.is_colliding():
		var obj = interact_ray.get_collider()
		if obj and "prompt_text" in obj:
			prompt_label.text = obj.prompt_text
			prompt_label.visible = true
			return
	prompt_label.visible = false

func _trigger_scanner() -> void:
	scanner_cooldown = SCANNER_COOLDOWN_TIME
	if sound_synth and sound_synth.has_method("play_scanner_ping"):
		sound_synth.play_scanner_ping()

	var wave_script = load("res://scripts/scanner_wave.gd")
	if wave_script:
		var wave = MeshInstance3D.new()
		wave.set_script(wave_script)
		get_parent().add_child(wave)
		wave.global_position = global_position

func _on_note_opened(title: String, content: String) -> void:
	if note_panel:
		note_panel.visible = true
		if note_title_lbl:
			note_title_lbl.text = title
		if note_content_lbl:
			note_content_lbl.text = content

func _on_note_closed() -> void:
	if note_panel:
		note_panel.visible = false

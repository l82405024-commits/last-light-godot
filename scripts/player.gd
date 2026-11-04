extends CharacterBody3D

# Полноценный FPS-контроллер с боевой системой: дробовик, зомби, сонар, фонарь

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

# Здоровье игрока
var player_health: float = 100.0
var max_player_health: float = 100.0

# Узлы игрока
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var flashlight: SpotLight3D = $CameraPivot/Camera3D/Flashlight
@onready var interact_ray: RayCast3D = $CameraPivot/Camera3D/InteractRay
@onready var sound_synth: Node = $SoundSynth

# Оружие: Дробовик
var gun_mesh: Node3D = null
var muzzle_flash: OmniLight3D = null
var ammo_in_clip: int = 8
var max_clip: int = 8
var ammo_reserve: int = 32
var is_reloading: bool = false
var can_shoot: bool = true
var shoot_cooldown: float = 0.75
var shoot_timer: float = 0.0

# Фонарик и сканер
var flashlight_enabled: bool = true
var scanner_cooldown: float = 0.0
const SCANNER_COOLDOWN_TIME: float = 3.5

# Ссылки на UI
@export var prompt_label: Label
@export var battery_bar: ProgressBar
@export var scanner_bar: ProgressBar
@export var health_bar: ProgressBar
@export var ammo_label: Label
@export var crosshair_dot: ColorRect
@export var damage_vignette: ColorRect
@export var note_panel: PanelContainer
@export var note_title_lbl: Label
@export var note_content_lbl: Label

var hitmarker_timer: float = 0.0
var damage_flash_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if not camera_pivot:
		camera_pivot = get_node_or_null("CameraPivot")
	if not camera and camera_pivot:
		camera = camera_pivot.get_node_or_null("Camera3D")
	if not flashlight and camera:
		flashlight = camera.get_node_or_null("Flashlight")
	if not interact_ray and camera:
		interact_ray = camera.get_node_or_null("InteractRay")
	if not sound_synth:
		sound_synth = get_node_or_null("SoundSynth")

	if camera and not gun_mesh:
		gun_mesh = camera.get_node_or_null("Shotgun")
		if not gun_mesh:
			gun_mesh = _create_procedural_shotgun()
			camera.add_child(gun_mesh)

	if gun_mesh and not muzzle_flash:
		muzzle_flash = gun_mesh.get_node_or_null("MuzzleFlash")

	if flashlight:
		flashlight.visible = flashlight_enabled
	if muzzle_flash:
		muzzle_flash.visible = false

	# Автоматическая настройка недостающих элементов HUD
	var hud = get_node_or_null("HUD")
	if hud:
		if not crosshair_dot:
			crosshair_dot = hud.get_node_or_null("Crosshair/Dot")

		if not damage_vignette:
			damage_vignette = ColorRect.new()
			damage_vignette.name = "DamageVignette"
			damage_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
			damage_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
			damage_vignette.color = Color(0.9, 0.05, 0.05, 0.0)
			hud.add_child(damage_vignette)
			hud.move_child(damage_vignette, 0)

		if not health_bar:
			var bottom_left = hud.get_node_or_null("BottomLeft")
			if bottom_left:
				var hp_label = Label.new()
				hp_label.text = "СОСТОЯНИЕ ЗДОРОВЬЯ"
				hp_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
				hp_label.add_theme_font_size_override("font_size", 13)
				bottom_left.add_child(hp_label)
				bottom_left.move_child(hp_label, 0)

				health_bar = ProgressBar.new()
				health_bar.custom_minimum_size = Vector2(0, 10)
				health_bar.max_value = 100.0
				health_bar.value = 100.0
				health_bar.show_percentage = true
				bottom_left.add_child(health_bar)
				bottom_left.move_child(health_bar, 1)

		if not ammo_label:
			var top_right = hud.get_node_or_null("TopRight")
			if top_right:
				ammo_label = Label.new()
				ammo_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3, 1.0))
				ammo_label.add_theme_font_size_override("font_size", 16)
				ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				top_right.add_child(ammo_label)

	Game.note_opened.connect(_on_note_opened)
	Game.note_closed.connect(_on_note_closed)
	_update_ammo_ui()

func _create_procedural_shotgun() -> Node3D:
	var gun = Node3D.new()
	gun.name = "Shotgun"
	gun.position = Vector3(0.28, -0.24, -0.42)

	# Ствольная коробка
	var rec_mesh = MeshInstance3D.new()
	var rec_box = BoxMesh.new()
	rec_box.size = Vector3(0.065, 0.08, 0.28)
	rec_mesh.mesh = rec_box
	var rec_mat = StandardMaterial3D.new()
	rec_mat.albedo_color = Color(0.12, 0.13, 0.15)
	rec_mat.metallic = 0.9
	rec_mat.roughness = 0.3
	rec_mesh.material_override = rec_mat
	gun.add_child(rec_mesh)

	# Двойной ствол
	var barrel_mat = StandardMaterial3D.new()
	barrel_mat.albedo_color = Color(0.16, 0.17, 0.18)
	barrel_mat.metallic = 0.95
	barrel_mat.roughness = 0.25

	for offset_x in [-0.016, 0.016]:
		var barrel = MeshInstance3D.new()
		var b_cyl = CylinderMesh.new()
		b_cyl.top_radius = 0.014
		b_cyl.bottom_radius = 0.014
		b_cyl.height = 0.48
		barrel.mesh = b_cyl
		barrel.rotation.x = deg_to_rad(90.0)
		barrel.position = Vector3(offset_x, 0.018, -0.32)
		barrel.material_override = barrel_mat
		gun.add_child(barrel)

	# Деревянный приклад
	var stock = MeshInstance3D.new()
	var s_box = BoxMesh.new()
	s_box.size = Vector3(0.05, 0.11, 0.26)
	stock.mesh = s_box
	var stock_mat = StandardMaterial3D.new()
	stock_mat.albedo_color = Color(0.24, 0.13, 0.07)
	stock_mat.roughness = 0.65
	stock.material_override = stock_mat
	stock.position = Vector3(0.0, -0.06, 0.22)
	stock.rotation.x = deg_to_rad(-16.0)
	gun.add_child(stock)

	# Помпа
	var pump = MeshInstance3D.new()
	var p_box = BoxMesh.new()
	p_box.size = Vector3(0.068, 0.055, 0.16)
	pump.mesh = p_box
	var pump_mat = StandardMaterial3D.new()
	pump_mat.albedo_color = Color(0.08, 0.08, 0.08)
	pump_mat.roughness = 0.9
	pump.material_override = pump_mat
	pump.position = Vector3(0.0, -0.015, -0.22)
	gun.add_child(pump)

	# Вспышка выстрела
	var flash = OmniLight3D.new()
	flash.name = "MuzzleFlash"
	flash.light_color = Color(1.0, 0.72, 0.2)
	flash.light_energy = 5.0
	flash.omni_range = 10.0
	flash.position = Vector3(0.0, 0.02, -0.6)
	flash.visible = false
	gun.add_child(flash)

	return gun

func _unhandled_input(event: InputEvent) -> void:
	if Game.is_note_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("pause") or event.is_action_pressed("jump"):
			Game.close_note()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		if camera_pivot:
			camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
			camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -deg_to_rad(82.0), deg_to_rad(82.0))

	# Стрельба из дробовика (ЛКМ)
	if event.is_action_pressed("shoot") and can_shoot and not is_reloading and shoot_timer <= 0.0:
		_shoot_shotgun()

	# Перезарядка (R)
	if event.is_action_pressed("reload") and not is_reloading and ammo_in_clip < max_clip and ammo_reserve > 0:
		_start_reload()

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

	if shoot_timer > 0.0:
		shoot_timer -= delta

	# Вспышка урона на экране
	if damage_flash_timer > 0.0:
		damage_flash_timer -= delta
		if damage_vignette:
			damage_vignette.color.a = clampf(damage_flash_timer * 1.5, 0.0, 0.55)

	# Хитмаркер перекрестия
	if hitmarker_timer > 0.0:
		hitmarker_timer -= delta
		if hitmarker_timer <= 0.0 and crosshair_dot:
			crosshair_dot.color = Color(1, 1, 1, 0.75)
			crosshair_dot.custom_minimum_size = Vector2(4, 4)

	if Game.is_note_open:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	is_crouching = Input.is_action_pressed("crouch")
	var target_cam_height = 0.9 if is_crouching else 1.65
	if camera_pivot:
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
			if camera:
				camera.position = bob_offset
	else:
		velocity.x = lerpf(velocity.x, 0.0, delta * 10.0)
		velocity.z = lerpf(velocity.z, 0.0, delta * 10.0)
		if camera:
			camera.position = camera.position.lerp(Vector3.ZERO, delta * 6.0)

	move_and_slide()

	# Возврат оружия после отдачи
	if gun_mesh:
		gun_mesh.position = gun_mesh.position.lerp(Vector3(0.28, -0.24, -0.42), delta * 10.0)
		gun_mesh.rotation.x = lerpf(gun_mesh.rotation.x, 0.0, delta * 8.0)

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

func _shoot_shotgun() -> void:
	if ammo_in_clip <= 0:
		_start_reload()
		return

	ammo_in_clip -= 1
	shoot_timer = shoot_cooldown
	_update_ammo_ui()

	# Звук выстрела
	if sound_synth and sound_synth.has_method("play_shotgun_blast"):
		sound_synth.play_shotgun_blast()

	# Визуальная отдача оружия
	if gun_mesh:
		gun_mesh.position.z += 0.14
		gun_mesh.rotation.x += deg_to_rad(14.0)

	# Отдача камеры
	if camera_pivot:
		camera_pivot.rotation.x += deg_to_rad(3.5)

	# Вспышка выстрела
	if muzzle_flash:
		muzzle_flash.visible = true
		get_tree().create_timer(0.06).timeout.connect(func(): muzzle_flash.visible = false)

	# Оповещение всех зомби поблизости (звук выстрела привлекает мутантов)
	get_tree().call_group("zombies", "on_gunshot_heard", global_position, 48.0)

	if not camera:
		return

	# Трассировка 8 дробинок с разбросом
	var space_state = get_world_3d().direct_space_state
	var cam_pos = camera.global_position
	var forward = -camera.global_transform.basis.z

	var pellets = 8
	var hit_any = false

	for i in range(pellets):
		var spread_angle = randf_range(0.0, 0.048)
		var rot_angle = randf() * TAU
		var right = camera.global_transform.basis.x
		var up = camera.global_transform.basis.y
		var spread_vec = (right * cos(rot_angle) + up * sin(rot_angle)) * spread_angle
		var ray_dir = (forward + spread_vec).normalized()

		var query = PhysicsRayQueryParameters3D.create(cam_pos, cam_pos + ray_dir * 55.0)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.collision_mask = 5 # Игровое окружение и зомби

		var result = space_state.intersect_ray(query)
		if result:
			var collider = result.collider
			if collider and collider.is_in_group("zombies") and collider.has_method("take_damage"):
				collider.take_damage(18.0, result.position, result.normal)
				hit_any = true

	# Индикация попадания (Хитмаркер)
	if hit_any:
		hitmarker_timer = 0.18
		if crosshair_dot:
			crosshair_dot.color = Color(1.0, 0.25, 0.25, 1.0)
			crosshair_dot.custom_minimum_size = Vector2(8, 8)
		if sound_synth and sound_synth.has_method("play_zombie_hit"):
			sound_synth.play_zombie_hit()

func _start_reload() -> void:
	if is_reloading or ammo_reserve <= 0 or ammo_in_clip == max_clip:
		return
	is_reloading = true
	if sound_synth and sound_synth.has_method("play_reload"):
		sound_synth.play_reload()

	if ammo_label:
		ammo_label.text = "ПЕРЕЗАРЯДКА..."

	# Анимация покачивания оружия при перезарядке
	if gun_mesh:
		var tw = create_tween()
		tw.tween_property(gun_mesh, "position:y", -0.4, 0.3)
		tw.tween_interval(0.6)
		tw.tween_property(gun_mesh, "position:y", -0.24, 0.3)

	await get_tree().create_timer(1.2).timeout
	var needed = max_clip - ammo_in_clip
	var to_load = mini(needed, ammo_reserve)
	ammo_in_clip += to_load
	ammo_reserve -= to_load
	is_reloading = false
	_update_ammo_ui()

func _update_ammo_ui() -> void:
	if ammo_label:
		ammo_label.text = "ДРОБОВИК: %d / %d" % [ammo_in_clip, ammo_reserve]

func take_damage(amount: float) -> void:
	player_health = maxf(0.0, player_health - amount)
	damage_flash_timer = 0.35
	if health_bar:
		health_bar.value = player_health

	# Если здоровье на нуле — плавная перезагрузка на стартовую позицию
	if player_health <= 0.0:
		global_position = Vector3(0, 2.0, 0)
		player_health = max_player_health
		if health_bar:
			health_bar.value = player_health

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

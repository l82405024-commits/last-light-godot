extends CharacterBody3D

# Зомби-мутант с конечным автоматом (FSM), светящимися глазами и реакцией на выстрелы

enum State { IDLE, WANDER, CHASE, ATTACK, DEAD }

@export var max_health: float = 100.0
@export var walk_speed: float = 2.2
@export var run_speed: float = 5.2
@export var attack_damage: float = 22.0
@export var attack_range: float = 2.2
@export var detection_range: float = 26.0

var current_health: float = 100.0
var current_state: State = State.IDLE
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var target_player: Node3D = null
var attack_cooldown: float = 0.0
var wander_timer: float = 0.0
var wander_dir: Vector3 = Vector3.ZERO
var flash_timer: float = 0.0
var step_bob: float = 0.0

@onready var visual_root: Node3D = $Visuals
@onready var eyes_mesh: MeshInstance3D = $Visuals/Eyes
@onready var body_mesh: MeshInstance3D = $Visuals/Body

var default_body_mat: StandardMaterial3D
var hit_flash_mat: StandardMaterial3D

func _ready() -> void:
	add_to_group("zombies")
	current_health = max_health

	# Материалы
	default_body_mat = StandardMaterial3D.new()
	default_body_mat.albedo_color = Color(0.24, 0.28, 0.26) # Трупно-пепельный оттенок
	default_body_mat.roughness = 0.85
	if body_mesh:
		body_mesh.material_override = default_body_mat

	hit_flash_mat = StandardMaterial3D.new()
	hit_flash_mat.albedo_color = Color(0.9, 0.2, 0.2)
	hit_flash_mat.emission_enabled = true
	hit_flash_mat.emission = Color(1.0, 0.3, 0.3)

	# Находим игрока
	target_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if current_state == State.DEAD:
		move_and_slide()
		return

	# Таймер вспышки при попадании
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0 and body_mesh:
			body_mesh.material_override = default_body_mat

	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	# Поиск игрока если ещё не найден
	if not target_player:
		target_player = get_tree().get_first_node_in_group("player")

	var dist_to_player = 999.0
	if target_player:
		dist_to_player = global_position.distance_to(target_player.global_position)

	# Переходы между состояниями
	match current_state:
		State.IDLE, State.WANDER:
			if dist_to_player <= detection_range:
				_set_state(State.CHASE)
			else:
				_handle_wander(delta)

		State.CHASE:
			if dist_to_player <= attack_range:
				_set_state(State.ATTACK)
			elif dist_to_player > detection_range * 1.5:
				_set_state(State.IDLE)
			else:
				_handle_chase(delta)

		State.ATTACK:
			if dist_to_player > attack_range:
				_set_state(State.CHASE)
			else:
				_handle_attack(delta)

	move_and_slide()

func _handle_wander(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.0, 5.0)
		if randf() > 0.4:
			var angle = randf() * TAU
			wander_dir = Vector3(cos(angle), 0, sin(angle)).normalized()
			current_state = State.WANDER
		else:
			wander_dir = Vector3.ZERO
			current_state = State.IDLE

	if wander_dir != Vector3.ZERO:
		velocity.x = wander_dir.x * walk_speed
		velocity.z = wander_dir.z * walk_speed
		var look_target = global_position + wander_dir
		look_at(Vector3(look_target.x, global_position.y, look_target.z), Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0, delta * 4.0)
		velocity.z = move_toward(velocity.z, 0, delta * 4.0)

func _handle_chase(delta: float) -> void:
	if not target_player:
		return

	var dir = (target_player.global_position - global_position)
	dir.y = 0
	dir = dir.normalized()

	velocity.x = dir.x * run_speed
	velocity.z = dir.z * run_speed

	var look_target = target_player.global_position
	look_at(Vector3(look_target.x, global_position.y, look_target.z), Vector3.UP)

	# Анимация пошатывания при беге
	step_bob += delta * 10.0
	if visual_root:
		visual_root.rotation.z = sin(step_bob) * 0.08
		visual_root.rotation.x = 0.15 + cos(step_bob * 2.0) * 0.05

func _handle_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, delta * 8.0)
	velocity.z = move_toward(velocity.z, 0, delta * 8.0)

	if target_player:
		var look_target = target_player.global_position
		look_at(Vector3(look_target.x, global_position.y, look_target.z), Vector3.UP)

	if attack_cooldown <= 0.0:
		attack_cooldown = 1.3
		if target_player and target_player.has_method("take_damage"):
			target_player.take_damage(attack_damage)
			# Выпад визуальной модели
			if visual_root:
				visual_root.position.z = 0.4
				var tween = create_tween()
				tween.tween_property(visual_root, "position:z", 0.0, 0.4)

func take_damage(amount: float, _hit_point: Vector3, hit_normal: Vector3) -> void:
	if current_state == State.DEAD:
		return

	current_health -= amount
	flash_timer = 0.12
	if body_mesh:
		body_mesh.material_override = hit_flash_mat

	# Отталкивающий импульс назад от выстрела
	velocity += -hit_normal * 4.5
	velocity.y += 1.5

	# Мгновенно агримся на игрока
	_set_state(State.CHASE)

	if current_health <= 0.0:
		_die()

func on_gunshot_heard(origin: Vector3, alert_radius: float) -> void:
	if current_state == State.DEAD:
		return
	if global_position.distance_to(origin) <= alert_radius:
		_set_state(State.CHASE)

func _set_state(new_state: State) -> void:
	current_state = new_state
	if new_state == State.CHASE:
		var synth = get_tree().get_first_node_in_group("sound_synth")
		if synth and synth.has_method("play_zombie_groan") and randf() > 0.6:
			synth.play_zombie_groan()

func _die() -> void:
	current_state = State.DEAD
	collision_layer = 0
	collision_mask = 1 # Только коллизия с землей

	# Падение тела
	if visual_root:
		var tween = create_tween()
		tween.tween_property(visual_root, "rotation:x", -deg_to_rad(85.0), 0.35).set_trans(Tween.TRANS_BOUNCE)

	# Выключаем светящиеся глаза
	if eyes_mesh:
		eyes_mesh.visible = false

	# Исчезновение трупа через 8 секунд
	var fade_tween = create_tween()
	fade_tween.tween_interval(6.0)
	fade_tween.tween_callback(queue_free)

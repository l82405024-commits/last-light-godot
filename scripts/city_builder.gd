extends Node3D

# Процедурный генератор заброшенного мегаполиса:
# Небоскребы, разрушенные эстакады, заросшие дворы, генераторы и записки выживших

const InteractiveObjScript = preload("res://scripts/interactive_object.gd")

@export var city_grid_size: int = 6 # 6x6 кварталов
@export var block_size: float = 24.0 # Размер одного городского квартала
@export var street_width: float = 8.0 # Ширина проспектов

var building_shader: Shader
var ground_shader: Shader
var grass_shader: Shader
var neon_shader: Shader

func _ready() -> void:
	building_shader = load("res://shaders/building.gdshader")
	ground_shader = load("res://shaders/ground.gdshader")
	grass_shader = load("res://shaders/grass.gdshader")
	neon_shader = load("res://shaders/neon.gdshader")

	_build_ground()
	_generate_city_blocks()
	_spawn_landmarks_and_lore()

func _build_ground() -> void:
	# Главная плоскость земли с шейдером потрескавшегося асфальта и луж
	var plane_mesh = PlaneMesh.new()
	var total_size = float(city_grid_size) * (block_size + street_width) + 60.0
	plane_mesh.size = Vector2(total_size, total_size)
	plane_mesh.subdivide_width = 30
	plane_mesh.subdivide_depth = 30

	var ground_inst = MeshInstance3D.new()
	ground_inst.mesh = plane_mesh
	
	if ground_shader:
		var mat = ShaderMaterial.new()
		mat.shader = ground_shader
		ground_inst.material_override = mat

	# Статическое тело для коллизии с землей
	var static_body = StaticBody3D.new()
	var col_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(total_size, 1.0, total_size)
	col_shape.shape = box
	col_shape.position.y = -0.5
	static_body.add_child(col_shape)
	ground_inst.add_child(static_body)

	add_child(ground_inst)

func _generate_city_blocks() -> void:
	var offset = (float(city_grid_size) * (block_size + street_width)) * 0.5

	for gx in range(city_grid_size):
		for gz in range(city_grid_size):
			var bx = float(gx) * (block_size + street_width) - offset + block_size * 0.5
			var bz = float(gz) * (block_size + street_width) - offset + block_size * 0.5

			# В центральном квартале оставляем площадь для старта игрока
			if gx == city_grid_size / 2 and gz == city_grid_size / 2:
				_build_central_plaza(Vector3(bx, 0, bz))
				continue

			_build_block(Vector3(bx, 0, bz), (gx * 37 + gz * 19))

func _build_block(pos: Vector3, seed_val: int) -> void:
	var block_node = Node3D.new()
	block_node.position = pos
	add_child(block_node)

	# Случайная конфигурация: 1 мега-небоскреб или 4 средних здания
	var r = (seed_val % 10) / 10.0
	if r > 0.45:
		var height = 35.0 + float(seed_val % 40)
		_create_building(block_node, Vector3.ZERO, Vector3(block_size * 0.85, height, block_size * 0.85), float(seed_val))
	else:
		var sub_w = block_size * 0.4
		var h1 = 20.0 + float((seed_val * 7) % 30)
		var h2 = 25.0 + float((seed_val * 13) % 25)
		_create_building(block_node, Vector3(-sub_w * 0.5, 0, -sub_w * 0.5), Vector3(sub_w, h1, sub_w), float(seed_val + 1))
		_create_building(block_node, Vector3(sub_w * 0.5, 0, sub_w * 0.5), Vector3(sub_w, h2, sub_w), float(seed_val + 2))

	_create_street_prop(pos + Vector3(block_size * 0.5 + 2.0, 0, block_size * 0.5 + 2.0))

func _create_building(parent: Node, local_pos: Vector3, size: Vector3, seed_f: float) -> void:
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.position = local_pos + Vector3(0, size.y * 0.5, 0)

	if building_shader:
		var mat = ShaderMaterial.new()
		mat.shader = building_shader
		mat.set_shader_parameter("seed", seed_f)
		mat.set_shader_parameter("ruin", 0.4)
		mesh_inst.material_override = mat

	var static_body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	static_body.add_child(col)
	mesh_inst.add_child(static_body)

	parent.add_child(mesh_inst)

func _build_central_plaza(pos: Vector3) -> void:
	var plaza = Node3D.new()
	plaza.position = pos
	add_child(plaza)

	var base_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(8.0, 1.2, 8.0)
	base_mesh.mesh = box
	base_mesh.position.y = 0.6
	plaza.add_child(base_mesh)

	var col_mesh = MeshInstance3D.new()
	var c_box = BoxMesh.new()
	c_box.size = Vector3(1.8, 11.0, 1.8)
	col_mesh.mesh = c_box
	col_mesh.position = Vector3(0, 5.0, 0)
	col_mesh.rotation = Vector3(0.12, 0.4, 0.18)
	plaza.add_child(col_mesh)

	_create_interactive_note(
		pos + Vector3(2.5, 1.5, 0.5),
		"Дневник выжившего: Запись #1",
		"Город опустел за считанные часы. Туман пришел с залива и заглушил все частоты.\nЧтобы включить эвакуационную антенну, нужно восстановить 3 генератора в кварталах вокруг площади. Нажми [Q] для сканирования местности."
	)

func _spawn_landmarks_and_lore() -> void:
	_create_interactive_generator(Vector3(34.0, 0.0, 12.0), 1)
	_create_interactive_note(
		Vector3(32.0, 1.0, 14.0),
		"Запись инженера: Генератор 'Альфа'",
		"Турбина в порядке, но предохранитель выбило. Если замкнуть цепь, этот сектор снова оживет светом."
	)

	_create_interactive_generator(Vector3(-12.0, 0.0, 48.0), 2)
	_create_interactive_note(
		Vector3(-10.0, 1.0, 46.0),
		"Запись исследователя: Аномальный туман",
		"Этот туман не рассеивается ветром. Но когда загорается яркий свет подстанций, мгла отступает."
	)

	_create_interactive_generator(Vector3(-45.0, 0.0, -25.0), 3)
	_create_interactive_note(
		Vector3(-43.0, 1.0, -23.0),
		"Финальное сообщение: Сигнал SOS",
		"Все три подстанции соединены в единую сеть. Как только будет запущен последний сектор, сияние города пробьет пелену на многие километры."
	)

func _create_interactive_note(pos: Vector3, title: String, text: String) -> void:
	var note_area = Area3D.new()
	note_area.set_script(InteractiveObjScript)
	note_area.set("object_type", 0) # NOTE
	note_area.set("note_title", title)
	note_area.set("note_text", text)
	note_area.set("prompt_text", "[E] Прочитать записку")
	note_area.position = pos

	var m = MeshInstance3D.new()
	var b = BoxMesh.new()
	b.size = Vector3(0.5, 0.1, 0.7)
	m.mesh = b
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.85, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.35, 0.15)
	m.material_override = mat
	note_area.add_child(m)

	var col = CollisionShape3D.new()
	var s = BoxShape3D.new()
	s.size = Vector3(1.6, 1.6, 1.6)
	col.shape = s
	note_area.add_child(col)

	add_child(note_area)

func _create_interactive_generator(pos: Vector3, id: int) -> void:
	var gen_node = Node3D.new()
	gen_node.position = pos

	var body_mesh = MeshInstance3D.new()
	var b = BoxMesh.new()
	b.size = Vector3(2.5, 3.2, 2.5)
	body_mesh.mesh = b
	body_mesh.position.y = 1.6
	
	var gen_mat = StandardMaterial3D.new()
	gen_mat.albedo_color = Color(0.18, 0.22, 0.25)
	gen_mat.metallic = 0.8
	gen_mat.roughness = 0.35
	body_mesh.material_override = gen_mat
	gen_node.add_child(body_mesh)

	var area = Area3D.new()
	area.set_script(InteractiveObjScript)
	area.set("object_type", 1) # GENERATOR
	area.set("generator_id", id)
	area.set("prompt_text", "[E] Запустить генератор #" + str(id))
	area.position.y = 1.6

	var col = CollisionShape3D.new()
	var s = BoxShape3D.new()
	s.size = Vector3(3.5, 3.5, 3.5)
	col.shape = s
	area.add_child(col)
	gen_node.add_child(area)

	var sb = StaticBody3D.new()
	var col_sb = CollisionShape3D.new()
	var s_sb = BoxShape3D.new()
	s_sb.size = Vector3(2.5, 3.2, 2.5)
	col_sb.shape = s_sb
	col_sb.position.y = 1.6
	sb.add_child(col_sb)
	gen_node.add_child(sb)

	add_child(gen_node)

func _create_street_prop(pos: Vector3) -> void:
	var pole = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.15
	cyl.height = 6.0
	pole.mesh = cyl
	pole.position = pos + Vector3(0, 3.0, 0)
	
	var pole_mat = StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.2, 0.2, 0.22)
	pole_mat.metallic = 0.9
	pole.material_override = pole_mat
	add_child(pole)

extends MeshInstance3D
class_name ScannerWave

# Визуальная волна сканера окружения: сферический импульс с френелевским свечением

var max_radius: float = 45.0
var current_radius: float = 0.5
var speed: float = 32.0
var lifetime: float = 1.6
var time_alive: float = 0.0
var mat: ShaderMaterial

func _ready() -> void:
	mesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	var shader = load("res://shaders/scan_wave.gdshader")
	if shader:
		mat = ShaderMaterial.new()
		mat.shader = shader
		material_override = mat

func _process(delta: float) -> void:
	time_alive += delta
	current_radius += speed * delta
	scale = Vector3.ONE * current_radius
	
	if mat:
		var alpha = clampf(1.0 - (time_alive / lifetime), 0.0, 1.0)
		mat.set_shader_parameter("alpha", alpha)
	
	if time_alive >= lifetime or current_radius >= max_radius:
		queue_free()

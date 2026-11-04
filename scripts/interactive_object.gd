extends Area3D
class_name InteractiveObject

# Базовый класс интерактивных объектов: Записки, Генераторы, Терминалы

enum Type { NOTE, GENERATOR, TERMINAL }

@export var object_type: Type = Type.NOTE
@export var prompt_text: String = "[E] Взаимодействовать"
@export var note_title: String = "Забытый дневник"
@export_multiline var note_text: String = "Мы думали, что туман рассеется к утру. Но он остался навсегда... Если кто-то читает это, ищите генераторы на крышах."
@export var generator_id: int = 1

var is_activated: bool = false
var highlight_mesh: MeshInstance3D

func _ready() -> void:
	collision_layer = 2 # Слой взаимодействия
	collision_mask = 0

func interact() -> void:
	match object_type:
		Type.NOTE:
			Game.read_note(note_title, note_text)
		Type.GENERATOR:
			if not is_activated:
				is_activated = true
				prompt_text = "[Активирован]"
				Game.activate_generator(generator_id)
				_trigger_generator_visuals()

func _trigger_generator_visuals() -> void:
	# При активации генератора включается мягкий свет и неоновое сияние
	var light = OmniLight3D.new()
	light.light_color = Color(0.2, 0.9, 0.5)
	light.light_energy = 3.5
	light.omni_range = 14.0
	add_child(light)

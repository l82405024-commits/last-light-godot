extends Node

# Autoload: Game
# Менеджер игрового состояния, аккумулятора, дневников и питания города

signal note_opened(title: String, content: String)
signal note_closed
signal power_restored(generator_index: int, total: int)
signal battery_changed(current: float, max_val: float)
signal toast(text: String)

var battery_energy: float = 100.0
var max_battery: float = 100.0
var generators_active: int = 0
var total_generators: int = 3
var is_note_open: bool = false
var notes_found: Array[String] = []

func _process(delta: float) -> void:
	if battery_energy < max_battery:
		battery_energy = min(max_battery, battery_energy + delta * 2.5)
		battery_changed.emit(battery_energy, max_battery)

func use_battery(amount: float) -> bool:
	if battery_energy >= amount:
		battery_energy = max(0.0, battery_energy - amount)
		battery_changed.emit(battery_energy, max_battery)
		return true
	return false

func activate_generator(index: int) -> void:
	generators_active = clampi(generators_active + 1, 0, total_generators)
	power_restored.emit(generators_active, total_generators)

func read_note(title: String, content: String) -> void:
	is_note_open = true
	if not notes_found.has(title):
		notes_found.append(title)
	note_opened.emit(title, content)

func close_note() -> void:
	is_note_open = false
	note_closed.emit()

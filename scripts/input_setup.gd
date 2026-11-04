extends Node

# Autoload: GameInput
# Настройка управления по умолчанию, если действия отсутствуют в InputMap

func _ready() -> void:
	_ensure_action("move_forward", [KEY_W, KEY_UP])
	_ensure_action("move_backward", [KEY_S, KEY_DOWN])
	_ensure_action("move_left", [KEY_A, KEY_LEFT])
	_ensure_action("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action("jump", [KEY_SPACE])
	_ensure_action("sprint", [KEY_SHIFT])
	_ensure_action("crouch", [KEY_CTRL, KEY_C])
	_ensure_action("flashlight", [KEY_F])
	_ensure_action("scan", [KEY_Q])
	_ensure_action("interact", [KEY_E])
	_ensure_action("toggle_fullscreen", [KEY_F11])
	_ensure_action("pause", [KEY_ESCAPE])

func _ensure_action(action_name: StringName, default_keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		for k in default_keys:
			var event = InputEventKey.new()
			event.physical_keycode = k
			InputMap.action_add_event(action_name, event)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

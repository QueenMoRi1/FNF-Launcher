class_name InputSetup
extends RefCounted
## Keyboard + controller bindings, applied once at startup (intro and menu).
## Controller events use device -1 so any controller works: handhelds like the
## ROG Ally don't always show up as controller #0.

static var _done := false


static func apply() -> void:
	if _done:
		return
	_done = true
	# Godot's built-in accept/cancel are keyboard-only.
	_bind_button("ui_accept", JOY_BUTTON_A)
	_bind_button("ui_cancel", JOY_BUTTON_B)
	_add("edit", KEY_F2, JOY_BUTTON_Y)
	_add("rescan", KEY_F5, JOY_BUTTON_X)
	_add("friends", KEY_F3, JOY_BUTTON_START)
	_add("download", KEY_F4, JOY_BUTTON_RIGHT_STICK)
	_add("music_pause", KEY_SPACE, JOY_BUTTON_BACK)
	_add("music_prev", KEY_Q, JOY_BUTTON_LEFT_SHOULDER)
	_add("music_next", KEY_W, JOY_BUTTON_RIGHT_SHOULDER)
	# Space pauses music instead of launching the selected game.
	for event in InputMap.action_get_events("ui_accept"):
		if event is InputEventKey and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE):
			InputMap.action_erase_event("ui_accept", event)


static func _add(action: String, key: Key, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var k := InputEventKey.new()
	k.physical_keycode = key
	InputMap.action_add_event(action, k)
	_bind_button(action, button)


static func _bind_button(action: String, button: JoyButton) -> void:
	var j := InputEventJoypadButton.new()
	j.button_index = button
	j.device = -1 # any controller
	InputMap.action_add_event(action, j)

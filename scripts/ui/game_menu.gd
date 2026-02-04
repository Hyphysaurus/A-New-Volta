extends Control
class_name GameMenu

## ESC = Pause/Resume. Shows tutorial on first launch.
## Pause menu: Resume, Reset to Harbor, Quit.
## Tutorial: control instructions, auto-shows once, press any key to dismiss.

signal reset_requested
signal quit_requested

var _paused: bool = false
var _tutorial_shown: bool = false
var _tutorial_active: bool = true  ## Start with tutorial visible

# UI nodes
var _pause_panel: Panel
var _tutorial_panel: Panel
var _dim: ColorRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS  ## Works even when tree is paused
	_build_dim()
	_build_tutorial()
	_build_pause_menu()
	# Show tutorial on start
	_show_tutorial()

func _unhandled_input(event: InputEvent) -> void:
	# Dismiss tutorial on any key/button press
	if _tutorial_active:
		if (event is InputEventKey and event.pressed) or \
		   (event is InputEventJoypadButton and event.pressed) or \
		   (event is InputEventMouseButton and event.pressed):
			_hide_tutorial()
			get_viewport().set_input_as_handled()
			return

	# ESC or Start button = toggle pause
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_toggle_pause()
			get_viewport().set_input_as_handled()
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			_toggle_pause()
			get_viewport().set_input_as_handled()

# ── Dim overlay ──────────────────────────────────────────────────────────
func _build_dim() -> void:
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	add_child(_dim)

# ── Tutorial ─────────────────────────────────────────────────────────────
func _build_tutorial() -> void:
	_tutorial_panel = Panel.new()
	_tutorial_panel.name = "TutorialPanel"

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.04, 0.08, 0.94)
	style.border_color = Color(0.35, 0.55, 0.7, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 32
	style.content_margin_bottom = 28
	_tutorial_panel.add_theme_stylebox_override("panel", style)

	_tutorial_panel.set_anchors_preset(Control.PRESET_CENTER)
	_tutorial_panel.size = Vector2(460, 420)
	_tutorial_panel.position = Vector2(-230, -210)
	_tutorial_panel.visible = false
	_tutorial_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_tutorial_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 40; vbox.offset_right = -40
	vbox.offset_top = 32; vbox.offset_bottom = -28
	vbox.add_theme_constant_override("separation", 4)
	_tutorial_panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "VOLTA DO MARE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	vbox.add_child(title)

	# Subtitle
	var sub := Label.new()
	sub.text = "Sail the open seas"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
	vbox.add_child(sub)

	_add_spacer(vbox, 10)

	# Controls — clean two-column style
	var controls_text := "W  /  Left Stick        Sail forward
S  /  Left Stick        Brake (close sail)
A  D  /  Left Stick     Steer

Q  E  /  Right Stick    Orbit camera
Scroll  /  Right Stick  Zoom in/out
Right-click drag        Free look

F  /  Y Button          Dock or anchor
ESC  /  Start           Pause menu"

	var controls := Label.new()
	controls.text = controls_text
	controls.add_theme_font_size_override("font_size", 14)
	controls.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95))
	vbox.add_child(controls)

	_add_spacer(vbox, 10)

	# Tips
	var tips_label := Label.new()
	tips_label.text = "Wind fills your sails — crosswinds are fastest.
The compass shows wind (blue) and heading (gold).
Brake near islands for control. Dock at ports with F.
Days pass automatically. Press SPACE to skip ahead."
	tips_label.add_theme_font_size_override("font_size", 13)
	tips_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.85))
	tips_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(tips_label)

	_add_spacer(vbox, 14)

	# Dismiss
	var dismiss := Label.new()
	dismiss.text = "Press any key to sail"
	dismiss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dismiss.add_theme_font_size_override("font_size", 18)
	dismiss.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	vbox.add_child(dismiss)

# ── Pause menu ───────────────────────────────────────────────────────────
func _build_pause_menu() -> void:
	_pause_panel = Panel.new()
	_pause_panel.name = "PausePanel"

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.1, 0.92)
	style.border_color = Color(0.3, 0.55, 0.7, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	_pause_panel.add_theme_stylebox_override("panel", style)

	_pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_panel.size = Vector2(320, 280)
	_pause_panel.position = Vector2(-160, -140)
	_pause_panel.visible = false
	_pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pause_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 30; vbox.offset_right = -30
	vbox.offset_top = 24; vbox.offset_bottom = -24
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	vbox.add_child(title)

	_add_spacer(vbox, 8)

	# Resume button
	var resume_btn := _make_button("Resume")
	resume_btn.pressed.connect(_toggle_pause)
	vbox.add_child(resume_btn)

	# Show Controls button
	var controls_btn := _make_button("Show Controls")
	controls_btn.pressed.connect(func():
		_hide_pause()
		_show_tutorial()
	)
	vbox.add_child(controls_btn)

	# Reset button
	var reset_btn := _make_button("Reset to Harbor")
	reset_btn.pressed.connect(_do_reset)
	vbox.add_child(reset_btn)

	# Quit button
	var quit_btn := _make_button("Quit Game")
	quit_btn.pressed.connect(_do_quit)
	vbox.add_child(quit_btn)

func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(220, 38)
	btn.add_theme_font_size_override("font_size", 17)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.18, 0.28, 0.9)
	normal.border_color = Color(0.3, 0.5, 0.65, 0.6)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.15, 0.28, 0.42, 0.95)
	hover.border_color = Color(0.4, 0.65, 0.85, 0.8)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(6)
	hover.content_margin_left = 12
	hover.content_margin_right = 12
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.08, 0.15, 0.22, 0.95)
	pressed.border_color = Color(0.5, 0.7, 0.9, 0.9)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(6)
	pressed.content_margin_left = 12
	pressed.content_margin_right = 12
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	return btn

func _add_spacer(parent: Control, h: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, h)
	parent.add_child(spacer)

# ── State management ─────────────────────────────────────────────────────
func _toggle_pause() -> void:
	if _tutorial_active:
		return
	_paused = not _paused
	if _paused:
		_show_pause()
	else:
		_hide_pause()

func _show_pause() -> void:
	_paused = true
	get_tree().paused = true
	_dim.visible = true
	_pause_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _hide_pause() -> void:
	_paused = false
	get_tree().paused = false
	_dim.visible = false
	_pause_panel.visible = false

func _show_tutorial() -> void:
	_tutorial_active = true
	get_tree().paused = true
	_dim.visible = true
	_tutorial_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _hide_tutorial() -> void:
	_tutorial_active = false
	_tutorial_shown = true
	get_tree().paused = false
	_dim.visible = false
	_tutorial_panel.visible = false

func _do_reset() -> void:
	_hide_pause()
	# Find boat and reset it
	var boat = get_tree().get_first_node_in_group("boat")
	if boat and boat.has_method("_teleport_to_harbor"):
		# Unfreeze in case docked
		boat.freeze = false
		boat.linear_velocity = Vector3.ZERO
		boat.angular_velocity = Vector3.ZERO
		boat._teleport_to_harbor()
		boat._is_capsized = false
		boat.visible = true
		boat.sail_open = true
	# Reset docking state
	var dock_sys = get_node_or_null("/root/World/DockingSystem") as DockingSystem
	if dock_sys:
		dock_sys.state = DockingSystem.State.SAILING
		dock_sys._active_dock = {}
		dock_sys.prompt_changed.emit("")
		dock_sys.dock_state_changed.emit("sailing")
	reset_requested.emit()

func _do_quit() -> void:
	_hide_pause()
	get_tree().quit()

func is_paused() -> bool:
	return _paused

func is_tutorial_active() -> bool:
	return _tutorial_active

extends Control
class_name SailingHUD

## Bottom-left sailing HUD — stats on the left, compass to the right.
## No overlap. Context prompts center-bottom.

@export var show_compass: bool = true
@export var compass_size: float = 60.0

var _boat: Node3D
var _wind_system: WindSystem
var _docking_system: DockingSystem
var _prompt_text: String = ""

# UI elements
var _panel: Panel
var _speed_label: Label
var _wind_label: Label
var _sail_label: Label
var _heading_label: Label
var _status_label: Label
var _prompt_label: Label
var _compass_display: Control
var _day_label: Label
var _time_system: Node
var _region_system: Node
var _region_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_find_systems()
	_build_hud()

func _find_systems() -> void:
	await get_tree().process_frame
	_boat = get_tree().get_first_node_in_group("boat")
	if not _boat:
		_boat = get_node_or_null("/root/World/Boat")
	_wind_system = get_node_or_null("/root/World/WindSystem") as WindSystem
	_docking_system = get_node_or_null("/root/World/DockingSystem") as DockingSystem
	_time_system = get_node_or_null("/root/World/TimeSystem")
	_region_system = get_node_or_null("/root/World/RegionSystem")
	if _docking_system:
		_docking_system.prompt_changed.connect(_on_prompt_changed)

func _build_hud() -> void:
	# ── HBox container at bottom-left: [Stats Panel] [Compass] ──
	var hbox := HBoxContainer.new()
	hbox.name = "HUDRow"
	hbox.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hbox.position = Vector2(8, -148)
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)

	# ── Stats panel (left side) ──
	_panel = Panel.new()
	_panel.name = "InfoPanel"
	_panel.custom_minimum_size = Vector2(260, 155)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.08, 0.88)
	style.border_color = Color(0.35, 0.55, 0.7, 0.85)
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.corner_radius_top_right = 10
	style.corner_radius_top_left = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 4
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	vbox.offset_left = 16; vbox.offset_right = -16
	vbox.offset_top = 12; vbox.offset_bottom = -12
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vbox)

	_speed_label = _make_label("SPEED: 0.0 kn", 19, Color(0.95, 0.98, 1.0))
	vbox.add_child(_speed_label)
	_heading_label = _make_label("HDG: N 000°", 16, Color(0.75, 0.88, 0.98))
	vbox.add_child(_heading_label)
	_wind_label = _make_label("WIND: 0.0 kn @ 000°", 15, Color(0.55, 0.82, 1.0))
	vbox.add_child(_wind_label)
	_sail_label = _make_label("SAIL: OPEN  eff 100%", 15, Color(0.45, 0.92, 0.5))
	vbox.add_child(_sail_label)
	_status_label = _make_label("", 15, Color(0.98, 0.88, 0.45))
	_status_label.visible = false
	vbox.add_child(_status_label)

	# ── Day counter (top-right) with background ──
	var day_panel := Panel.new()
	day_panel.name = "DayPanel"
	day_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	day_panel.position = Vector2(-240, 8)
	day_panel.size = Vector2(230, 85) # Increased height slightly
	var day_style := StyleBoxFlat.new()
	day_style.bg_color = Color(0.02, 0.04, 0.08, 0.85)
	day_style.border_color = Color(0.35, 0.55, 0.7, 0.8)
	day_style.border_width_top = 2
	day_style.border_width_right = 2
	day_style.border_width_bottom = 2
	day_style.border_width_left = 2
	day_style.corner_radius_top_right = 10
	day_style.corner_radius_top_left = 10
	day_style.corner_radius_bottom_right = 10
	day_style.corner_radius_bottom_left = 10
	day_panel.add_theme_stylebox_override("panel", day_style)
	day_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(day_panel)
	
	var day_vbox := VBoxContainer.new()
	day_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	day_vbox.offset_top = 4; day_vbox.offset_bottom = -4
	day_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	day_panel.add_child(day_vbox)

	_day_label = Label.new()
	_day_label.name = "DayLabel"
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_label.add_theme_font_size_override("font_size", 18)
	_day_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	_day_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_label.text = "Day 1 / 28\nCalm Winds"
	day_vbox.add_child(_day_label)

	# ── Region indicator (automatically stacked below) ──
	_region_label = Label.new()
	_region_label.name = "RegionLabel"
	_region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_label.add_theme_font_size_override("font_size", 14)
	_region_label.add_theme_color_override("font_color", Color(0.65, 0.8, 0.9))
	_region_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_region_label.text = "📍 Inner Sea"
	day_vbox.add_child(_region_label)

	# ── Mini compass (right side of the HBox) ──
	if show_compass:
		_compass_display = _MiniCompass.new()
		_compass_display.name = "MiniCompass"
		_compass_display.custom_minimum_size = Vector2(compass_size * 2.4, compass_size * 2.4)
		_compass_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(_compass_display)

	# ── Center-bottom prompt ──
	_prompt_label = Label.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.position = Vector2(-200, -70)
	_prompt_label.size = Vector2(400, 50)
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label.text = ""
	add_child(_prompt_label)

func _make_label(default_text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = default_text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

func _process(_dt: float) -> void:
	if not _boat:
		_find_systems()
		return
	_update_labels()
	if _compass_display and _compass_display is _MiniCompass:
		var mc := _compass_display as _MiniCompass
		mc.boat = _boat
		mc.wind_system = _wind_system

func _update_labels() -> void:
	if not _boat or not _boat is Boat:
		return
	var boat: Boat = _boat as Boat

	var fwd_speed: float = boat.get_forward_speed()
	var knots: float = abs(fwd_speed) * 1.94
	_speed_label.text = "SPEED: %.1f kn" % knots
	if knots > 15:
		_speed_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	elif knots > 5:
		_speed_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	else:
		_speed_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))

	var heading_deg: float = boat.get_heading()
	if heading_deg < 0:
		heading_deg += 360.0
	_heading_label.text = "HDG: %s %03d°" % [_deg_to_cardinal(heading_deg), int(heading_deg)]

	if _wind_system:
		var wd: Dictionary = _wind_system.get_wind_data()
		var wind_knots: float = wd.strength * 1.94
		var wind_deg: float = wd.angle_degrees
		if wind_deg < 0:
			wind_deg += 360.0
		_wind_label.text = "WIND: %.1f kn @ %03d°" % [wind_knots, int(wind_deg)]

	var move_name: String = boat.get_move_state_name()
	var eff_pct: int = int(boat.sail_efficiency * 100)

	if move_name == "Sailing":
		_sail_label.text = "⛵ SAILING  wind %d%%" % eff_pct
		if boat.sail_efficiency > 0.7:
			_sail_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.4))
		elif boat.sail_efficiency > 0.35:
			_sail_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.3))
		else:
			_sail_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.3))
	elif move_name == "Braking":
		_sail_label.text = "⚓ BRAKING"
		_sail_label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.3))
	else:
		_sail_label.text = "[W] to raise sail"
		_sail_label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))

	if _docking_system:
		var ds_state: String = _docking_system.get_state_name()
		if ds_state != "Sailing":
			_status_label.text = "⚓ %s" % ds_state
			_status_label.visible = true
		else:
			_status_label.visible = false

	_prompt_label.text = _prompt_text
	_prompt_label.visible = _prompt_text != ""

	# Day counter
	if _time_system and _day_label:
		_day_label.text = "%s\n%s" % [_time_system.get_day_string(), _time_system.get_week_name()]
		# Color shifts as cataclysm approaches
		var intensity: float = _time_system.cataclysm_intensity
		if intensity > 0.5:
			_day_label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.3))
		elif intensity > 0.01:
			_day_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.4))
		else:
			_day_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))

	# Region indicator
	if _region_system and _region_label:
		_region_label.text = "📍 " + _region_system.get_region_name()

func _on_prompt_changed(text: String) -> void:
	_prompt_text = text

func _deg_to_cardinal(deg: float) -> String:
	var dirs := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var idx: int = int(round(deg / 45.0)) % 8
	return dirs[idx]

# ═══════════════════════════════════════════════════════════════════════
# Mini compass — drawn to the right of the stats with improved visibility
# ═══════════════════════════════════════════════════════════════════════
class _MiniCompass extends Control:
	var boat: Node3D
	var wind_system: WindSystem
	var radius: float = 55.0

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var center := Vector2(size.x * 0.5, size.y * 0.5)
		var r: float = minf(size.x, size.y) * 0.40

		# Background — darker for contrast
		draw_circle(center, r + 5, Color(0.02, 0.04, 0.08, 0.92))
		draw_arc(center, r + 5, 0, TAU, 48, Color(0.35, 0.55, 0.7, 0.8), 2.5)
		draw_circle(center, r * 0.12, Color(0.4, 0.45, 0.5, 0.6))

		# Inner rings
		draw_arc(center, r * 0.5, 0, TAU, 24, Color(0.25, 0.3, 0.35, 0.3), 1.0)
		draw_arc(center, r * 0.75, 0, TAU, 32, Color(0.2, 0.25, 0.3, 0.2), 1.0)

		# Tick marks
		var font := ThemeDB.fallback_font
		for i in range(8):
			var angle: float = float(i) / 8.0 * TAU - PI * 0.5
			var dir: Vector2 = Vector2(cos(angle), sin(angle))
			var inner_p: Vector2 = center + dir * (r * 0.78)
			var outer_p: Vector2 = center + dir * (r * 0.95)
			var col: Color
			if i == 0:
				col = Color(1.0, 0.35, 0.3, 1.0)  # North = bright red
			elif i % 2 == 0:
				col = Color(0.75, 0.8, 0.85, 0.9)
			else:
				col = Color(0.55, 0.6, 0.65, 0.6)
			var line_w: float = 2.5 if i % 2 == 0 else 1.5
			draw_line(inner_p, outer_p, col, line_w)

		# Cardinals — larger, brighter
		var labels: Array[String] = ["N", "E", "S", "W"]
		for i in range(4):
			var angle: float = float(i) / 4.0 * TAU - PI * 0.5
			var dir: Vector2 = Vector2(cos(angle), sin(angle))
			var pos: Vector2 = center + dir * (r + 14) - Vector2(5, -5)
			var col: Color
			if i == 0:
				col = Color(1.0, 0.4, 0.35)  # North = red
			else:
				col = Color(0.8, 0.85, 0.9)
			draw_string(font, pos, labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)

		# Wind arrow — thicker, brighter blue
		if wind_system:
			var w3: Vector3 = wind_system.wind_direction
			var wa: float = atan2(w3.x, -w3.z)
			var wd: Vector2 = Vector2(sin(wa), -cos(wa))
			var wt: Vector2 = center + wd * (r * 0.7)
			var wb: Vector2 = center + wd * 10.0
			draw_line(wb, wt, Color(0.3, 0.65, 1.0, 0.95), 3.5)
			var wp: Vector2 = Vector2(-wd.y, wd.x)
			draw_colored_polygon(PackedVector2Array([wt, wt - wd * 11 + wp * 5.5, wt - wd * 11 - wp * 5.5]),
				Color(0.3, 0.65, 1.0, 1.0))

		# Boat heading — bright gold arrow
		if boat:
			var fwd: Vector3 = -boat.global_transform.basis.z
			var ba: float = atan2(fwd.x, -fwd.z)
			var bd: Vector2 = Vector2(sin(ba), -cos(ba))
			var bt: Vector2 = center + bd * (r * 0.42)
			var bp: Vector2 = Vector2(-bd.y, bd.x)
			draw_colored_polygon(PackedVector2Array([bt, bt - bd * 8 + bp * 4, bt - bd * 8 - bp * 4]),
				Color(0.95, 0.85, 0.3))
			draw_polyline(PackedVector2Array([bt, bt - bd * 8 + bp * 4, bt - bd * 8 - bp * 4, bt]),
				Color(1, 1, 1, 0.5), 1.0)

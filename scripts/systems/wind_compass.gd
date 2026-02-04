extends Control
class_name WindCompass

## HUD compass showing wind direction relative to the boat, plus sail efficiency.
## Positioned top-right by default. Shows:
##   - Compass rose with N/S/E/W
##   - Blue arrow = wind direction (world space)
##   - Small boat icon = your heading
##   - Efficiency arc colored green→yellow→red
##   - Numeric wind strength bar

@export var compass_radius: float = 70.0
@export var wind_system_path: NodePath

var wind_system: WindSystem
var _boat: Node3D

var wind_direction: Vector3 = Vector3.FORWARD
var wind_strength: float = 1.0
var wind_alignment: float = 0.0
var sail_efficiency: float = 0.0

func _ready() -> void:
	# Anchor top-right with some margin
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(-compass_radius * 2.6, 10)
	custom_minimum_size = Vector2(compass_radius * 2.6, compass_radius * 2.8)
	size = custom_minimum_size

	# Find systems
	if wind_system_path:
		wind_system = get_node_or_null(wind_system_path) as WindSystem
	if not wind_system:
		wind_system = get_node_or_null("/root/World/WindSystem") as WindSystem
	if wind_system:
		wind_system.wind_changed.connect(_on_wind_changed)

	# Find boat
	var world = get_tree().get_root().get_node_or_null("World")
	if world:
		_boat = world.get_node_or_null("Boat")

func _process(_delta: float) -> void:
	if _boat and _boat is Boat:
		var b: Boat = _boat as Boat
		wind_alignment = b.wind_alignment
		sail_efficiency = b.sail_efficiency
	queue_redraw()

func _is_sail_open() -> bool:
	if _boat and _boat is Boat:
		return (_boat as Boat).is_sail_open()
	return true

func _on_wind_changed(dir: Vector3, strength: float) -> void:
	wind_direction = dir
	wind_strength = strength

func _draw() -> void:
	var center := Vector2(compass_radius + 10, compass_radius + 10)
	var r := compass_radius

	# ── Background ──
	draw_circle(center, r + 4, Color(0.05, 0.08, 0.12, 0.85))
	draw_arc(center, r + 4, 0, TAU, 48, Color(0.3, 0.4, 0.5, 0.6), 2.0)

	# ── Efficiency arc (outer ring) ──
	_draw_efficiency_arc(center, r)

	# ── Compass grid rings ──
	for i in range(1, 4):
		draw_arc(center, r * (float(i) / 3.0), 0, TAU, 32, Color(0.2, 0.25, 0.3, 0.25), 1.0)

	# ── Cardinal markers ──
	_draw_cardinals(center, r)

	# ── Wind arrow ──
	_draw_wind_arrow(center, r)

	# ── Boat heading indicator ──
	_draw_boat_heading(center, r)

	# ── Strength bar below compass ──
	_draw_strength_bar(center, r)

	# ── Sail state text ──
	var font := ThemeDB.fallback_font
	var sail_state: String = "OPEN" if _is_sail_open() else "CLOSED"
	var eff_text := "Sail: %s %d%%" % [sail_state, int(sail_efficiency * 100)]
	var eff_color := _efficiency_color(sail_efficiency) if _is_sail_open() else Color(0.6, 0.6, 0.6)
	draw_string(font, center + Vector2(-38, r + 38), eff_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, eff_color)

func _draw_efficiency_arc(center: Vector2, r: float) -> void:
	# Draw a colored arc segment showing efficiency: green = good, red = bad
	var segments: int = 32
	var arc_width: float = 5.0
	var arc_r: float = r + 9

	for i in range(segments):
		var t: float = float(i) / float(segments)
		var angle: float = t * TAU
		var next_angle: float = float(i + 1) / float(segments) * TAU

		# Color based on what efficiency would be at this heading relative to wind
		var sim_alignment: float = cos(angle)
		var sim_eff: float = 0.0
		if sim_alignment >= 0.0:
			sim_eff = 1.0 - 0.6 * (sim_alignment - 0.5) * (sim_alignment - 0.5)
			sim_eff = clamp(sim_eff, 0.4, 1.0)
		else:
			sim_eff = clamp((1.0 + sim_alignment) * 0.5, 0.0, 0.5)
			sim_eff *= sim_eff

		var color := _efficiency_color(sim_eff)
		color.a = 0.4
		draw_arc(center, arc_r, angle, next_angle, 2, color, arc_width)

func _draw_cardinals(center: Vector2, r: float) -> void:
	var font := ThemeDB.fallback_font
	var fs: int = 14
	var offset: float = r + 18
	var labels := {"N": Vector2(0, -1), "S": Vector2(0, 1), "E": Vector2(1, 0), "W": Vector2(-1, 0)}

	for label in labels:
		var dir: Vector2 = labels[label]
		var pos: Vector2 = center + dir * offset
		# Center the text roughly
		pos.x -= 5
		pos.y += 5
		var col := Color.WHITE if label == "N" else Color(0.6, 0.65, 0.7)
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _draw_wind_arrow(center: Vector2, r: float) -> void:
	# Convert 3D wind direction to 2D angle (Godot: -Z = forward/north)
	var angle: float = atan2(wind_direction.x, -wind_direction.z)
	var dir := Vector2(sin(angle), -cos(angle))

	var arrow_len: float = r * 0.65
	var tip: Vector2 = center + dir * arrow_len
	var base: Vector2 = center + dir * 12.0
	var perp := Vector2(-dir.y, dir.x)

	# Shaft
	draw_line(base, tip - dir * 12, Color(0.35, 0.7, 1.0, 0.9), 3.0)

	# Arrow head
	var head := PackedVector2Array([
		tip,
		tip - dir * 14 + perp * 7,
		tip - dir * 14 - perp * 7,
	])
	draw_colored_polygon(head, Color(0.35, 0.7, 1.0, 0.95))

	# "W" label at the tip
	var font := ThemeDB.fallback_font
	draw_string(font, tip + dir * 10 - Vector2(4, -4), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.8, 1.0))

func _draw_boat_heading(center: Vector2, r: float) -> void:
	if not _boat:
		return

	var forward: Vector3 = -_boat.global_transform.basis.z
	var angle: float = atan2(forward.x, -forward.z)
	var dir := Vector2(sin(angle), -cos(angle))

	# Small triangle representing the boat
	var tip: Vector2 = center + dir * (r * 0.45)
	var perp := Vector2(-dir.y, dir.x)
	var boat_tri := PackedVector2Array([
		tip,
		tip - dir * 10 + perp * 5,
		tip - dir * 10 - perp * 5,
	])

	var eff_col := _efficiency_color(sail_efficiency)
	draw_colored_polygon(boat_tri, eff_col)
	# Outline
	draw_polyline(PackedVector2Array([boat_tri[0], boat_tri[1], boat_tri[2], boat_tri[0]]), Color.WHITE, 1.5)

func _draw_strength_bar(center: Vector2, r: float) -> void:
	var bar_w: float = r * 1.4
	var bar_h: float = 8.0
	var bar_pos := Vector2(center.x - bar_w * 0.5, center.y + r + 20)

	# Background
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.15, 0.15, 0.2, 0.7))

	# Fill
	var max_str: float = 5.5
	var fill: float = clamp(wind_strength / max_str, 0, 1)
	draw_rect(Rect2(bar_pos, Vector2(bar_w * fill, bar_h)), Color(0.35, 0.7, 1.0, 0.8))

	# Border
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.4, 0.5, 0.6, 0.5), false, 1.0)

	# Label
	var font := ThemeDB.fallback_font
	draw_string(font, bar_pos + Vector2(0, -3), "Wind: %.1f" % wind_strength, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.8, 0.9))

func _efficiency_color(eff: float) -> Color:
	if eff > 0.7:
		return Color(0.2, 0.9, 0.3)   # Green — great angle
	elif eff > 0.35:
		return Color(0.9, 0.85, 0.2)  # Yellow — ok angle
	else:
		return Color(0.9, 0.25, 0.2)  # Red — bad angle / in irons

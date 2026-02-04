extends Node3D
class_name WindSystem

## Wind simulation with regional variation and cycle-driven weather.
##
## Wind shifts direction every few minutes. Different map zones have
## distinctly different wind angles so players can tack around the map.
## The 28-day cycle makes weather increasingly chaotic as cataclysm nears.

# ── Tuning ──────────────────────────────────────────────────────────────────
@export_group("Wind Behavior")
@export var base_strength: float = 2.8
@export var max_strength: float = 5.0
@export var gust_cycle_speed: float = 0.35
@export var gust_amplitude: float = 0.9

@export_group("Direction Shifts")
@export var shift_interval_min: float = 90.0   ## Seconds between major shifts
@export var shift_interval_max: float = 240.0  ## Wider range = less predictable
@export var shift_speed: float = 0.5           ## How fast the shift happens (rad/s)

@export_group("Regional Variation")
@export var zone_rotation: float = 0.6         ## Max radians offset per zone

@export_group("Visualization")
@export var show_particles: bool = true
@export var show_wind_lines: bool = true
@export var particle_count: int = 80
@export var wind_line_count: int = 24

# ── Runtime state ───────────────────────────────────────────────────────────
var wind_angle: float = 0.0
var wind_direction: Vector3 = Vector3.FORWARD
var wind_strength: float = 2.8

## Target angle for smooth directional shifts
var _target_angle: float = 0.0
var _next_shift_time: float = 0.0
var _gust_phase: float = 0.0

## Cycle-driven modifiers (set by TimeSystem connection)
var _cycle_storm_mult: float = 1.0   ## 1.0 = calm, up to 2.0 near cataclysm
var _cycle_shift_mult: float = 1.0   ## Shifts happen faster near cataclysm

# Visualization nodes
var _particles: GPUParticles3D
var _wind_lines_container: Node3D
var _wind_line_meshes: Array[MeshInstance3D] = []
var _boat: Node3D

signal wind_changed(direction: Vector3, strength: float)

# ── Lifecycle ───────────────────────────────────────────────────────────────
func _ready() -> void:
    # Start with Prevailing Wind (from NE = 225 degrees = 5PI/4)
	wind_angle = 5.0 * PI / 4.0 
	_target_angle = wind_angle
	wind_direction = Vector3(sin(wind_angle), 0.0, cos(wind_angle))
	wind_strength = base_strength
	_schedule_next_shift()

	_boat = _find_boat()

	if show_particles:
		_setup_particles()
	if show_wind_lines:
		_setup_wind_lines()

	# Connect to TimeSystem for cycle-driven weather
	_connect_time_system()

	print("🌬️ WindSystem ready — angle %.0f°, strength %.1f" % [rad_to_deg(wind_angle), wind_strength])

func _process(delta: float) -> void:
	_update_wind(delta)
	_update_particles(delta)
	_update_wind_lines(delta)
	wind_changed.emit(wind_direction, wind_strength)

# ── Wind simulation ────────────────────────────────────────────────────────
func _update_wind(delta: float) -> void:
	var now: float = Time.get_ticks_msec() * 0.001

	# Major direction shift — smooth rotation to new target
	if now > _next_shift_time:
		_pick_new_direction()
		_schedule_next_shift()

	# Smooth rotation toward target angle
	var angle_diff: float = _target_angle - wind_angle
	# Wrap to [-PI, PI]
	while angle_diff > PI: angle_diff -= TAU
	while angle_diff < -PI: angle_diff += TAU
	wind_angle += angle_diff * shift_speed * delta
	wind_direction = Vector3(sin(wind_angle), 0.0, cos(wind_angle))

	# Gust layer — oscillation + storm multiplier
	_gust_phase += delta * gust_cycle_speed * _cycle_storm_mult
	var gust: float = sin(_gust_phase) * 0.5 + sin(_gust_phase * 1.8 + 1.3) * 0.3 + sin(_gust_phase * 3.1 + 0.7) * 0.2
	var effective_max: float = max_strength * _cycle_storm_mult
	wind_strength = clampf(base_strength + gust * gust_amplitude * _cycle_storm_mult, base_strength * 0.3, effective_max)

func _pick_new_direction() -> void:
    # Bias towards Prevailing Wind (from NE = 225 deg)
	var prevailing_angle: float = 5.0 * PI / 4.0
	
	# Random variance, but weighted to stay within +/- 90 degrees of prevailing often
	var variance: float = randf_range(-PI * 0.6, PI * 0.6) 
	
	# Occasionally (20%) allow full random shift for storms/chaos
	if randf() < 0.2:
		variance = randf_range(-PI, PI)
		
	_target_angle = prevailing_angle + variance
	print("🌬️ Wind shifting to %.0f° (prevailing NE)" % rad_to_deg(_target_angle))

func _schedule_next_shift() -> void:
	var interval: float = randf_range(shift_interval_min, shift_interval_max)
	interval /= _cycle_shift_mult  # More frequent near cataclysm
	_next_shift_time = Time.get_ticks_msec() * 0.001 + interval

# ── Cycle connection ────────────────────────────────────────────────────────
func _connect_time_system() -> void:
	var ts = get_node_or_null("../TimeSystem")
	if not ts:
		ts = get_node_or_null("/root/World/TimeSystem")
	if ts and ts.has_signal("day_advanced"):
		ts.day_advanced.connect(_on_day_advanced)
		ts.cataclysm_building.connect(_on_cataclysm_building)
		# Set initial state
		_on_day_advanced(ts.cycle_day, ts.cycle_count)

func _on_day_advanced(cycle_day: int, _cycle_count: int) -> void:
	# Weather gets wilder in the last week
	if cycle_day <= 14:
		_cycle_storm_mult = 1.0
		_cycle_shift_mult = 1.0
	elif cycle_day <= 21:
		_cycle_storm_mult = 1.2
		_cycle_shift_mult = 1.3
	else:
		# Days 22-28: escalating storms
		var progress: float = float(cycle_day - 21) / 7.0
		_cycle_storm_mult = 1.2 + progress * 0.8  # Up to 2.0
		_cycle_shift_mult = 1.3 + progress * 0.7  # Up to 2.0

func _on_cataclysm_building(intensity: float) -> void:
	# Direct intensity override for the final days
	if intensity > 0.01:
		_cycle_storm_mult = 1.5 + intensity * 1.0
		_cycle_shift_mult = 1.5 + intensity * 1.0

# ── Particles ───────────────────────────────────────────────────────────────
func _setup_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "WindStreamers"
	_particles.emitting = true
	_particles.amount = particle_count
	_particles.lifetime = 2.5
	_particles.explosiveness = 0.0
	_particles.randomness = 0.3
	_particles.visibility_aabb = AABB(Vector3(-60, -5, -60), Vector3(120, 15, 120))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(35, 2, 35)
	pm.direction = Vector3.FORWARD
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 14.0
	pm.gravity = Vector3(0, -0.3, 0)
	pm.damping_min = 0.5
	pm.damping_max = 1.0
	pm.scale_min = 0.08
	pm.scale_max = 0.25
	pm.color = Color(1, 1, 1, 0.35)
	_particles.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.15)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.95, 1.0, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mat
	_particles.draw_pass_1 = quad

	add_child(_particles)

func _update_particles(_delta: float) -> void:
	if not _particles:
		return
	if _boat and is_instance_valid(_boat):
		_particles.global_position = _boat.global_position + Vector3(0, 3, 0)
	var pm: ParticleProcessMaterial = _particles.process_material as ParticleProcessMaterial
	if pm:
		pm.direction = wind_direction
		var vel: float = 6.0 + wind_strength * 3.0
		pm.initial_velocity_min = vel * 0.7
		pm.initial_velocity_max = vel * 1.3

# ── Wind lines ──────────────────────────────────────────────────────────────
func _setup_wind_lines() -> void:
	_wind_lines_container = Node3D.new()
	_wind_lines_container.name = "WindLines"
	add_child(_wind_lines_container)

	for i in range(wind_line_count):
		var line_mesh := MeshInstance3D.new()
		var im := ImmediateMesh.new()
		line_mesh.mesh = im
		line_mesh.name = "WL_%d" % i

		var wl_mat := StandardMaterial3D.new()
		wl_mat.albedo_color = Color(0.85, 0.92, 1.0, 0.0)
		wl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wl_mat.no_depth_test = true
		line_mesh.material_override = wl_mat

		_wind_lines_container.add_child(line_mesh)
		_wind_line_meshes.append(line_mesh)

func _update_wind_lines(_delta: float) -> void:
	if not show_wind_lines or _wind_line_meshes.is_empty():
		return

	var time: float = Time.get_ticks_msec() * 0.001
	var boat_pos := Vector3.ZERO
	if _boat:
		boat_pos = _boat.global_position

	for i in range(_wind_line_meshes.size()):
		var line_mesh: MeshInstance3D = _wind_line_meshes[i]
		var im: ImmediateMesh = line_mesh.mesh as ImmediateMesh
		if not im:
			continue
		im.clear_surfaces()

		var phase: float = float(i) / float(wind_line_count)
		var life: float = fmod(time * 0.4 + phase, 1.0)

		var perp: Vector3 = Vector3(-wind_direction.z, 0, wind_direction.x)
		var spread_along: float = (phase - 0.5) * 80.0
		var spread_perp: float = sin(phase * 17.3 + 3.1) * 40.0

		var origin: Vector3 = boat_pos + perp * spread_perp + wind_direction * (spread_along - 40.0 * life)
		origin.y = 0.35

		var seg_count: int = 6
		var seg_len: float = (1.5 + wind_strength * 0.5)

		var alpha: float = sin(life * PI) * 0.35 * clampf(wind_strength / base_strength, 0.3, 1.0)
		var wl_mat: StandardMaterial3D = line_mesh.material_override as StandardMaterial3D
		if wl_mat:
			wl_mat.albedo_color.a = alpha

		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for s in range(seg_count + 1):
			var t: float = float(s) / float(seg_count)
			var wave: float = sin(t * PI * 2.0 + time * 3.0 + phase * 10.0) * 0.15
			var pt: Vector3 = origin + wind_direction * (t * seg_len * seg_count) + perp * wave
			im.surface_add_vertex(pt)
		im.surface_end()

# ── Public API ──────────────────────────────────────────────────────────────

## Returns wind at a specific position — regional zones have offset angles.
func get_wind_force_at(pos: Vector3) -> Vector3:
	var local_angle: float = _get_local_angle(pos)
	var local_dir := Vector3(sin(local_angle), 0, cos(local_angle))
	return local_dir * wind_strength

func get_wind_data() -> Dictionary:
	return {
		"direction": wind_direction,
		"strength": wind_strength,
		"angle_degrees": rad_to_deg(atan2(wind_direction.x, wind_direction.z)),
		"normalized_strength": wind_strength / max_strength,
	}

func get_wind_data_at(pos: Vector3) -> Dictionary:
	var local_angle: float = _get_local_angle(pos)
	var local_dir := Vector3(sin(local_angle), 0, cos(local_angle))
	return {
		"direction": local_dir,
		"strength": wind_strength,
		"angle_degrees": rad_to_deg(atan2(local_dir.x, local_dir.z)),
		"normalized_strength": wind_strength / max_strength,
	}

func get_alignment(boat_forward: Vector3) -> float:
	return boat_forward.dot(wind_direction)

## Returns the current storm intensity (0-1) for other systems to read.
func get_storm_intensity() -> float:
	return clampf((_cycle_storm_mult - 1.0) / 1.0, 0.0, 1.0)

# ── Helpers ─────────────────────────────────────────────────────────────────
func _get_local_angle(pos: Vector3) -> float:
	# Four-quadrant wind zones: each quarter of the map has a distinct offset
	# This creates natural tacking routes — you can always find favorable wind
	var zone_x: float = sin(pos.x * 0.005 + 1.0) * zone_rotation
	var zone_z: float = cos(pos.z * 0.004 + 0.5) * zone_rotation * 0.8
	# Cross term for diagonal variation
	var cross: float = sin((pos.x + pos.z) * 0.003) * zone_rotation * 0.4
	return wind_angle + zone_x + zone_z + cross

func _find_boat() -> Node3D:
	var world := get_parent()
	if world:
		var boat := world.get_node_or_null("Boat")
		if boat:
			return boat
	return null

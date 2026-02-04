extends RigidBody3D
class_name Boat

## The Crimson Spirit / Shining Quetzal — Flagship of the Volta do Mar.
## Normalized for HEROIC scale (6.0x Boat, 1.2x Mariner).
## No hidden state. No competing forces. Just go where you point.

# ── Spawn ───────────────────────────────────────────────────────────────────
const HARBOR_SPAWN := Vector3(250, 2.0, 0)  ## Spawn just above water level
const HARBOR_HEADING := -105.0
const TOON_MAT = preload("res://assets/materials/toon_material.tres")

@export_group("Wind System")
@export var wind_system_path: NodePath
@export var current_system_path: NodePath

@export_group("Movement")
@export var thrust_force: float = 4000.0         ## Boosted for 6x ship
@export var wind_bonus_force: float = 1800.0    ## Stronger wind influence
@export var max_speed: float = 55.0             ## Higher top speed for scale
@export var cruise_speed: float = 30.0 

@export_group("Steering")
@export var turn_torque: float = 6500.0         ## Snappy steering for 6x hull
@export var turn_damping: float = 22.0         
@export var stationary_turn: float = 0.9

@export_group("Braking")
@export var brake_force: float = 800.0
@export var coast_drag: float = 0.4             ## Gentle drag when coasting (no W/S)

@export_group("Drag")
@export var lateral_drag: float = 15.0          ## Prevents sliding
@export var angular_drag: float = 6.0           ## Stops spinning quickly

@export_group("Ocean & Buoyancy")
@export var target_height: float = 1.2          ## Slightly higher flotation
@export var buoyancy_stiffness: float = 800.0   ## Tighter for mass 80
@export var buoyancy_damping: float = 110.0     
@export var wave_amplitude: float = 0.6
@export var wave_length: float = 0.035
@export var wave_speed: float = 0.8
@export var wave_secondary_amp: float = 0.3
@export var wave_secondary_len: float = 0.05
@export var wave_bob_strength: float = 15.0     
@export var stabilization_torque: float = 850.0 

@export_group("Capsize")
@export var capsize_tilt_degrees: float = 85.0
@export var capsize_depth: float = -4.0
@export var capsize_respawn_delay: float = 1.5

@export_group("Pilot Setup")
@export var pilot_offset := Vector3(0.0, 0.45, -2.8) # Feet on deck at 6.0x scale

# ── API for HUD ─────────────────────────────────────────────────────────────
func get_forward_speed() -> float:
	return linear_velocity.dot(-global_transform.basis.z)

func get_heading() -> float:
	var angle := -atan2(global_transform.basis.z.x, -global_transform.basis.z.z)
	return wrapf(rad_to_deg(angle), 0, 360)

func get_move_state_name() -> String:
	match move_state:
		MoveState.SAILING: return "Sailing"
		MoveState.BRAKING: return "Braking"
		_: return "Idle"

# ── Runtime state ───────────────────────────────────────────────────────────
var wind_system: WindSystem
var current_system: CurrentSystem
var current_speed: float = 0.0
var wind_alignment: float = 0.0
var sail_efficiency: float = 0.0
var wind_force_debug: Vector3 = Vector3.ZERO

var sail_open: bool = true
var _sail_close_lerp: float = 0.0

enum MoveState { IDLE, SAILING, BRAKING }
var move_state: int = MoveState.IDLE

var _is_capsized: bool = false
var _capsize_timer: float = 0.0
var _spawn_grace: float = 0.0

var _last_collision_time: float = 0.0

var sail_pivot: Node3D
var sail_mesh: Node3D
var rudder_mesh: Node3D

# ── Init ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("boat")
	_force_physics_settings()
	_build_visuals()
	_teleport_to_harbor()

	if wind_system_path:
		wind_system = get_node_or_null(wind_system_path) as WindSystem
	if not wind_system:
		wind_system = get_node_or_null("/root/World/WindSystem") as WindSystem
	
	if current_system_path:
		current_system = get_node_or_null(current_system_path) as CurrentSystem
	if not current_system:
		current_system = get_node_or_null("/root/World/CurrentSystem") as CurrentSystem

	body_entered.connect(_on_body_entered)
	_setup_wake()

func _setup_wake() -> void:
	# Wake Particles (Trail)
	var wake := GPUParticles3D.new()
	wake.name = "WakeParticles"
	wake.amount = 200
	wake.lifetime = 4.0
	wake.local_coords = false 
	wake.position = Vector3(0, 0, 3.5) 
	
	var proc := ParticleProcessMaterial.new()
	proc.direction = Vector3(0, 0, 1) 
	proc.spread = 15.0
	proc.initial_velocity_min = 2.0
	proc.initial_velocity_max = 5.0
	proc.gravity = Vector3(0, 0, 0)
	proc.scale_min = 0.15 # Normalized scale
	proc.scale_max = 0.45 
	proc.color = Color(1, 1, 1, 0.6)
	
	var curv := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 0.5))
	c.add_point(Vector2(1, 0.0))
	curv.curve = c
	proc.alpha_curve = curv
		
	wake.process_material = proc
	
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.5, 1.5)
	mesh.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.9, 0.95, 1.0, 0.5)
	mesh.material = mat
	wake.draw_pass_1 = mesh
	add_child(wake)
	
	# Bow Splash (Foam)
	var splash := GPUParticles3D.new()
	splash.name = "BowSplash"
	splash.amount = 60
	splash.lifetime = 0.8
	splash.local_coords = true
	splash.position = Vector3(0, 1.0, -3.2) 
	
	var sproc := ParticleProcessMaterial.new()
	sproc.direction = Vector3(0, 1, -1) 
	sproc.spread = 40.0
	sproc.initial_velocity_min = 3.0
	sproc.initial_velocity_max = 6.0
	sproc.scale_min = 0.1
	sproc.scale_max = 0.3
	sproc.gravity = Vector3(0, -9, 0)
	splash.process_material = sproc
	
	var smesh := BoxMesh.new()
	smesh.size = Vector3(0.3, 0.3, 0.3)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1, 1, 1, 0.8)
	smesh.material = smat
	splash.draw_pass_1 = smesh
	add_child(splash)


func _force_physics_settings() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = false
	lock_rotation = false
	mass = 80.0 
	gravity_scale = 1.0
	sleeping = false
	can_sleep = false

func _physics_process(dt: float) -> void:
	if Engine.get_physics_frames() < 10:
		_force_physics_settings()
	if sleeping:
		sleeping = false

	if _is_capsized:
		_capsize_timer -= dt
		if _capsize_timer <= 0:
			_respawn_at_harbor()
		return

	var state_manager = get_tree().get_first_node_in_group("state_manager") as StateManager
	if state_manager and state_manager.current_state != StateManager.State.SAILING and state_manager.current_state != StateManager.State.DOCKING:
		_update_visuals(dt)
		return

	var throttle: float = _get_throttle()
	var braking: bool = _get_braking()
	var turn_input: float = _get_steering()

	if braking:
		move_state = MoveState.BRAKING
		sail_open = false
	elif throttle > 0.01:
		move_state = MoveState.SAILING
		sail_open = true
	else:
		move_state = MoveState.IDLE

	_update_wind_efficiency()

	var boat_fwd: Vector3 = -global_transform.basis.z
	var boat_right: Vector3 = global_transform.basis.x
	
	var vel_mag = linear_velocity.length()
	if vel_mag > 0.01:
		var drag_coeff = coast_drag
		if move_state == MoveState.BRAKING: drag_coeff = 2.0
		apply_central_force(-linear_velocity * drag_coeff * 5.0)

	if throttle > 0.01 and not braking:
		var push = thrust_force * throttle
		if wind_system:
			var bonus = wind_bonus_force * sail_efficiency * throttle
			bonus *= wind_system.wind_strength / 2.8 
			push += bonus
		apply_central_force(boat_fwd * push)

	elif braking:
		if linear_velocity.dot(boat_fwd) > 0.1:
			apply_central_force(-boat_fwd * brake_force * 3.0)

	if abs(turn_input) > 0.01:
		var steer_power = turn_torque * (stationary_turn + clampf(vel_mag / 10.0, 0.0, 1.0))
		apply_torque(Vector3.UP * turn_input * steer_power)
	
	apply_torque(-angular_velocity * turn_damping) 

	var lat_speed = linear_velocity.dot(boat_right)
	apply_central_force(-boat_right * lat_speed * lateral_drag * 2.0)

	_apply_ocean_buoyancy(dt)

	if _spawn_grace > 0.0:
		_spawn_grace -= dt
	else:
		_check_capsize()

	current_speed = linear_velocity.length()
	if current_speed > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed

	_update_visuals(dt)

	if global_position.length() > 4500 or global_position.y > 60:
		_trigger_capsize()

func _get_throttle() -> float:
	var t: float = 0.0
	if Input.is_action_pressed("move_forward"):
		t = 1.0
	var joy_y: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if joy_y < -0.2:
		t = maxf(t, -joy_y)
	return clampf(t, 0.0, 1.0)

func _get_braking() -> bool:
	if Input.is_action_pressed("move_backward"):
		return true
	var joy_y: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	return joy_y > 0.4

func _get_steering() -> float:
	var s: float = 0.0
	if Input.is_action_pressed("move_left"):
		s -= 1.0
	if Input.is_action_pressed("move_right"):
		s += 1.0
	var joy_x: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	if abs(joy_x) > 0.15:
		var val = (abs(joy_x) - 0.15) / 0.85
		s += sign(joy_x) * pow(val, 1.4)
	return clampf(s, -1.0, 1.0)


func _update_wind_efficiency() -> void:
	if not wind_system:
		sail_efficiency = 0.0
		return
	var boat_fwd: Vector3 = -global_transform.basis.z
	var wd = wind_system.get_wind_data()
	wind_alignment = boat_fwd.dot(wd.direction)
	if wind_alignment >= 0.0:
		sail_efficiency = 1.0 - wind_alignment * 0.15
	else:
		sail_efficiency = clampf(0.5 + wind_alignment * 0.3, 0.2, 0.5)
	if not sail_open:
		sail_efficiency = 0.0

func _apply_ocean_buoyancy(_dt: float) -> void:
	var t: float = Time.get_ticks_msec() * 0.001
	var pos: Vector3 = global_position
	var wave_h: float = _get_wave_height(pos.x, pos.z, t)
	var water_y: float = target_height + wave_h
	var depth: float = water_y - pos.y
	apply_central_force(Vector3.UP * (depth * buoyancy_stiffness - linear_velocity.y * buoyancy_damping))

	var up = global_transform.basis.y
	_align_to_vector(up, Vector3.UP, stabilization_torque)

func _align_to_vector(current: Vector3, target: Vector3, torque: float) -> void:
	var angle = current.angle_to(target)
	if angle > 0.01:
		var axis = current.cross(target).normalized()
		apply_torque(axis * torque * angle)

func _get_wave_height(x: float, z: float, t: float) -> float:
	var primary := sin(x * wave_length + t * wave_speed) * cos(z * wave_length * 0.8 + t * wave_speed * 0.6) * wave_amplitude
	return primary

func _check_capsize() -> void:
	var up = global_transform.basis.y
	if rad_to_deg(up.angle_to(Vector3.UP)) > capsize_tilt_degrees:
		_trigger_capsize()
	elif global_position.y < capsize_depth:
		_trigger_capsize()

func _trigger_capsize() -> void:
	if _is_capsized: return
	_is_capsized = true
	_capsize_timer = capsize_respawn_delay
	linear_velocity = Vector3.ZERO; angular_velocity = Vector3.ZERO
	visible = false

func _respawn_at_harbor() -> void:
	_is_capsized = false
	visible = true; sail_open = true; move_state = MoveState.IDLE
	_deferred_teleport.call_deferred(HARBOR_SPAWN, HARBOR_HEADING)

func _teleport_to_harbor() -> void:
	_spawn_grace = 3.0
	_deferred_teleport.call_deferred(HARBOR_SPAWN, HARBOR_HEADING)

func _deferred_teleport(pos: Vector3, heading_deg: float) -> void:
	linear_velocity = Vector3.ZERO; angular_velocity = Vector3.ZERO
	global_position = pos
	global_rotation = Vector3(0, deg_to_rad(heading_deg), 0)
	for child in get_children():
		if child is GPUParticles3D: child.restart()

func _build_visuals() -> void:
	# Quetzal mesh is now part of the boat.tscn scene via the Model/QuetzalMesh node and its script.
	# All visuals are handled in the scene file now - no procedural building needed.
	pass

func _update_visuals(_dt: float) -> void:
	pass

func _make_mesh(m: Mesh, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	return mi

func _make_mat(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	return mat

func _on_body_entered(_body: Node) -> void:
	pass

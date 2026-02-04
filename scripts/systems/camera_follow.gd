extends Camera3D

enum CameraMode { BOAT, MARINER }

var current_mode: CameraMode = CameraMode.BOAT
var transition_tween: Tween = null

@export var boat_offset: Vector3 = Vector3(0, 10, 35)
@export var mariner_offset: Vector3 = Vector3(0, 1.6, 0)  # Shoulder cam

## Third-person chase camera with orbit controls.
##
## MOUSE: Right-click drag to orbit.  Scroll = zoom.
## KEYBOARD: Q/E to orbit.
## GAMEPAD: Right stick orbits.
## Auto-returns behind the boat after idle.

@export var min_distance: float = 10.0
@export var max_distance: float = 45.0
@export var default_distance: float = 24.0
@export var height_offset: float = 6.0
@export var look_up_offset: float = 4.0
@export var follow_smoothness: float = 4.0
@export var orbit_sensitivity: float = 0.004
@export var keyboard_orbit_speed: float = 2.0
@export var gamepad_orbit_speed: float = 2.0
@export var zoom_speed: float = 3.0
@export var auto_return_delay: float = 5.0
@export var auto_return_speed: float = 0.8

var target: Node3D
var _orbit_angle: float = 0.0
var _orbit_pitch: float = 0.15 # Flatter start angle for horizon view
var _distance: float = 24.0
var _mouse_orbiting: bool = false
var _last_input_time: float = 0.0
var _initialized: bool = false

func _ready() -> void:
	_distance = default_distance
	await get_tree().process_frame
	target = get_tree().get_first_node_in_group("boat")
	if not target:
		target = get_node_or_null("/root/World/Boat")
	# Snap camera to correct position on first frame (no lerp swoosh)
	if target:
		_snap_to_target()

func _snap_to_target() -> void:
	if not target:
		return
	var pos: Vector3 = _compute_camera_pos()
	global_position = pos
	look_at(target.global_position + Vector3.UP * look_up_offset, Vector3.UP)
	_initialized = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_orbiting = event.pressed
			if event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(_distance - zoom_speed, min_distance)
			_mark_input()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(_distance + zoom_speed, max_distance)
			_mark_input()

	if event is InputEventMouseMotion and _mouse_orbiting:
		_orbit_angle -= event.relative.x * orbit_sensitivity
		_orbit_pitch = clampf(_orbit_pitch + event.relative.y * orbit_sensitivity, -0.2, 1.2)
		_mark_input()

func _process(delta: float) -> void:
	if not target or not is_instance_valid(target):
		return

	if not _initialized:
		_snap_to_target()
		return

	_handle_keyboard_orbit(delta)
	_handle_gamepad_orbit(delta)
	_handle_auto_return(delta)

	var cam_target: Vector3 = _compute_camera_pos()
	global_position = global_position.lerp(cam_target, follow_smoothness * delta)
	look_at(target.global_position + Vector3.UP * look_up_offset, Vector3.UP)

func _compute_camera_pos() -> Vector3:
	var boat_pos: Vector3 = target.global_position
	var boat_heading: float = target.global_rotation.y

	# Camera goes BEHIND the boat.
	# Boat forward = -Z, so boat_heading=0 means facing -Z.
	# "Behind" = +Z from boat = heading + 0 (not + PI).
	# orbit_angle=0 means directly behind.
	var cam_angle: float = boat_heading + _orbit_angle
	var hor_dist: float = _distance * cos(_orbit_pitch)
	var vert_dist: float = _distance * sin(_orbit_pitch) + height_offset

	return Vector3(
		boat_pos.x + sin(cam_angle) * hor_dist,
		boat_pos.y + vert_dist,
		boat_pos.z + cos(cam_angle) * hor_dist
	)

func _handle_keyboard_orbit(delta: float) -> void:
	var orbit_input: float = 0.0
	if Input.is_key_pressed(KEY_Q):
		orbit_input += 1.0
	if Input.is_key_pressed(KEY_E):
		orbit_input -= 1.0
	if abs(orbit_input) > 0.01:
		_orbit_angle += orbit_input * keyboard_orbit_speed * delta
		_mark_input()

func _handle_gamepad_orbit(delta: float) -> void:
	var rx: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	
	# Apply deadzone and curve for smoother control
	if abs(rx) < 0.2: rx = 0.0
	else: rx = sign(rx) * pow((abs(rx) - 0.2) / 0.8, 1.5)
		
	if abs(ry) < 0.2: ry = 0.0
	else: ry = sign(ry) * pow((abs(ry) - 0.2) / 0.8, 1.5)

	if abs(rx) > 0.01:
		_orbit_angle -= rx * gamepad_orbit_speed * delta
		_mark_input()
	if abs(ry) > 0.01:
		_orbit_pitch = clampf(_orbit_pitch + ry * gamepad_orbit_speed * delta * 0.5, -0.2, 1.2)
		_mark_input()


func _handle_auto_return(delta: float) -> void:
	var time_now := Time.get_ticks_msec() * 0.001
	if time_now - _last_input_time > auto_return_delay:
		_orbit_angle = lerpf(_orbit_angle, 0.0, auto_return_speed * delta)
		_orbit_pitch = lerpf(_orbit_pitch, 0.35, auto_return_speed * delta * 0.5)

func _mark_input() -> void:
	_last_input_time = Time.get_ticks_msec() * 0.001

# ═══════════════════════════════════════════════════════════════════════════
# STATE MACHINE INTEGRATION
# ═══════════════════════════════════════════════════════════════════════════

func set_mode(mode: String) -> void:
	match mode:
		"boat":
			current_mode = CameraMode.BOAT
		"mariner":
			current_mode = CameraMode.MARINER

func transition_to_mariner(duration: float) -> void:
	if transition_tween:
		transition_tween.kill()
	
	current_mode = CameraMode.MARINER
	current = true
	
	# Find mariner
	var mariner = get_tree().get_first_node_in_group("mariner")
	if mariner:
		target = mariner
		
		# Smooth transition
		transition_tween = create_tween()
		transition_tween.set_trans(Tween.TRANS_CUBIC)
		transition_tween.set_ease(Tween.EASE_IN_OUT)
		
		# Reparent to mariner's camera pivot if it exists
		var mariner_pivot = mariner.get_node_or_null("CameraPivot")
		if mariner_pivot:
			var old_global_pos = global_position
			var old_global_rot = global_rotation
			
			get_parent().remove_child(self)
			mariner_pivot.add_child(self)
			
			global_position = old_global_pos
			global_rotation = old_global_rot
			
			# Tween to local shoulder position
			transition_tween.tween_property(self, "position", Vector3.ZERO, duration)
			transition_tween.parallel().tween_property(self, "rotation", Vector3.ZERO, duration)

func transition_to_boat(duration: float) -> void:
	if transition_tween:
		transition_tween.kill()
	
	current_mode = CameraMode.BOAT
	current = true
	
	# Find boat
	var boat = get_tree().get_first_node_in_group("boat")
	if boat:
		target = boat
		
		# Smooth transition back
		transition_tween = create_tween()
		transition_tween.set_trans(Tween.TRANS_CUBIC)
		transition_tween.set_ease(Tween.EASE_IN_OUT)
		
		# Reparent back to boat's camera pivot
		var boat_pivot = boat.get_node_or_null("CameraPivot")
		if boat_pivot:
			var old_global_pos = global_position
			var old_global_rot = global_rotation
			
			get_parent().remove_child(self)
			boat_pivot.add_child(self)
			
			global_position = old_global_pos
			global_rotation = old_global_rot
			
			# Snap back to orbit camera position
			_snap_to_target()

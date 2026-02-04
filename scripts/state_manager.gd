extends Node
class_name StateManager

## Central state machine for boat sailing, docking, and player movement
## Enforces single movement authority and smooth transitions

signal state_changed(old_state: State, new_state: State)
signal docking_available(dock_zone: DockZone)
signal docking_unavailable()

enum State {
	SAILING,    # Player controls boat with arcade physics
	DOCKING,    # Smooth deceleration to dock
	DOCKED,     # Boat frozen, can disembark
	ON_FOOT     # Player walking on island
}

@export var boat: RigidBody3D
@export var mariner: CharacterBody3D
@export var camera_controller: Node

var current_state: State = State.SAILING
var current_dock_zone: DockZone = null
var docking_tween: Tween = null

# Thresholds
const DOCK_SPEED_THRESHOLD := 5.0  # Max speed to initiate docking
const DOCKED_SPEED_THRESHOLD := 0.5  # Speed considered "stopped"
const DOCK_LERP_DURATION := 1.5
const CAMERA_TRANSITION_DURATION := 0.8

func _ready() -> void:
	if not boat:
		push_error("StateManager: Boat not assigned!")
		return
	if not mariner:
		push_error("StateManager: Mariner not assigned!")
		return
	
	# Start in sailing state
	_enter_sailing()

func _process(delta: float) -> void:
	match current_state:
		State.SAILING:
			_process_sailing(delta)
		State.DOCKING:
			_process_docking(delta)
		State.DOCKED:
			_process_docked(delta)
		State.ON_FOOT:
			_process_on_foot(delta)

# ═══════════════════════════════════════════════════════════════════════════
# STATE: SAILING
# ═══════════════════════════════════════════════════════════════════════════

func _enter_sailing() -> void:
	print("→ SAILING")
	boat.set_physics_process(true)
	boat.freeze = false
	mariner.set_physics_process(false)
	mariner.visible = false  # Mariner is "on the boat"
	
	if camera_controller:
		camera_controller.set_mode("boat")

func _process_sailing(_delta: float) -> void:
	# Check for dock zone entry
	if current_dock_zone and boat.linear_velocity.length() < DOCK_SPEED_THRESHOLD:
		if Input.is_action_just_pressed("interact"):
			transition_to(State.DOCKING)

func _exit_sailing() -> void:
	pass

# ═══════════════════════════════════════════════════════════════════════════
# STATE: DOCKING
# ═══════════════════════════════════════════════════════════════════════════

func _enter_docking() -> void:
	print("→ DOCKING")
	
	# Smooth velocity reduction
	if docking_tween:
		docking_tween.kill()
	
	docking_tween = create_tween()
	docking_tween.set_parallel(true)
	docking_tween.tween_property(boat, "linear_velocity", Vector3.ZERO, DOCK_LERP_DURATION)
	docking_tween.tween_property(boat, "angular_velocity", Vector3.ZERO, DOCK_LERP_DURATION)

func _process_docking(_delta: float) -> void:
	# Check if stopped
	if boat.linear_velocity.length() < DOCKED_SPEED_THRESHOLD:
		transition_to(State.DOCKED)
	
	# Allow canceling dock by accelerating
	if Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_backward"):
		if docking_tween:
			docking_tween.kill()
		transition_to(State.SAILING)

func _exit_docking() -> void:
	if docking_tween:
		docking_tween.kill()
		docking_tween = null

# ═══════════════════════════════════════════════════════════════════════════
# STATE: DOCKED
# ═══════════════════════════════════════════════════════════════════════════

func _enter_docked() -> void:
	print("→ DOCKED")
	boat.freeze = true
	boat.set_physics_process(false)
	
	# Keep collision active for stability
	boat.collision_layer = 1
	boat.collision_mask = 3

func _process_docked(_delta: float) -> void:
	# Disembark
	if Input.is_action_just_pressed("interact"):
		transition_to(State.ON_FOOT)
	
	# Undock
	if Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_backward"):
		transition_to(State.SAILING)

func _exit_docked() -> void:
	pass

# ═══════════════════════════════════════════════════════════════════════════
# STATE: ON_FOOT
# ═══════════════════════════════════════════════════════════════════════════

func _enter_on_foot() -> void:
	print("→ ON_FOOT")
	
	# Position mariner on dock
	if current_dock_zone:
		mariner.global_position = current_dock_zone.get_spawn_point()
	
	mariner.visible = true
	mariner.set_physics_process(true)
	
	# Camera transition
	if camera_controller:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_IN_OUT)
		camera_controller.transition_to_mariner(CAMERA_TRANSITION_DURATION)

func _process_on_foot(_delta: float) -> void:
	# Check for re-boarding (near boat)
	var distance_to_boat = mariner.global_position.distance_to(boat.global_position)
	if distance_to_boat < 5.0 and Input.is_action_just_pressed("interact"):
		transition_to(State.DOCKED)

func _exit_on_foot() -> void:
	mariner.set_physics_process(false)
	mariner.visible = false
	
	# Camera back to boat
	if camera_controller:
		camera_controller.transition_to_boat(CAMERA_TRANSITION_DURATION)

# ═══════════════════════════════════════════════════════════════════════════
# TRANSITIONS
# ═══════════════════════════════════════════════════════════════════════════

func transition_to(new_state: State) -> void:
	if new_state == current_state:
		return
	
	var old_state = current_state
	
	# Exit current state
	match current_state:
		State.SAILING: _exit_sailing()
		State.DOCKING: _exit_docking()
		State.DOCKED: _exit_docked()
		State.ON_FOOT: _exit_on_foot()
	
	current_state = new_state
	
	# Enter new state
	match new_state:
		State.SAILING: _enter_sailing()
		State.DOCKING: _enter_docking()
		State.DOCKED: _enter_docked()
		State.ON_FOOT: _enter_on_foot()
	
	state_changed.emit(old_state, new_state)

# ═══════════════════════════════════════════════════════════════════════════
# DOCK ZONE CALLBACKS
# ═══════════════════════════════════════════════════════════════════════════

func _on_dock_zone_entered(dock_zone: DockZone) -> void:
	current_dock_zone = dock_zone
	docking_available.emit(dock_zone)
	print("📍 Dock available: %s" % dock_zone.name)

func _on_dock_zone_exited(dock_zone: DockZone) -> void:
	if current_dock_zone == dock_zone:
		current_dock_zone = null
		docking_unavailable.emit()
		print("📍 Left dock zone")

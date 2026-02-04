extends Node3D
class_name DockingSystem

## Manages dock zones around islands and the anchor mechanic.
##
## DOCK ZONES: Area3D triggers placed near island docks.
##   When the boat enters a zone at low speed, a prompt appears.
##   Press F (or gamepad Y) to dock. Press again to undock.
##
## ANCHOR: Press F at open sea (no dock zone) to drop anchor.
##   Boat decelerates and holds position with gentle bobbing.
##   Press F again to raise anchor.
##
## AC-style: docking auto-pilots the boat to the dock point,
##   then locks it in place. Undocking gives a gentle push out.

signal dock_state_changed(state: String)  # "docked", "anchored", "sailing"
signal prompt_changed(text: String)       # "" = hide prompt

const DOCK_APPROACH_SPEED: float = 3.0   # Max speed to allow docking
const DOCK_ZONE_RADIUS: float = 18.0     # How close to trigger prompt
const ANCHOR_DRAG: float = 25.0          # Heavy drag when anchored
const ANCHOR_DROP_SPEED: float = 4.0     # Max speed to drop anchor

enum State { SAILING, DOCKING_APPROACH, DOCKED, ANCHORED, UNDOCKING }

var state: int = State.SAILING
var _boat: RigidBody3D
var _active_dock: Dictionary = {}  # {position, forward_dir, island_name}
var _nearby_docks: Array[Dictionary] = []
var _dock_points: Array[Dictionary] = []  # All registered dock points
var _anchor_position: Vector3 = Vector3.ZERO
var _dock_lerp: float = 0.0
var _undock_timer: float = 0.0

# Visual nodes
var _anchor_mesh: MeshInstance3D
var _anchor_chain: MeshInstance3D
var _anchor_visible: bool = false

func _ready() -> void:
	# Find boat
	await get_tree().process_frame
	_boat = get_tree().get_first_node_in_group("boat")
	if not _boat:
		_boat = get_node_or_null("/root/World/Boat")
	if _boat:
		_boat.add_to_group("boat")
		print("⚓ Docking system connected to boat")

func register_dock_point(world_pos: Vector3, forward_dir: Vector3, island_name: String) -> void:
	_dock_points.append({
		"position": world_pos,
		"forward_dir": forward_dir.normalized(),
		"island_name": island_name,
	})

func _physics_process(dt: float) -> void:
	if not _boat:
		return

	match state:
		State.SAILING:
			_check_nearby_docks()
		State.DOCKING_APPROACH:
			_do_docking_approach(dt)
		State.DOCKED:
			_hold_docked_position()
		State.ANCHORED:
			_apply_anchor_physics(dt)
		State.UNDOCKING:
			_do_undocking(dt)

func _unhandled_input(event: InputEvent) -> void:
	if not _boat:
		return

	# F key or gamepad Y
	var is_interact := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F:
			is_interact = true
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_Y:
			is_interact = true

	if not is_interact:
		return

	match state:
		State.SAILING:
			if _nearby_docks.size() > 0:
				_begin_docking(_nearby_docks[0])
			else:
				_try_anchor()
		State.DOCKED:
			_begin_undocking()
		State.ANCHORED:
			_raise_anchor()

# ── Dock proximity check ──────────────────────────────────────────────────
func _check_nearby_docks() -> void:
	_nearby_docks.clear()
	var boat_pos := _boat.global_position
	var boat_speed: float = _boat.linear_velocity.length()

	for dock in _dock_points:
		var dist: float = boat_pos.distance_to(dock.position)
		if dist < DOCK_ZONE_RADIUS:
			_nearby_docks.append(dock)

	if _nearby_docks.size() > 0:
		_nearby_docks.sort_custom(func(a, b):
			return boat_pos.distance_to(a.position) < boat_pos.distance_to(b.position))
		var nearest = _nearby_docks[0]
		if boat_speed < DOCK_APPROACH_SPEED * 2.5:
			prompt_changed.emit("[F] Dock at %s" % nearest.island_name)
		else:
			prompt_changed.emit("Slow down to dock (S to brake)")
	else:
		# Check if near any island (suppress anchor near shore to prevent getting stuck)
		var island_sys = get_node_or_null("/root/World/IslandSystem") as IslandSystem
		var near_island: bool = false
		if island_sys:
			near_island = island_sys.is_near_island(boat_pos, 20.0)

		if near_island:
			prompt_changed.emit("")  # Too close to shore for anchor
		elif boat_speed < ANCHOR_DROP_SPEED * 2:
			prompt_changed.emit("[F] Drop Anchor")
		else:
			prompt_changed.emit("")

# ── Docking ───────────────────────────────────────────────────────────────
func _begin_docking(dock: Dictionary) -> void:
	var boat_speed: float = _boat.linear_velocity.length()
	if boat_speed > DOCK_APPROACH_SPEED * 2.5:
		prompt_changed.emit("Too fast to dock!")
		return

	_active_dock = dock
	state = State.DOCKING_APPROACH
	_dock_lerp = 0.0
	# Start slowing the boat
	_boat.linear_velocity *= 0.3
	_boat.angular_velocity *= 0.1
	prompt_changed.emit("Docking...")
	dock_state_changed.emit("docking")
	print("🚢 Docking at %s" % dock.island_name)

func _do_docking_approach(dt: float) -> void:
	_dock_lerp += dt * 0.8  # ~1.25 seconds to dock
	_dock_lerp = min(_dock_lerp, 1.0)

	var ease_t: float = _ease_in_out(_dock_lerp)

	# Lerp boat to dock position
	var target_pos: Vector3 = _active_dock.position
	target_pos.y = _boat.global_position.y  # Keep current water height
	_boat.global_position = _boat.global_position.lerp(target_pos, ease_t * dt * 3.0)

	# Rotate to face dock forward direction
	var target_angle: float = atan2(_active_dock.forward_dir.x, _active_dock.forward_dir.z)
	var current_rot: Vector3 = _boat.global_rotation
	current_rot.y = lerp_angle(current_rot.y, target_angle, ease_t * dt * 3.0)
	_boat.global_rotation = current_rot

	# Kill velocity progressively
	_boat.linear_velocity = _boat.linear_velocity.lerp(Vector3.ZERO, dt * 5.0)
	_boat.angular_velocity = _boat.angular_velocity.lerp(Vector3.ZERO, dt * 5.0)

	if _dock_lerp >= 1.0:
		_finish_docking()

func _finish_docking() -> void:
	state = State.DOCKED
	_boat.linear_velocity = Vector3.ZERO
	_boat.angular_velocity = Vector3.ZERO
	_boat.freeze = true
	prompt_changed.emit("[F] Undock")
	dock_state_changed.emit("docked")
	print("✅ Docked at %s" % _active_dock.island_name)

func _hold_docked_position() -> void:
	# Boat is frozen, just keep gentle bob
	# (freeze prevents physics, but we can still sway the visual)
	pass

func _begin_undocking() -> void:
	state = State.UNDOCKING
	_boat.freeze = false
	_undock_timer = 0.0
	prompt_changed.emit("Undocking...")
	dock_state_changed.emit("undocking")
	print("🚢 Undocking from %s" % _active_dock.island_name)

	# Push the boat away from the dock
	var push_dir: Vector3 = -_active_dock.forward_dir
	push_dir.y = 0
	push_dir = push_dir.normalized()
	_boat.apply_central_impulse(push_dir * 80.0)

func _do_undocking(dt: float) -> void:
	_undock_timer += dt
	if _undock_timer > 1.5:
		state = State.SAILING
		_active_dock = {}
		prompt_changed.emit("")
		dock_state_changed.emit("sailing")
		print("⛵ Back to sailing")

# ── Anchor ────────────────────────────────────────────────────────────────
func _try_anchor() -> void:
	var boat_speed: float = _boat.linear_velocity.length()
	if boat_speed > ANCHOR_DROP_SPEED * 2:
		prompt_changed.emit("Too fast to anchor!")
		return

	# Don't allow anchoring near shore
	var island_sys = get_node_or_null("/root/World/IslandSystem") as IslandSystem
	if island_sys and island_sys.is_near_island(_boat.global_position, 20.0):
		prompt_changed.emit("Too close to shore!")
		return

	state = State.ANCHORED
	_anchor_position = _boat.global_position
	_show_anchor(true)
	prompt_changed.emit("[F] Raise Anchor")
	dock_state_changed.emit("anchored")
	print("⚓ Anchor dropped at %s" % str(_anchor_position))

func _apply_anchor_physics(dt: float) -> void:
	# Heavy drag to stop the boat
	_boat.linear_velocity = _boat.linear_velocity.lerp(Vector3.ZERO, ANCHOR_DRAG * dt)
	_boat.angular_velocity = _boat.angular_velocity.lerp(Vector3.ZERO, 8.0 * dt)

	# Gentle elastic pull back to anchor position
	var offset: Vector3 = _anchor_position - _boat.global_position
	offset.y = 0  # Only horizontal
	var dist: float = offset.length()
	if dist > 2.0:
		_boat.apply_central_force(offset.normalized() * (dist - 2.0) * 15.0)

	# Update chain visual
	_update_anchor_visual()

func _raise_anchor() -> void:
	state = State.SAILING
	_show_anchor(false)
	prompt_changed.emit("")
	dock_state_changed.emit("sailing")
	print("⚓ Anchor raised")

# ── Anchor Visuals ────────────────────────────────────────────────────────
func _show_anchor(vis: bool) -> void:
	_anchor_visible = vis
	if vis and not _anchor_mesh:
		_build_anchor_visual()
	if _anchor_mesh:
		_anchor_mesh.visible = vis
	if _anchor_chain:
		_anchor_chain.visible = vis

func _build_anchor_visual() -> void:
	if not _boat:
		return
	# Anchor body - a small dark shape hanging from the boat
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.25, 0.28)
	mat.metallic = 0.7
	mat.roughness = 0.4

	# Anchor shape (simplified cross)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.15
	mesh.bottom_radius = 0.2
	mesh.height = 1.0

	_anchor_mesh = MeshInstance3D.new()
	_anchor_mesh.name = "AnchorMesh"
	_anchor_mesh.mesh = mesh
	_anchor_mesh.material_override = mat
	_anchor_mesh.visible = false
	_boat.add_child(_anchor_mesh)

	# Chain (thin cylinder from boat to anchor)
	var chain_mat := StandardMaterial3D.new()
	chain_mat.albedo_color = Color(0.35, 0.33, 0.3)
	chain_mat.metallic = 0.6
	chain_mat.roughness = 0.5

	var chain_mesh := CylinderMesh.new()
	chain_mesh.top_radius = 0.03
	chain_mesh.bottom_radius = 0.03
	chain_mesh.height = 1.0  # Will be scaled dynamically

	_anchor_chain = MeshInstance3D.new()
	_anchor_chain.name = "AnchorChain"
	_anchor_chain.mesh = chain_mesh
	_anchor_chain.material_override = chain_mat
	_anchor_chain.visible = false
	_boat.add_child(_anchor_chain)

func _update_anchor_visual() -> void:
	if not _anchor_mesh or not _anchor_visible:
		return

	# Anchor drops to a fixed depth below the boat
	var anchor_depth: float = 4.0
	_anchor_mesh.global_position = Vector3(
		_anchor_position.x,
		_boat.global_position.y - anchor_depth,
		_anchor_position.z
	)

	# Chain connects stern of boat to anchor
	if _anchor_chain:
		var stern := _boat.global_position + _boat.global_transform.basis.z * 3.0
		var anchor_pos := _anchor_mesh.global_position
		var mid := (stern + anchor_pos) * 0.5
		_anchor_chain.global_position = mid
		var chain_len := stern.distance_to(anchor_pos)
		_anchor_chain.scale = Vector3(1, chain_len, 1)
		# Point chain from stern to anchor
		if chain_len > 0.1:
			var dir := (anchor_pos - stern).normalized()
			_anchor_chain.global_transform = _anchor_chain.global_transform.looking_at(
				_anchor_chain.global_position + dir, Vector3.RIGHT
			)
			_anchor_chain.rotate_object_local(Vector3.RIGHT, PI * 0.5)

# ── Utility ───────────────────────────────────────────────────────────────
func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

func is_docked() -> bool:
	return state == State.DOCKED

func is_anchored() -> bool:
	return state == State.ANCHORED

func is_free() -> bool:
	return state == State.SAILING

func get_state_name() -> String:
	match state:
		State.SAILING: return "Sailing"
		State.DOCKING_APPROACH: return "Docking..."
		State.DOCKED: return "Docked"
		State.ANCHORED: return "Anchored"
		State.UNDOCKING: return "Undocking..."
	return "Unknown"

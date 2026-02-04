extends Area3D
class_name DockZone

## Dock zone for islands - detects boat entry and provides docking alignment

signal boat_entered(boat: RigidBody3D)
signal boat_exited(boat: RigidBody3D)

@export var dock_name: String = "Dock"
@export var spawn_point_offset: Vector3 = Vector3(0, 1, 5)  # Where player spawns when disembarking

@onready var spawn_marker: Marker3D = $SpawnPoint

func _ready() -> void:
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Create spawn point if it doesn't exist
	if not spawn_marker:
		spawn_marker = Marker3D.new()
		spawn_marker.name = "SpawnPoint"
		spawn_marker.position = spawn_point_offset
		add_child(spawn_marker)
	
	# Set collision layers
	collision_layer = 0  # Don't collide with anything
	collision_mask = 1   # Detect boats (layer 1)
	
	monitoring = true
	monitorable = false

func _on_body_entered(body: Node3D) -> void:
	if body is RigidBody3D and body.is_in_group("boat"):
		boat_entered.emit(body)
		print("🚢 Boat entered %s" % dock_name)

func _on_body_exited(body: Node3D) -> void:
	if body is RigidBody3D and body.is_in_group("boat"):
		boat_exited.emit(body)
		print("🚢 Boat left %s" % dock_name)

func get_spawn_point() -> Vector3:
	if spawn_marker:
		return spawn_marker.global_position
	return global_position + spawn_point_offset

func get_alignment_target() -> Transform3D:
	# Returns the ideal boat position/rotation for docking
	return global_transform

extends Node3D
class_name CurrentSystem

## Simulates ocean currents (gyres, streams) that affect physics objects.
## Visualizes flow with floating particles/meshes.

@export_group("Simulation")
@export var base_strength: float = 8.0
@export var gyre_center: Vector3 = Vector3.ZERO
@export var gyre_radius: float = 400.0
@export var gyre_speed: float = 1.5

@export_group("Visuals")
@export var show_currents: bool = true
@export var flow_line_count: int = 100
@export var flow_color: Color = Color(0.1, 0.4, 0.6, 0.3)

var _flow_lines: MultiMeshInstance3D

func _ready() -> void:
	if show_currents:
		_setup_visuals()

func _process(delta: float) -> void:
	# Subtle shift of the gyre center or strength could happen here
	pass

# ── API ─────────────────────────────────────────────────────────────────────

## Returns the current velocity vector at a given world position
func get_current_velocity_at(pos: Vector3) -> Vector3:
	var velocity := Vector3.ZERO
	
	# 1. Main Gyre (Clockwise around center)
	var offset = pos - gyre_center
	var dist = offset_no_y(offset).length()
	
	if dist > 50.0 and dist < gyre_radius * 1.5:
		var tangent = Vector3(offset.z, 0, -offset.x).normalized()
		# Current is strongest at 60% of radius, fades edges
		var strength_curve = ease_curve(dist / gyre_radius) 
		velocity += tangent * base_strength * gyre_speed * strength_curve

	# 2. Add some turbulence/noise
	var noise = sin(pos.x * 0.02) * cos(pos.z * 0.02)
	velocity += Vector3(noise, 0, -noise) * 2.0
	
	return velocity

# ── Visuals ─────────────────────────────────────────────────────────────────

func _setup_visuals() -> void:
	_flow_lines = MultiMeshInstance3D.new()
	_flow_lines.name = "FlowVisuals"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false # Replaces color_format = COLOR_NONE
	mm.instance_count = flow_line_count
	
	# Arrow mesh
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.2
	mesh.height = 3.0
	mm.mesh = mesh
	
	_flow_lines.multimesh = mm
	
	# Material
	var mat = StandardMaterial3D.new()
	mat.albedo_color = flow_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flow_lines.material_override = mat
	
	add_child(_flow_lines)
	_update_visual_positions()

func _update_visual_positions() -> void:
	if not _flow_lines: return
	
	for i in range(_flow_lines.multimesh.instance_count):
		# Random spots in the ocean
		var r = sqrt(randf()) * gyre_radius * 1.2
		var theta = randf() * TAU
		var pos = gyre_center + Vector3(sin(theta)*r, -1.0, cos(theta)*r)
		
		# Align with flow
		var vel = get_current_velocity_at(pos)
		if vel.length_squared() < 0.1:
			pos.y = -100 # Hide
		
		var t = Transform3D()
		if vel.length() > 0.1:
			t = t.looking_at(vel.normalized(), Vector3.UP)
			t.origin = pos
			# Rotate 90 deg x to lay flat if using cylinder as arrow pointing Y
			# Actually standard cylinder matches Y. We want it pointing forward Z.
			# Let's just use looking_at which points -Z. 
			# Mesh is Y up. So we need to rotate mesh or transform.
			# Simpler: Rotate mesh: top=forward.
			t = t.rotated_local(Vector3.RIGHT, -PI/2)
		
		_flow_lines.multimesh.set_instance_transform(i, t)

# ── Helpers ─────────────────────────────────────────────────────────────────

func offset_no_y(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)

func ease_curve(t: float) -> float:
	# Bell curve peaking around 0.6
	return maxf(0.0, sin(t * PI))

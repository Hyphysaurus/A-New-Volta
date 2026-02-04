extends Node3D

## Ocean visual details — grid and foam particles.
## Removed rings to avoid visual clutter with new mesh scales.

@export var grid_size: int = 100
@export var grid_spacing: float = 20.0
@export var line_color: Color = Color(0.15, 0.35, 0.42, 0.25)
@export var show_grid: bool = true
@export var show_foam_particles: bool = true

var _foam_particles: GPUParticles3D
var _boat: Node3D

func _ready() -> void:
	if show_grid:
		_create_nav_grid()
	if show_foam_particles:
		_create_foam_particles()
	_boat = _find_boat()
	print("🌊 Ocean visuals ready")

func _process(_delta: float) -> void:
	if _foam_particles and _boat:
		_foam_particles.global_position = _boat.global_position + Vector3(0, 0.3, 0)

# ── Navigation grid — faint lines on the water surface ──────────────────────
func _create_nav_grid() -> void:
	var half := grid_size >> 1
	var step := int(grid_spacing)
	for x in range(-half, half + 1):
		if x % step == 0:
			var alpha: float = 0.3 if (x % (step * 5) == 0) else 0.12
			_create_line(
				Vector3(float(x) * grid_spacing, 0.15, float(-half) * grid_spacing),
				Vector3(float(x) * grid_spacing, 0.15, float(half) * grid_spacing),
				line_color * Color(1, 1, 1, alpha)
			)
	for z in range(-half, half + 1):
		if z % step == 0:
			var alpha: float = 0.3 if (z % (step * 5) == 0) else 0.12
			_create_line(
				Vector3(float(-half) * grid_spacing, 0.15, float(z) * grid_spacing),
				Vector3(float(half) * grid_spacing, 0.15, float(z) * grid_spacing),
				line_color * Color(1, 1, 1, alpha)
			)

func _create_line(from: Vector3, to: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(from)
	im.surface_add_vertex(to)
	im.surface_end()
	mi.mesh = im
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	add_child(mi)

# ── Foam particles near the boat ────────────────────────────────────────────
func _create_foam_particles() -> void:
	_foam_particles = GPUParticles3D.new()
	_foam_particles.name = "OceanFoam"
	_foam_particles.emitting = true
	_foam_particles.amount = 30
	_foam_particles.lifetime = 2.0
	_foam_particles.randomness = 0.5
	_foam_particles.visibility_aabb = AABB(Vector3(-15, -2, -15), Vector3(30, 5, 30))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(5, 0.2, 5)
	pm.direction = Vector3(0, 0.2, 0)
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0, -0.5, 0)
	pm.scale_min = 0.1
	pm.scale_max = 0.4
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.color = Color(0.9, 0.95, 1.0, 0.3)
	_foam_particles.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.97, 1.0, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	_foam_particles.draw_pass_1 = quad

	add_child(_foam_particles)

func _find_boat() -> Node3D:
	var world := get_parent()
	if world:
		return world.get_node_or_null("Boat")
	return null

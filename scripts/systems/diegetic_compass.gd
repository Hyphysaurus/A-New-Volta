extends Node3D
class_name DiegeticCompass

## Physical nautical compass mounted on the boat deck.
##
## A brass-and-glass compass that sits near the stern, visible
## when the camera looks down. The compass rose stays north-aligned
## (counter-rotates against boat heading), and a separate blue
## wind needle shows current wind direction.
##
## This replaces abstract HUD compass elements with a tangible
## in-world object that creates embodied navigation.

@export var smoothing: float = 8.0
@export var wind_needle_smoothing: float = 6.0
@export var bob_amount: float = 0.02  ## Subtle movement with waves

# Materials
var _brass_mat: StandardMaterial3D
var _glass_mat: StandardMaterial3D
var _parchment_mat: StandardMaterial3D
var _needle_mat: StandardMaterial3D
var _wind_needle_mat: StandardMaterial3D

# Components
var _base: MeshInstance3D
var _rose: MeshInstance3D
var _glass_dome: MeshInstance3D
var _heading_needle: MeshInstance3D
var _wind_needle: MeshInstance3D
var _cardinal_markers: Array[MeshInstance3D] = []

# State
var _target_rose_angle: float = 0.0
var _target_wind_angle: float = 0.0
var _bob_phase: float = 0.0
var _wind_system: Node3D

func _ready() -> void:
	_create_materials()
	_build_compass()
	
	# Find wind system
	await get_tree().process_frame
	_wind_system = get_node_or_null("/root/World/WindSystem")
	
	print("🧭 Diegetic compass ready")

func _process(delta: float) -> void:
	var boat: Node3D = get_parent()
	if not boat:
		return
	
	# Counter-rotate rose to stay north-aligned
	var boat_heading: float = boat.global_rotation.y
	_target_rose_angle = -boat_heading
	
	# Wind needle points in wind direction (relative to boat)
	if _wind_system:
		var wind_dir: Vector3 = _wind_system.wind_direction
		var wind_world_angle: float = atan2(wind_dir.x, wind_dir.z)
		_target_wind_angle = wind_world_angle - boat_heading
	
	# Smooth rotation
	if _rose:
		_rose.rotation.y = lerp_angle(_rose.rotation.y, _target_rose_angle, smoothing * delta)
	if _wind_needle:
		_wind_needle.rotation.y = lerp_angle(_wind_needle.rotation.y, _target_wind_angle, wind_needle_smoothing * delta)
	
	# Subtle bob with waves
	_bob_phase += delta * 1.5
	var bob: float = sin(_bob_phase) * bob_amount
	position.y = 0.92 + bob

func _create_materials() -> void:
	# Aged brass
	_brass_mat = StandardMaterial3D.new()
	_brass_mat.albedo_color = Color(0.72, 0.58, 0.32)
	_brass_mat.metallic = 0.8
	_brass_mat.roughness = 0.35
	
	# Glass dome
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.albedo_color = Color(0.9, 0.95, 1.0, 0.25)
	_glass_mat.metallic = 0.1
	_glass_mat.roughness = 0.05
	_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Parchment compass rose
	_parchment_mat = StandardMaterial3D.new()
	_parchment_mat.albedo_color = Color(0.92, 0.88, 0.78)
	_parchment_mat.roughness = 0.9
	_parchment_mat.metallic = 0.0
	
	# Heading needle (gold)
	_needle_mat = StandardMaterial3D.new()
	_needle_mat.albedo_color = Color(0.85, 0.7, 0.25)
	_needle_mat.metallic = 0.9
	_needle_mat.roughness = 0.2
	
	# Wind needle (blue)
	_wind_needle_mat = StandardMaterial3D.new()
	_wind_needle_mat.albedo_color = Color(0.2, 0.5, 0.85)
	_wind_needle_mat.metallic = 0.7
	_wind_needle_mat.roughness = 0.3
	_wind_needle_mat.emission_enabled = true
	_wind_needle_mat.emission = Color(0.15, 0.35, 0.6)
	_wind_needle_mat.emission_energy_multiplier = 0.3

func _build_compass() -> void:
	# ── Base housing (brass cylinder) ──
	_base = MeshInstance3D.new()
	_base.name = "CompassBase"
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.28
	base_mesh.bottom_radius = 0.32
	base_mesh.height = 0.12
	_base.mesh = base_mesh
	_base.material_override = _brass_mat
	_base.position = Vector3.ZERO
	add_child(_base)
	
	# ── Brass rim (outer ring) ──
	var rim := MeshInstance3D.new()
	rim.name = "CompassRim"
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.24
	rim_mesh.outer_radius = 0.30
	rim_mesh.rings = 24
	rim_mesh.ring_segments = 12
	rim.mesh = rim_mesh
	rim.material_override = _brass_mat
	rim.position = Vector3(0, 0.07, 0)
	add_child(rim)
	
	# ── Compass rose (rotating disc) ──
	_rose = MeshInstance3D.new()
	_rose.name = "CompassRose"
	var rose_mesh := CylinderMesh.new()
	rose_mesh.top_radius = 0.22
	rose_mesh.bottom_radius = 0.22
	rose_mesh.height = 0.02
	_rose.mesh = rose_mesh
	_rose.material_override = _parchment_mat
	_rose.position = Vector3(0, 0.06, 0)
	add_child(_rose)
	
	# ── Cardinal direction markers on the rose ──
	_add_cardinal_markers()
	
	# ── Degree tick marks ──
	_add_tick_marks()
	
	# ── Center pivot post ──
	var pivot := MeshInstance3D.new()
	pivot.name = "CenterPivot"
	var pivot_mesh := CylinderMesh.new()
	pivot_mesh.top_radius = 0.015
	pivot_mesh.bottom_radius = 0.02
	pivot_mesh.height = 0.06
	pivot.mesh = pivot_mesh
	pivot.material_override = _brass_mat
	pivot.position = Vector3(0, 0.09, 0)
	_rose.add_child(pivot)
	
	# ── Heading needle (fixed to boat, points forward) ──
	_heading_needle = MeshInstance3D.new()
	_heading_needle.name = "HeadingNeedle"
	var h_needle_mesh := BoxMesh.new()
	h_needle_mesh.size = Vector3(0.015, 0.01, 0.16)
	_heading_needle.mesh = h_needle_mesh
	_heading_needle.material_override = _needle_mat
	_heading_needle.position = Vector3(0, 0.12, -0.02)
	add_child(_heading_needle)
	
	# Heading needle tip (arrow point)
	var h_tip := MeshInstance3D.new()
	h_tip.name = "HeadingTip"
	var h_tip_mesh := BoxMesh.new()
	h_tip_mesh.size = Vector3(0.03, 0.01, 0.03)
	h_tip.mesh = h_tip_mesh
	h_tip.material_override = _needle_mat
	h_tip.position = Vector3(0, 0, -0.09)
	h_tip.rotation.y = PI / 4.0
	_heading_needle.add_child(h_tip)
	
	# ── Wind needle (rotates with wind direction) ──
	_wind_needle = MeshInstance3D.new()
	_wind_needle.name = "WindNeedle"
	_wind_needle.position = Vector3(0, 0.14, 0)
	add_child(_wind_needle)
	
	var w_needle := MeshInstance3D.new()
	var w_needle_mesh := BoxMesh.new()
	w_needle_mesh.size = Vector3(0.012, 0.008, 0.18)
	w_needle.mesh = w_needle_mesh
	w_needle.material_override = _wind_needle_mat
	w_needle.position = Vector3(0, 0, 0.03)
	_wind_needle.add_child(w_needle)
	
	# Wind needle tip (blue arrow)
	var w_tip := MeshInstance3D.new()
	var w_tip_mesh := BoxMesh.new()
	w_tip_mesh.size = Vector3(0.025, 0.008, 0.025)
	w_tip.mesh = w_tip_mesh
	w_tip.material_override = _wind_needle_mat
	w_tip.position = Vector3(0, 0, 0.10)
	w_tip.rotation.y = PI / 4.0
	w_needle.add_child(w_tip)
	
	# ── Glass dome ──
	_glass_dome = MeshInstance3D.new()
	_glass_dome.name = "GlassDome"
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 0.24
	dome_mesh.height = 0.20
	_glass_dome.mesh = dome_mesh
	_glass_dome.material_override = _glass_mat
	_glass_dome.position = Vector3(0, 0.08, 0)
	_glass_dome.scale = Vector3(1.0, 0.5, 1.0)
	add_child(_glass_dome)

func _add_cardinal_markers() -> void:
	var cardinals := [
		{"label": "N", "angle": 0.0, "color": Color(0.8, 0.15, 0.1)},
		{"label": "E", "angle": PI / 2.0, "color": Color(0.2, 0.2, 0.2)},
		{"label": "S", "angle": PI, "color": Color(0.2, 0.2, 0.2)},
		{"label": "W", "angle": -PI / 2.0, "color": Color(0.2, 0.2, 0.2)},
	]
	
	for card in cardinals:
		var marker := MeshInstance3D.new()
		marker.name = "Cardinal_" + card.label
		var marker_mesh := BoxMesh.new()
		marker_mesh.size = Vector3(0.025, 0.015, 0.06)
		marker.mesh = marker_mesh
		
		var mat := StandardMaterial3D.new()
		mat.albedo_color = card.color
		mat.roughness = 0.8
		marker.material_override = mat
		
		var dist: float = 0.16
		marker.position = Vector3(
			sin(card.angle) * dist,
			0.02,
			-cos(card.angle) * dist
		)
		marker.rotation.y = card.angle
		
		_rose.add_child(marker)
		_cardinal_markers.append(marker)

func _add_tick_marks() -> void:
	# Add tick marks every 30 degrees
	for i in range(12):
		var angle: float = float(i) * (TAU / 12.0)
		# Skip cardinals (they have markers)
		if i % 3 == 0:
			continue
		
		var tick := MeshInstance3D.new()
		tick.name = "Tick_%d" % (i * 30)
		var tick_mesh := BoxMesh.new()
		tick_mesh.size = Vector3(0.008, 0.01, 0.03)
		tick.mesh = tick_mesh
		
		var tick_mat := StandardMaterial3D.new()
		tick_mat.albedo_color = Color(0.3, 0.25, 0.2)
		tick.material_override = tick_mat
		
		var dist: float = 0.18
		tick.position = Vector3(
			sin(angle) * dist,
			0.015,
			-cos(angle) * dist
		)
		tick.rotation.y = angle
		
		_rose.add_child(tick)

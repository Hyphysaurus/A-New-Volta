extends Node3D
class_name IslandSystem

## Geologically coherent archipelago generator for Volta do Mar.
## Features a 5-island volcanic chain (Hotspot progression) from SE (Young) to NW (Old).

const COLLISION_LAYER_ISLAND: int = 2

@export_group("Archipelago Settings")
@export var tectonic_axis_angle: float = -45.0 ## Degrees. SE to NW.
@export var chain_spacing: float = 350.0
@export var prevailing_wind_angle: float = 225.0 ## Blowing FROM NE (-135/225 deg)

@export_group("Visual Style")
@export var rock_color: Color = Color(0.50, 0.42, 0.34)
@export var grass_color: Color = Color(0.30, 0.58, 0.22)
@export var dark_grass: Color = Color(0.18, 0.42, 0.14)
@export var sand_color: Color = Color(0.88, 0.82, 0.65)
@export var wet_sand: Color = Color(0.70, 0.62, 0.48)
@export var palm_trunk: Color = Color(0.45, 0.32, 0.18)
@export var palm_leaf: Color = Color(0.22, 0.52, 0.15)
@export var dock_wood: Color = Color(0.40, 0.28, 0.15)
@export var lighthouse_white: Color = Color(0.92, 0.90, 0.85)
@export var lighthouse_red: Color = Color(0.75, 0.15, 0.10)
@export var lava_color: Color = Color(1.0, 0.3, 0.1)
@export var coral_color: Color = Color(0.2, 0.8, 0.7)

var _placed: Array[Vector3] = []
var _container: Node3D
var harbor_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	_container = Node3D.new()
	_container.name = "IslandContainer"
	add_child(_container)
	seed(12345) # Fixed seed for consistent archipelago
	
	_build_harbor_island() # The player start / hub
	_build_home_base_island() # New Home Base island
	_build_eternal_sanctuary() # Eternal Sanctuary island
	_build_overflow_island() # Overflow Island
	_build_archipelago() # The main 5 islands
	_build_archipelago() # The main 5 islands
	_scatter_small_islands() # Fill in the gaps
	
	_register_dock_points()
	print("🏝️ Archipelago generated.")

# ═══════════════════════════════════════════════════════════════════════════
# ARCHIPELAGO GENERATION
# ═══════════════════════════════════════════════════════════════════════════
func _build_archipelago() -> void:
	var axis_rad = deg_to_rad(tectonic_axis_angle)
	var axis_dir = Vector3(sin(axis_rad), 0, cos(axis_rad))
	
	# ── WORLD LAYOUT: DUAL CONTINENTS + ARCTIC + SCATTERED ──
	
	# 1. WESTERN CLUSTER (The Wilds)
	_build_stormfall_expanse(Vector3(-600, 0, 400))
	_build_obsidian_rift(Vector3(-800, 0, -400)) 
	
	# 2. EASTERN CLUSTER (The Sanctuary)
	_build_coral_crown(Vector3(600, 0, 500))
	_build_northeast_atolls(Vector3(900, 0, -300))
	
	# 3. CENTRAL BRIDGE (The Broken Path)
	_build_shattered_archipelago(Vector3(150, 0, 500)) 
	
	# 4. ARCTIC REGION (Far North)
	_build_glacial_spire(Vector3(-300, 0, -1200))
	_build_glacial_spire(Vector3(400, 0, -1100))
	
	# 5. SCATTERED ISLANDS (Filling the void)
	_build_scattered_islands()

# ── SCATTERED ISLANDS ──
func _build_scattered_islands() -> void:
	for i in range(12):
		var pos = Vector3(randf_range(-600, 600), 0, randf_range(-600, 600))
		# Avoid overlap with main clusters (rough checks)
		if pos.distance_to(Vector3(-350,0,150)) < 200: continue
		if pos.distance_to(Vector3(450,0,200)) < 200: continue
		if pos.z < -700: continue # Don't put generic islands in Arctic
		
		# Simple generic small island
		var body := _make_body("Islet_%d" % i, pos)
		var r = randf_range(15, 30)
		_add_mesh(body, _sphere_mesh(r, r*0.5), _mat(grass_color), Vector3(0, r*0.1, 0))
		_add_col_cylinder(body, r, r*0.5, 0)
		if randf() > 0.5:
			_add_vegetation_patch(body, Vector3(0, r*0.2, 0), r*0.5, 3)
		_container.add_child(body)

# ── ARCTIC: GLACIAL SPIRE ───────────────────────────────────────────────────
func _build_glacial_spire(pos: Vector3) -> void:
	var body := _make_body("GlacialSpire", pos)
	_placed.append(pos)
	
	var r = 60.0; var h = 90.0
	
	# Main Ice Spire
	var ice_color = Color(0.8, 0.95, 1.0)
	_add_mesh(body, _cyl_mesh(0.0, r, h), _mat(ice_color, 0.1, 0.8), Vector3(0, h*0.5, 0))
	_add_col_cylinder(body, r, h, h*0.5)
	
	# Floating Icebergs around
	for i in range(8):
		var offset = Vector3(randf_range(-1,1), 0, randf_range(-1,1)).normalized() * randf_range(r+20, r+80)
		var berg_h = randf_range(5, 15)
		var berg_sz = randf_range(10, 25)
		_add_mesh(body, _box_mesh(berg_sz, berg_h, berg_sz), _mat(ice_color), offset + Vector3(0, 1, 0)).rotation = Vector3(randf(), randf(), randf())
		_add_col_box(body, Vector3(berg_sz, berg_h, berg_sz), offset)

	# Snow effect (using a simple particle box if we had one, or static mesh flakes)
	# For now, just the stark visuals.
	
	_add_dock(body, pos, r+5.0, PI)
	_container.add_child(body)

# ── 1. OBSIDIAN RIFT PLATEAU ──────────────────────────────────────────────
func _build_obsidian_rift(pos: Vector3) -> void:
	var body := _make_body("ObsidianRift", pos)
	_placed.append(pos)
	
	# Main blocky plateau
	var w = 120.0; var d = 100.0; var h = 25.0
	
	# Layered sharp blocks
	for i in range(12):
		var offset = Vector3(randf_range(-40,40), 0, randf_range(-40,40))
		var sub_h = h * randf_range(0.5, 1.2)
		var sub_w = randf_range(20, 50)
		_add_mesh(body, _box_mesh(sub_w, sub_h, sub_w), _mat(rock_color.darkened(0.6), 0.4, 0.2), offset + Vector3(0, sub_h*0.4, 0))
		_add_col_box(body, Vector3(sub_w, sub_h, sub_w), offset + Vector3(0, sub_h*0.4, 0))
	
	# Glowing fissures (Magma vents)
	for i in range(5):
		var vent_pos = Vector3(randf_range(-30,30), h*0.5, randf_range(-30,30))
		_add_mesh(body, _cyl_mesh(2.0, 6.0, 15.0), _mat_emission(lava_color, 3.0), vent_pos)
		
	# Sharp crystalline spires
	for i in range(8):
		var spire_pos = Vector3(randf_range(-50,50), 0, randf_range(-50,50))
		_add_mesh(body, _cyl_mesh(0.0, 8.0, 40.0), _mat(Color(0.1, 0.1, 0.1), 0.2, 0.5), spire_pos + Vector3(0, 15, 0))
	
	_add_dock(body, pos, 60.0, PI)      # North
	_add_dock(body, pos, 60.0, PI * 0.25) # North-East
	
	_add_safe_zone_buffer(body, 90.0)
	_container.add_child(body)

# ── 2. SHATTERED ARCHIPELAGO ────────────────────────────────────────────────
func _build_shattered_archipelago(pos: Vector3) -> void:
	var body := _make_body("ShatteredIsles", pos)
	_placed.append(pos)
	
	# Cluster of tall, thin pillars connected by bridges/roots
	for i in range(15):
		var offset = Vector3(randf_range(-60,60), 0, randf_range(-60,60))
		var h = randf_range(30, 80)
		var r = randf_range(5, 12)
		
		# Pillar
		_add_mesh(body, _cyl_mesh(r*0.8, r, h), _mat(rock_color), offset + Vector3(0, h*0.4, 0))
		_add_col_cylinder(body, r, h, h*0.4, offset)
		
		# Vegetation only on top cap
		_add_vegetation_patch(body, offset + Vector3(0, h, 0), r * 0.8, 3)
		
		# Occasional bridges
		if i % 3 == 0:
			var bridge_len = 30.0
			_add_mesh(body, _box_mesh(4.0, 1.0, bridge_len), _mat(rock_color), offset + Vector3(10, h*0.8, 0)).rotation.z = -0.2
			
	_add_dock(body, pos, 70.0, -PI/2)
	_container.add_child(body)

# ── 3. VERIDIA (Lush Rainforest) ────────────────────────────────────────────
# ── 3. STORMFALL EXPANSE ────────────────────────────────────────────────────
func _build_stormfall_expanse(pos: Vector3) -> void:
	var body := _make_body("StormfallExpanse", pos)
	_placed.append(pos)
	
	var r = 70.0; var h = 60.0
	
	# Massive vertical cliffs (layered cylinders)
	_add_mesh(body, _cyl_mesh(r, r+10, h), _mat(rock_color), Vector3(0, h*0.5, 0))
	_add_col_cylinder(body, r, h, h*0.5)
	
	# Upper jungle plateau
	_add_vegetation_patch(body, Vector3(0, h, 0), r*0.9, 40)
	
	# Waterfall
	_add_mesh(body, _box_mesh(12.0, h, 2.0), _mat_alpha(Color(0.8, 0.9, 1.0, 0.6)), Vector3(0, h*0.5, r+2))
	
	# Mist at bottom of waterfall
	_add_mesh(body, _sphere_mesh(15.0, 10.0), _mat_alpha(Color(0.9, 0.95, 1.0, 0.3)), Vector3(0, 5.0, r+10))
	
	# Multiple Docks
	_add_dock(body, pos, r+5.0, 0.0)      # South
	_add_dock(body, pos, r+5.0, PI * 0.5) # West
	_add_dock(body, pos, r+5.0, -PI * 0.5)# East
	
	_add_safe_zone_buffer(body, r + 25.0)
	_container.add_child(body)

# ── 4. ARENARA (Sandy Lowlands) ─────────────────────────────────────────────
# ── 4. NORTHEAST ATOLLS ─────────────────────────────────────────────────────
func _build_northeast_atolls(pos: Vector3) -> void:
	var body := _make_body("NortheastAtolls", pos)
	_placed.append(pos)
	
	# A cluster of small low sandy islands
	for i in range(5):
		var offset = Vector3(randf_range(-60, 60), 0, randf_range(-60, 60))
		var r = randf_range(15, 30)
		
		_add_mesh(body, _cyl_mesh(r, r+5, 2.0), _mat(sand_color), offset + Vector3(0, 1.0, 0))
		_add_col_cylinder(body, r, 2.0, 1.0, offset)
		
		_add_vegetation_patch(body, offset+Vector3(0,2,0), r*0.6, 5)
		
	_add_dock(body, pos, 40.0, PI/2)
	_container.add_child(body)

# ── 5. CORALLIUM (The Atoll) ────────────────────────────────────────────────
# ── 5. CORAL CROWN BASIN ────────────────────────────────────────────────────
func _build_coral_crown(pos: Vector3) -> void:
	var body := _make_body("CoralCrown", pos)
	_placed.append(pos)
	
	var r_outer = 90.0
	var r_inner = 70.0
	var width = r_outer - r_inner
	
	var segments = 24
	for i in range(segments):
		var angle = (float(i) / segments) * TAU
		if i == 0 or i == 12: continue # Two entrances
		
		var center_angle = angle
		var segment_pos = Vector3(sin(center_angle)*(r_inner+width*0.5), 0, cos(center_angle)*(r_inner+width*0.5))
		
		# Wall segment
		var wall = _box_mesh(width, 15.0, (TAU*r_outer)/segments)
		_add_mesh(body, wall, _mat(rock_color), segment_pos + Vector3(0, 7.5, 0)).rotation.y = center_angle
		_add_col_box(body, Vector3(width, 15.0, (TAU*r_outer)/segments), segment_pos + Vector3(0, 7.5, 0))
		
		# Coral crests on top
		if randf() > 0.5:
			_add_mesh(body, _sphere_mesh(4.0, 4.0), _mat(coral_color), segment_pos + Vector3(0, 16.0, 0))

	# Glowing underwater center
	_add_mesh(body, _cyl_mesh(r_inner, r_inner, 1.0), _mat_emission(Color(0.2, 0.8, 0.9), 1.0), Vector3(0, -5.0, 0))
	
	# Floating central crystal
	_add_mesh(body, _cyl_mesh(0.0, 10.0, 25.0), _mat_emission(Color(0.4, 1.0, 0.9), 2.0), Vector3(0, 10.0, 0))
	
	_add_dock(body, pos, r_inner - 10.0, 0.0)
	_container.add_child(body)

# ── Helper: Scatter Small Islands ───────────────────────────────────────────
func _scatter_small_islands() -> void:
	var count = 0
	var tries = 0
	while count < num_small_islands and tries < 500:
		tries += 1
		# Prefer locations that are NOT on the main axis to make it feel like scattered debris
		var pos = _find_pos(25.0)
		if pos.is_finite():
			_build_small(pos, count)
			_placed.append(pos)
			count += 1
			
# ═══════════════════════════════════════════════════════════════════════════
# EXISTING SETUP & HELPERS (Kept for compatibility)
# ═══════════════════════════════════════════════════════════════════════════

func _build_harbor_island() -> void:
	var harbor_mesh_path := "res://assets/meshes/island_retreat.glb"
	var harbor_scene = load(harbor_mesh_path)
	
	if not harbor_scene:
		push_warning("Harbor mesh not found at %s. Falling back to procedural." % harbor_mesh_path)
		_build_procedural_harbor()
		return
		
	var body := StaticBody3D.new()
	body.name = "HarborIsland"
	body.position = Vector3(250.0, 8.0, 0.0) # Raised to stay above waves
	body.collision_layer = COLLISION_LAYER_ISLAND
	body.collision_mask = 0
	harbor_position = body.position
	_placed.append(harbor_position)
	
	var mesh_inst = harbor_scene.instantiate()
	mesh_inst.scale = Vector3(55, 55, 55)
	mesh_inst.position = Vector3(0, -2.0, 0) # Adjust mesh to sit on water surface
	body.add_child(mesh_inst)
	
	# Add some simple collision (The GLB might have it, but let's ensure the boat can't go through the center)
	_add_col_cylinder(body, 40.0, 10.0, 2.0)
	
	# Add a dock indicator (matches existing system)
	_add_dock(body, Vector3.ZERO, 45.0, 0.0) 
	
	_container.add_child(body)

func _build_home_base_island() -> void:
	var home_mesh_path := "res://assets/meshes/home_island.glb"
	var home_scene = load(home_mesh_path)
	
	if not home_scene:
		push_warning("Home Island mesh not found at %s." % home_mesh_path)
		return
		
	var pos := Vector3(0, 5.0, -420)
	var body := StaticBody3D.new()
	body.name = "HomeIsland"
	body.position = pos
	body.collision_layer = COLLISION_LAYER_ISLAND
	body.collision_mask = 0
	_placed.append(pos)
	
	var mesh_inst = home_scene.instantiate()
	mesh_inst.scale = Vector3(40, 40, 40) # Larger scale
	body.add_child(mesh_inst)
	
	_add_col_cylinder(body, 35.0, 10.0, 2.0)
	
	# Add dock zones
	_add_dock_zone(body, pos, 40.0, PI, "HomeIsland_Dock_South")
	_add_dock_zone(body, pos, 40.0, 0.0, "HomeIsland_Dock_North")
	
	_container.add_child(body)

func _build_eternal_sanctuary() -> void:
	var mesh_path := "res://assets/meshes/eternal_sanctuary.glb"
	var scene = load(mesh_path)
	
	if not scene:
		push_warning("Eternal Sanctuary mesh not found at %s." % mesh_path)
		return
		
	var pos := Vector3(-700, 8.0, 200)  # Western region, elevated
	var body := StaticBody3D.new()
	body.name = "EternalSanctuary"
	body.position = pos
	body.collision_layer = COLLISION_LAYER_ISLAND
	body.collision_mask = 0
	_placed.append(pos)
	
	var mesh_inst = scene.instantiate()
	mesh_inst.scale = Vector3(50, 50, 50)  # Large, imposing scale
	body.add_child(mesh_inst)
	
	_add_col_cylinder(body, 45.0, 15.0, 3.0)
	
	# Add dock zones
	_add_dock_zone(body, pos, 50.0, 0.0, "EternalSanctuary_Dock_South")
	_add_dock_zone(body, pos, 50.0, PI * 0.5, "EternalSanctuary_Dock_West")
	
	_container.add_child(body)

func _build_overflow_island() -> void:
	var mesh_path := "res://assets/meshes/overflow_island.glb"
	var scene = load(mesh_path)
	
	if not scene:
		push_warning("Overflow Island mesh not found at %s." % mesh_path)
		return
		
	var pos := Vector3(650, 6.0, -450)  # Eastern region
	var body := StaticBody3D.new()
	body.name = "OverflowIsland"
	body.position = pos
	body.collision_layer = COLLISION_LAYER_ISLAND
	body.collision_mask = 0
	_placed.append(pos)
	
	var mesh_inst = scene.instantiate()
	mesh_inst.scale = Vector3(48, 48, 48)  # Slightly smaller than Eternal Sanctuary
	body.add_child(mesh_inst)
	
	_add_col_cylinder(body, 42.0, 12.0, 2.5)
	
	# Add dock zones
	_add_dock_zone(body, pos, 48.0, PI, "OverflowIsland_Dock_North")
	_add_dock_zone(body, pos, 48.0, -PI * 0.5, "OverflowIsland_Dock_East")
	
	_container.add_child(body)

func _build_procedural_harbor() -> void:
	var body := StaticBody3D.new()
	body.name = "HarborIsland"
	body.position = Vector3.ZERO
	body.collision_layer = COLLISION_LAYER_ISLAND
	body.collision_mask = 0
	_placed.append(Vector3.ZERO)

	var scale: float = 2.5
	var west_center := Vector3(-12 * scale, 0, 0)

	_add_mesh(body, _cyl_mesh(18 * scale, 22 * scale, 1.5), _mat_alpha(Color(0.18, 0.42, 0.48, 0.35)), west_center + Vector3(0, -0.8, 0))
	_add_mesh(body, _cyl_mesh(14 * scale, 17 * scale, 1.2), _mat(sand_color), west_center + Vector3(0, 0.3, 0))
	_add_mesh(body, _cyl_mesh(12 * scale, 14 * scale, 0.8), _mat(wet_sand), west_center + Vector3(0, 0.6, 0))
	_add_mesh(body, _cyl_mesh(10 * scale, 12 * scale, 2.5), _mat(rock_color.lerp(grass_color, 0.25)), west_center + Vector3(0, 1.2, 0))
	_add_mesh(body, _box_mesh(8 * scale, 2.0, 14 * scale), _mat(rock_color.lerp(grass_color, 0.3)), west_center + Vector3(2 * scale, 1.0, 5 * scale))
	_add_mesh(body, _cyl_mesh(7 * scale, 9 * scale, 2.0), _mat(grass_color.lerp(rock_color, 0.15)), west_center + Vector3(-1 * scale, 2.8, -1 * scale))
	_add_mesh(body, _box_mesh(6 * scale, 1.8, 10 * scale), _mat(grass_color), west_center + Vector3(1 * scale, 2.5, 3 * scale))
	_add_mesh(body, _cyl_mesh(4 * scale, 6 * scale, 2.5), _mat(dark_grass), west_center + Vector3(-2 * scale, 4.5, -2 * scale))
	_add_mesh(body, _cyl_mesh(3 * scale, 4.5 * scale, 2.0), _mat(dark_grass.lerp(grass_color, 0.3)), west_center + Vector3(0, 4.0, 4 * scale))
	_add_mesh(body, _cyl_mesh(2 * scale, 3.5 * scale, 2.0), _mat(rock_color.darkened(0.1)), west_center + Vector3(-2.5 * scale, 6.2, -1 * scale))

	_add_col_cylinder(body, 14 * scale, 8.0, west_center.y + 2.0, west_center)
	_add_col_box(body, Vector3(10 * scale, 6.0, 16 * scale), west_center + Vector3(2 * scale, 3.0, 4 * scale))

	var isthmus_center := Vector3(3 * scale, 0, -2 * scale)
	_add_mesh(body, _box_mesh(12 * scale, 2.5, 6 * scale), _mat(rock_color.lerp(grass_color, 0.4)), isthmus_center + Vector3(0, 1.2, 0))
	_add_mesh(body, _box_mesh(10 * scale, 1.5, 4 * scale), _mat(grass_color), isthmus_center + Vector3(0, 2.2, 0))
	_add_col_box(body, Vector3(12 * scale, 4.0, 6 * scale), isthmus_center + Vector3(0, 2.0, 0))

	var east_center := Vector3(18 * scale, 0, 2 * scale)
	_add_mesh(body, _cyl_mesh(14 * scale, 18 * scale, 1.2), _mat_alpha(Color(0.18, 0.42, 0.48, 0.35)), east_center + Vector3(0, -0.6, 0))
	_add_mesh(body, _box_mesh(20 * scale, 2.5, 18 * scale), _mat(rock_color.darkened(0.15)), east_center + Vector3(3 * scale, 1.0, 0))

	var wall_color: Color = Color(0.55, 0.5, 0.45)
	var wall_h: float = 4.0
	_add_mesh(body, _box_mesh(22 * scale, wall_h, 2.5 * scale), _mat(wall_color), east_center + Vector3(4 * scale, wall_h * 0.5, 9 * scale))
	_add_mesh(body, _box_mesh(2.5 * scale, wall_h, 16 * scale), _mat(wall_color), east_center + Vector3(14 * scale, wall_h * 0.5, 0))
	_add_mesh(body, _box_mesh(12 * scale, wall_h, 2.5 * scale), _mat(wall_color), east_center + Vector3(9 * scale, wall_h * 0.5, -8 * scale))

	_add_col_box(body, Vector3(22 * scale, wall_h + 2, 3 * scale), east_center + Vector3(4 * scale, wall_h * 0.5, 9 * scale))
	_add_col_box(body, Vector3(3 * scale, wall_h + 2, 16 * scale), east_center + Vector3(14 * scale, wall_h * 0.5, 0))
	_add_col_box(body, Vector3(12 * scale, wall_h + 2, 3 * scale), east_center + Vector3(9 * scale, wall_h * 0.5, -8 * scale))
	_add_mesh(body, _box_mesh(16 * scale, 0.5, 12 * scale), _mat(Color(0.25, 0.35, 0.4)), east_center + Vector3(5 * scale, -0.3, 0))
	_add_mesh(body, _box_mesh(8 * scale, 1.5, 10 * scale), _mat(rock_color.lerp(wall_color, 0.5)), east_center + Vector3(-2 * scale, 1.5, 0))

	var tower_color: Color = wall_color.lightened(0.1)
	_add_mesh(body, _cyl_mesh(2 * scale, 2.5 * scale, 6.0), _mat(tower_color), east_center + Vector3(14 * scale, 3.0, 8 * scale))
	_add_col_cylinder(body, 2.5 * scale, 6.0, 3.0, east_center + Vector3(14 * scale, 0, 8 * scale))
	_add_mesh(body, _cyl_mesh(2 * scale, 2.5 * scale, 6.0), _mat(tower_color), east_center + Vector3(14 * scale, 3.0, -8 * scale))
	_add_col_cylinder(body, 2.5 * scale, 6.0, 3.0, east_center + Vector3(14 * scale, 0, -8 * scale))

	var lh_pos := Vector3(5 * scale, 3.0, -10 * scale)
	_add_mesh(body, _cyl_mesh(4 * scale, 5 * scale, 2.0), _mat(rock_color), lh_pos + Vector3(0, -0.5, 0))
	_add_col_cylinder(body, 5 * scale, 3.0, lh_pos.y, lh_pos)
	var lh_h: float = 14.0
	_add_mesh(body, _cyl_mesh(1.2 * scale, 1.8 * scale, lh_h), _mat(lighthouse_white, 0.6), lh_pos + Vector3(0, lh_h * 0.5, 0))
	for stripe_y in [0.3, 0.55, 0.8]:
		_add_mesh(body, _cyl_mesh(1.3 * scale, 1.3 * scale, 1.2), _mat(lighthouse_red, 0.7), lh_pos + Vector3(0, lh_h * stripe_y, 0))
	_add_mesh(body, _cyl_mesh(1.5 * scale, 1.5 * scale, 2.5), _mat(Color(0.2, 0.2, 0.25)), lh_pos + Vector3(0, lh_h + 1.0, 0))
	_add_mesh(body, _sphere_mesh(1.2 * scale, 2.0), _mat(Color(1, 0.95, 0.6, 0.85), 0.2, 0.6), lh_pos + Vector3(0, lh_h + 2.2, 0))
	_add_col_cylinder(body, 2 * scale, lh_h + 4, lh_pos.y + lh_h * 0.5, lh_pos)

	var dock_start := east_center + Vector3(14 * scale, 0, 0)
	var dock_len: float = 20 * scale
	var dock_y: float = 1.2
	_add_mesh(body, _box_mesh(4 * scale, 0.5, dock_len), _mat(dock_wood, 0.88), dock_start + Vector3(dock_len * 0.5, dock_y, 0))
	_add_col_box(body, Vector3(4 * scale, 2.0, dock_len), dock_start + Vector3(dock_len * 0.5, dock_y, 0))
	
	for pz in [-0.4, -0.15, 0.15, 0.4]:
		for px_frac in [0.15, 0.4, 0.65, 0.9]:
			var piling_pos := dock_start + Vector3(dock_len * px_frac, 0, pz * 4 * scale)
			_add_mesh(body, _cyl_mesh(0.2 * scale, 0.2 * scale, 3.0), _mat(dock_wood.darkened(0.25)), piling_pos)
	_add_mesh(body, _box_mesh(8 * scale, 0.6, 8 * scale), _mat(dock_wood.lightened(0.05)), dock_start + Vector3(dock_len + 2 * scale, dock_y, 0))
	_add_col_box(body, Vector3(8 * scale, 2.0, 8 * scale), dock_start + Vector3(dock_len + 2 * scale, dock_y, 0))

	var palm_positions: Array[Vector3] = [
		west_center + Vector3(-8 * scale, 2.0, -5 * scale), west_center + Vector3(-10 * scale, 1.5, 2 * scale), west_center + Vector3(-5 * scale, 3.0, -8 * scale),
		west_center + Vector3(-3 * scale, 2.5, 6 * scale), west_center + Vector3(2 * scale, 2.0, 8 * scale), west_center + Vector3(-12 * scale, 1.0, 5 * scale),
		west_center + Vector3(-6 * scale, 4.0, 0), west_center + Vector3(-9 * scale, 3.5, -3 * scale), west_center + Vector3(0, 2.0, 10 * scale), west_center + Vector3(-4 * scale, 3.0, 3 * scale),
	]
	for palm_pos in palm_positions:
		_add_palm(body, palm_pos)
	_container.add_child(body)



func _build_small(pos: Vector3, idx: int) -> void:
	var body := _make_body("SmallIsland_%d" % idx, pos)
	var r: float = randf_range(4.0, 7.0); var h: float = randf_range(2.5, 5.0)
	_add_col_cylinder(body, r, h + 2.0, h * 0.3)
	_add_mesh(body, _cyl_mesh(r + 1.5, r + 3.0, 0.4), _mat_alpha(Color(0.3, 0.55, 0.55, 0.5)), Vector3(0, -0.2, 0))
	_add_mesh(body, _cyl_mesh(r, r + 1.0, 0.8), _mat(wet_sand), Vector3(0, 0.2, 0))
	_add_mesh(body, _sphere_mesh(r * 0.9, h), _mat(rock_color.lerp(sand_color, randf() * 0.3)), Vector3(0, h * 0.3, 0), Vector3(1, 0.8, 0.9 + randf() * 0.2))
	if randf() > 0.4: _add_mesh(body, _sphere_mesh(r * 0.35, h * 0.4), _mat(rock_color.darkened(0.15)), Vector3(randf_range(-0.5, 0.5), h * 0.55, randf_range(-0.5, 0.5)))
	_container.add_child(body)

func _find_pos(own_r: float) -> Vector3:
	for _try in range(200):
		var c := Vector3(randf_range(-spread_radius, spread_radius), 0, randf_range(-spread_radius, spread_radius))
		if c.length() < min_distance_from_origin + own_r: continue
		var ok := true
		for e in _placed: if c.distance_to(e) < min_island_spacing + own_r: ok = false; break
		if ok: return c
	return Vector3.INF

# Export vars for random gen (kept for small islands)
@export var num_small_islands: int = 15
@export var num_medium_islands: int = 0
@export var num_large_islands: int = 0
@export var spread_radius: float = 1200.0
@export var min_distance_from_origin: float = 300.0
@export var min_island_spacing: float = 150.0

func _add_dock(body: StaticBody3D, island_pos: Vector3, radius: float, angle_rad: float) -> void:
	var dock_dir = Vector3(sin(angle_rad), 0, cos(angle_rad))
	var dock_len = 15.0
	var mid = dock_dir * (radius + dock_len * 0.5)
	var pos_local = Vector3(mid.x, 1.0, mid.z)
	
	# Dock Mesh
	var dock_mesh = _add_mesh(body, _box_mesh(4.0, 0.5, dock_len), _mat(dock_wood), pos_local)
	dock_mesh.rotation.y = angle_rad
	
	# Dock Collision
	_add_col_box(body, Vector3(4.0, 1.0, dock_len), pos_local)
	
	# Visual Indicator: Lantern Post
	var post_pos = pos_local + dock_dir * (dock_len * 0.4) + Vector3(0, 1.5, 0)
	var light_pos = post_pos + Vector3(0, 0.5, 0)
	_add_mesh(body, _cyl_mesh(0.1, 0.1, 3.0), _mat(dock_wood), post_pos) # Post
	
	# Lantern Light (Green = Safe/Dock)
	var light := OmniLight3D.new()
	light.light_color = Color(0.2, 1.0, 0.4)
	light.light_energy = 2.0
	light.omni_range = 15.0
	light.position = light_pos
	body.add_child(light)
	
	# Floating Buoy nearby
	var buoy_pos = pos_local + dock_dir * 12.0 # Further out
	var buoy = _add_mesh(body, _sphere_mesh(0.8, 0.8), _mat(Color(0.8, 0.1, 0.1)), buoy_pos)
	buoy.position.y = 0.5
	
	body.set_meta("has_dock", true)
	body.set_meta("dock_world_offset", pos_local + dock_dir * 5.0)
	body.set_meta("dock_forward", dock_dir)

func _add_safe_zone_buffer(body: StaticBody3D, radius: float) -> void:
	# Invisible cylinder to prevent getting stuck in complex geometry
	# Acts as a "soft" collider for the boat hull
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = 10.0
	cs.shape = s
	cs.position = Vector3(0, -2, 0) # Below water mostly
	body.add_child(cs)

func _make_body(nm: String, pos: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new(); b.name = nm; b.position = pos; b.collision_layer = COLLISION_LAYER_ISLAND; b.collision_mask = 0
	return b

func _add_col_cylinder(body: StaticBody3D, r: float, h: float, y: float, offset: Vector3 = Vector3.ZERO) -> void:
	var cs := CollisionShape3D.new(); var s := CylinderShape3D.new(); s.radius = r; s.height = h
	cs.shape = s; cs.position = Vector3(offset.x, y, offset.z); body.add_child(cs)

func _add_col_sphere(body: StaticBody3D, r: float, pos: Vector3) -> void:
	var cs := CollisionShape3D.new(); var s := SphereShape3D.new(); s.radius = r
	cs.shape = s; cs.position = pos; body.add_child(cs)

func _add_col_box(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new(); var s := BoxShape3D.new(); s.size = size
	cs.shape = s; cs.position = pos; body.add_child(cs)


func _add_mesh(parent: Node3D, mesh: Mesh, mat: StandardMaterial3D, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat; mi.position = pos; mi.scale = scl
	parent.add_child(mi); return mi

func _mat(color: Color, rough: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.roughness = rough; m.metallic = metal; return m

func _mat_alpha(color: Color, rough: float = 0.7) -> StandardMaterial3D:
	var m := _mat(color, rough); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; return m

func _mat_emission(color: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(color); m.emission_enabled = true; m.emission = color; m.emission_energy_multiplier = energy; return m

func _sphere_mesh(r: float, h: float) -> SphereMesh:
	var m := SphereMesh.new(); m.radius = r; m.height = h; return m

func _cyl_mesh(tr: float, br: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new(); m.top_radius = tr; m.bottom_radius = br; m.height = h; return m

func _box_mesh(w: float, h: float, d: float) -> BoxMesh:
	var m := BoxMesh.new(); m.size = Vector3(w, h, d); return m

func _add_palm(parent: Node3D, base_pos: Vector3) -> void:
	var trunk_h: float = randf_range(5.0, 9.0); var lean: float = randf_range(-0.25, 0.25)
	var trunk_mi := _add_mesh(parent, _cyl_mesh(0.15, 0.35, trunk_h), _mat(palm_trunk, 0.95), base_pos + Vector3(lean, trunk_h * 0.4, 0))
	trunk_mi.rotation.z = lean * 2.0
	trunk_mi.rotation.y = randf()*TAU
	
	# Fronds
	for _l in range(randi_range(4, 6)):
		var a := randf() * TAU
		var leaf_mi := _add_mesh(parent, _sphere_mesh(1.6, 0.3), _mat(palm_leaf.lerp(dark_grass, randf() * 0.3), 0.85), base_pos + Vector3(cos(a) * 1.2, trunk_h * 0.9, sin(a) * 1.2))
		leaf_mi.rotation = Vector3(randf() * 0.5, a, randf() * 0.2)

func _add_vegetation_patch(parent: Node3D, center: Vector3, radius: float, count: int) -> void:
	for i in range(count):
		var offset = Vector3(randf_range(-1,1), 0, randf_range(-1,1)).normalized() * (randf() * radius)
		if randf() > 0.4:
			_add_palm(parent, center + offset)
		else:
			# Bush
			_add_mesh(parent, _sphere_mesh(1.5, 1.2), _mat(dark_grass), center + offset + Vector3(0, 0.5, 0))
		
func get_nearest_island(world_pos: Vector3) -> Dictionary:
	var best_dist := INF; var best_pos := Vector3.ZERO; var best_name := ""
	for child in _container.get_children():
		var d: float = world_pos.distance_to(child.global_position)
		if d < best_dist: best_dist = d; best_pos = child.global_position; best_name = child.name
	return {"position": best_pos, "distance": best_dist, "name": best_name}

func is_near_island(world_pos: Vector3, threshold: float = 40.0) -> bool:
	return get_nearest_island(world_pos).distance < threshold

func _register_dock_points() -> void:
	await get_tree().process_frame; var dock_sys = get_node_or_null("/root/World/DockingSystem") as DockingSystem
	if not dock_sys: return
	var harbor_dock_pos := Vector3(140 * 1.0, 1.5, 5); dock_sys.register_dock_point(harbor_dock_pos, Vector3(-1, 0, 0), "Harbor")
	for child in _container.get_children():
		if child.has_meta("has_dock") and child.get_meta("has_dock"):
			var offset: Vector3 = child.get_meta("dock_world_offset")
			var fwd: Vector3 = child.get_meta("dock_forward")
			var world_dock_pos: Vector3 = child.global_transform.origin + child.global_transform.basis * offset
			var world_fwd: Vector3 = child.global_transform.basis * fwd
			world_fwd.y = 0; world_fwd = world_fwd.normalized()
			dock_sys.register_dock_point(world_dock_pos, world_fwd, child.name)
	print("⚓ Registered %d dock points" % dock_sys._dock_points.size())

# ═══════════════════════════════════════════════════════════════════════════
# DOCK ZONE HELPER (for State Machine)
# ═══════════════════════════════════════════════════════════════════════════

func _add_dock_zone(island_body: StaticBody3D, island_pos: Vector3, radius: float, angle: float, dock_name: String = "Dock") -> void:
	"""Add a DockZone Area3D to an island"""
	var dock_zone = Area3D.new()
	dock_zone.name = dock_name
	dock_zone.set_script(load("res://scripts/systems/dock_zone.gd"))
	
	# Position dock zone on the edge of the island
	var offset = Vector3(sin(angle) * radius, 0, cos(angle) * radius)
	dock_zone.position = offset
	
	# Create collision shape for dock zone
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(15, 10, 15)  # Dock area size
	collision_shape.shape = box_shape
	collision_shape.position = Vector3(0, 5, 0)  # Centered vertically
	dock_zone.add_child(collision_shape)
	
	# Create spawn point marker
	var spawn_marker = Marker3D.new()
	spawn_marker.name = "SpawnPoint"
	spawn_marker.position = Vector3(0, 1, 5)  # Slightly in front of dock
	dock_zone.add_child(spawn_marker)
	
	island_body.add_child(dock_zone)
	
	# Connect to state manager if it exists
	var state_manager = get_tree().get_first_node_in_group("state_manager")
	if state_manager:
		dock_zone.boat_entered.connect(state_manager._on_dock_zone_entered)
		dock_zone.boat_exited.connect(state_manager._on_dock_zone_exited)
	
	print("  ⚓ Added dock zone: %s" % dock_name)

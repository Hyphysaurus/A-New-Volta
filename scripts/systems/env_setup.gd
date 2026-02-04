extends Node3D

## Builds the tropical sky, environment, ocean material, light, fog,
## and ambient audio at runtime. All elements shift with the 28-day cycle.

var _ocean_mat: ShaderMaterial
var _wind_system: Node3D
var _light_ref: DirectionalLight3D
var _env_ref: WorldEnvironment
var _sky_mat: ProceduralSkyMaterial
var _env: Environment

# Audio
var _ocean_player: AudioStreamPlayer
var _wind_player: AudioStreamPlayer
var _ocean_gen: AudioStreamGenerator
var _wind_gen: AudioStreamGenerator
var _ocean_playback: AudioStreamGeneratorPlayback
var _wind_playback: AudioStreamGeneratorPlayback
var _audio_phase_ocean: float = 0.0
var _audio_phase_wind: float = 0.0
var _storm_level: float = 0.0
var _boat: Node3D

# Audio Noises
var _ocean_noise: FastNoiseLite
var _wind_noise: FastNoiseLite


func _ready() -> void:
	_setup_environment()
	_setup_ocean_material()
	_setup_light()
	_setup_ambient_audio()
	_setup_stars()
	_setup_wildlife()
	print("🌴 Tropical environment ready (sky + fog + audio + stars + birds)")

# ═══════════════════════════════════════════════════════════════════════════
# ATMOSPHERE - STARS & WILDLIFE
# ═══════════════════════════════════════════════════════════════════════════
var _stars: GPUParticles3D
var _gulls: GPUParticles3D

func _setup_stars() -> void:
	# A particle field that follows the camera (conceptually)
	# We'll attach it to EnvSetup (which is at origin), but make the box huge.
	
	_stars = GPUParticles3D.new()
	_stars.name = "StarField"
	_stars.amount = 1500
	_stars.lifetime = 100.0 # Persistent
	_stars.explosiveness = 0.0 # Constant emission? No, just static field.
	# Actually for static stars, Emission Shape Box is best, pre-filled.
	
	var proc_mat := ParticleProcessMaterial.new()
	proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc_mat.emission_box_extents = Vector3(2000, 500, 2000) # Huge area
	proc_mat.gravity = Vector3.ZERO
	proc_mat.direction = Vector3.ZERO
	proc_mat.color = Color(1, 1, 1, 0) # Start invisible (fade in at night)
	
	_stars.process_material = proc_mat
	
	var mesh := QuadMesh.new()
	mesh.size = Vector2(4.0, 4.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.use_point_size = true
	mat.point_size = 4.0
	mesh.material = mat
	_stars.draw_pass_1 = mesh
	
	add_child(_stars)

func _setup_wildlife() -> void:
	# Seagulls orbiting high up
	_gulls = GPUParticles3D.new()
	_gulls.name = "Seagulls"
	_gulls.amount = 50
	_gulls.lifetime = 20.0
	_gulls.preprocess = 10.0
	
	var proc_mat := ParticleProcessMaterial.new()
	proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	proc_mat.emission_ring_radius = 40.0
	proc_mat.emission_ring_height = 10.0
	proc_mat.gravity = Vector3(0, 0, 0)
	proc_mat.turbulence_enabled = true
	proc_mat.turbulence_noise_strength = 2.0
	proc_mat.turbulence_noise_scale = 5.0
	proc_mat.tangential_accel_min = 5.0 # Orbit
	proc_mat.tangential_accel_max = 10.0
	
	_gulls.process_material = proc_mat
	
	# Gull mesh - simple V shape (two tris)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Left wing
	st.set_color(Color(0.9, 0.9, 0.9))
	st.add_vertex(Vector3(0, 0, 0.5)) # Front
	st.add_vertex(Vector3(-0.5, 0.1, -0.2)) # Wing tip
	st.add_vertex(Vector3(0, 0, -0.3)) # Body back
	# Right wing
	st.add_vertex(Vector3(0, 0, -0.3))
	st.add_vertex(Vector3(0.5, 0.1, -0.2))
	st.add_vertex(Vector3(0, 0, 0.5))
	
	var gull_mesh = st.commit()
	var gull_mat = StandardMaterial3D.new()
	gull_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gull_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	gull_mesh.surface_set_material(0, gull_mat)
	
	_gulls.draw_pass_1 = gull_mesh
	
	# Attach to Boat if possible, otherwise World will do (but they won't follow)
	# Let's keep them in EnvSetup but move them in process to follow boat approx
	# Attach to Boat if possible, otherwise World will do (but they won't follow)
	# Let's keep them in EnvSetup but move them in process to follow boat approx
	add_child.call_deferred(_gulls)

func _update_atmosphere(_dt: float) -> void:
	if not _light_ref: return
	
	# Determine if it's night (Sun below horizon)
	# We mapped Sun X rot: 0 (Sunrise) -> -90 (Noon) -> -180 (Sunset)
	# So Night is when X > 0 or X < -180... wait.
	# logic used was: day_p < 0.5 (day), > 0.5 (night)
	
	var ts = get_node_or_null("/root/TimeSystem")
	if ts:
		if _stars:
			# Fade stars in at night
			if ts.day_progress > 0.45 or ts.day_progress < 0.1:
				_stars.visible = true
			else:
				_stars.visible = false
		
		# Rotate sun based on day progress
		if _light_ref:
			var day_p = ts.day_progress
			var rot_x = -90 # Default noon
			var energy = 0.0
			
			if (day_p >= 0.2 and day_p <= 0.8):
				# DAY
				var sun_t = (day_p - 0.2) / 0.6 # 0..1 during day
				rot_x = lerpf(-10, -170, sun_t) # -10 to -170
				energy = sin(sun_t * PI) * 2.5
			else:
				# NIGHT
				rot_x = -60 # Static moon or under
				energy = 0.1 # Moonlight
			
			_light_ref.rotation_degrees.x = rot_x
			_light_ref.light_energy = energy
	
	# Move gulls to follow boat
	if _boat and _gulls:
		_gulls.global_position = _boat.global_position + Vector3(0, 30, 0)

func _setup_environment() -> void:
	var we: WorldEnvironment = get_node_or_null("../WorldEnvironment")
	if not we:
		return

	_sky_mat = ProceduralSkyMaterial.new()
	# Rich tropical sky — vivid blue top, warm golden horizon
	_sky_mat.sky_top_color = Color(0.18, 0.45, 0.88)
	_sky_mat.sky_horizon_color = Color(0.62, 0.78, 0.95)
	_sky_mat.sky_curve = 0.08
	_sky_mat.sky_energy_multiplier = 1.2
	_sky_mat.ground_bottom_color = Color(0.08, 0.14, 0.28)
	_sky_mat.ground_horizon_color = Color(0.5, 0.68, 0.85)
	_sky_mat.ground_curve = 0.04
	_sky_mat.sun_angle_max = 35.0
	_sky_mat.sun_curve = 0.06

	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256

	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky

	# Ambient lighting from sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_color = Color(0.82, 0.88, 1.0)
	_env.ambient_light_energy = 0.75

	# Tonemapping for cinematic look
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_white = 5.0

	# Glow for sun bloom
	_env.glow_enabled = true
	_env.glow_intensity = 0.4
	_env.glow_strength = 0.8
	_env.glow_bloom = 0.15
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# ── Fog — depth-based with density falloff ──
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.65, 0.78, 0.9)
	_env.fog_light_energy = 0.6
	_env.fog_sun_scatter = 0.5
	_env.fog_density = 0.0004          ## Clearer for navigation
	_env.fog_sky_affect = 0.4          ## Sky bleeds into fog
	_env.fog_aerial_perspective = 0.3  ## Distant objects get hazier

	# Depth fog — main distance fade
	_env.fog_depth_begin = 80.0
	_env.fog_depth_end = 500.0

	# ── Volumetric fog — atmospheric depth ──
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.005
	_env.volumetric_fog_albedo = Color(0.7, 0.8, 0.9)
	_env.volumetric_fog_emission = Color(0.3, 0.4, 0.5)
	_env.volumetric_fog_emission_energy = 0.15
	_env.volumetric_fog_anisotropy = 0.6     ## Forward scattering (sun glow through fog)
	_env.volumetric_fog_length = 300.0
	_env.volumetric_fog_detail_spread = 0.8
	_env.volumetric_fog_ambient_inject = 0.2

	# SSAO for grounding
	_env.ssao_enabled = true
	_env.ssao_radius = 2.0
	_env.ssao_intensity = 0.8

	we.environment = _env
	_env_ref = we

func _setup_ocean_material() -> void:
	var ocean_node: Node3D = get_node_or_null("../Ocean/OceanMesh")
	if not ocean_node:
		return

	# We don't overwrite the mesh now, but we prepare the material
	var shader := Shader.new()
	shader.code = _get_ocean_shader_code()

	var mat := ShaderMaterial.new()
	mat.shader = shader
	# material_override needs to be applied to the MeshInstance3D nodes inside
	_apply_ocean_material_recursive(ocean_node, mat)

	var wind := get_node_or_null("../WindSystem")
	if wind:
		_ocean_mat = mat
		_wind_system = wind

func _apply_ocean_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_ocean_material_recursive(child, mat)

var _region_system: Node

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	_generate_audio(delta)
	_update_atmosphere(delta)
	
	if not _boat:
		_boat = get_tree().get_first_node_in_group("boat")
	
	if not _wind_system:
		_wind_system = get_node_or_null("/root/World/WindSystem")
	
	# Find region system if not yet connected
	if not _region_system:
		_region_system = get_node_or_null("../RegionSystem")
	
	# Ocean shader — feed wind data
	if _ocean_mat and _wind_system:
		_ocean_mat.set_shader_parameter("wind_direction", _wind_system.wind_direction)
		_ocean_mat.set_shader_parameter("wind_strength", _wind_system.wind_strength / _wind_system.base_strength)
		if _wind_system.has_method("get_storm_intensity"):
			_storm_level = _wind_system.get_storm_intensity()
			_ocean_mat.set_shader_parameter("storm_intensity", _storm_level)
	
	# Region colors — feed to ocean shader for smooth transitions
	if _ocean_mat and _region_system:
		var colors: Dictionary = _region_system.get_ocean_colors()
		_ocean_mat.set_shader_parameter("deep_color", _color_to_vec3(colors.deep_color))
		_ocean_mat.set_shader_parameter("mid_color", _color_to_vec3(colors.mid_color))
		_ocean_mat.set_shader_parameter("shallow_color", _color_to_vec3(colors.shallow_color))
		_ocean_mat.set_shader_parameter("crest_color", _color_to_vec3(colors.crest_color))
		
		# Adjust fog based on region
		if _env:
			var base_fog: float = _region_system.get_region_fog_density()
			# Storm intensity adds to base fog
			_env.fog_density = base_fog + _storm_level * 0.005

	# Audio generation
	_generate_audio(delta)



func _color_to_vec3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)

func _get_ocean_shader_code() -> String:
	return """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// Wave layers
uniform float wave_speed : hint_range(0.1, 4.0) = 1.2;
uniform float storm_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float cataclysm_intensity : hint_range(0.0, 1.0) = 0.0;

// Colors — fed from RegionSystem for zone-based variation
uniform vec3 deep_color : source_color = vec3(0.01, 0.06, 0.12);
uniform vec3 mid_color : source_color = vec3(0.02, 0.14, 0.24);
uniform vec3 shallow_color : source_color = vec3(0.06, 0.28, 0.38);
uniform vec3 crest_color : source_color = vec3(0.15, 0.42, 0.52);
uniform vec3 foam_color : source_color = vec3(0.88, 0.92, 0.96);

uniform vec3 wind_direction = vec3(0.0, 0.0, 1.0);
uniform float wind_strength = 1.0;

varying float wave_height;
varying float foam_factor;
varying vec3 world_pos;

// Gerstner wave with rolling crests
vec3 gerstner(vec2 pos, vec2 dir, float freq, float amp, float spd, float steep, float t) {
	float phase = dot(pos, dir) * freq + t * spd;
	float s = sin(phase);
	float c = cos(phase);
	return vec3(dir.x * amp * steep * c, amp * s, dir.y * amp * steep * c);
}

// Layered noise for surface detail
float noise2D(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float smoothNoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = noise2D(i);
	float b = noise2D(i + vec2(1.0, 0.0));
	float c = noise2D(i + vec2(0.0, 1.0));
	float d = noise2D(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, float t) {
	float value = 0.0;
	float amp = 0.5;
	p += t * 0.02;
	for (int i = 0; i < 4; i++) {
		value += amp * smoothNoise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return value;
}

float get_height(vec2 pos, float t) {
	float storm = 1.0 + storm_intensity * 2.5;

	// Primary swells
	vec2 d1 = normalize(wind_direction.xz + vec2(0.1, 0.0));
	float h = gerstner(pos, d1, 0.025, 1.2 * storm, wave_speed * 0.7, 0.7, t).y;

	// Secondary swells at angle
	vec2 d2 = normalize(wind_direction.xz + vec2(0.6, 0.4));
	h += gerstner(pos, d2, 0.04, 0.7 * storm, wave_speed * 0.9, 0.55, t).y;

	// Cross-chop
	h += gerstner(pos, vec2(0.8, -0.6), 0.07, 0.35 * storm, wave_speed * 1.3, 0.4, t).y;
	h += gerstner(pos, vec2(-0.5, 0.85), 0.1, 0.2 * storm, wave_speed * 1.6, 0.3, t).y;

	// Fine detail ripples
	h += sin(pos.x * 0.2 + pos.y * 0.15 + t * 2.0) * 0.08 * storm;
	h += sin(pos.x * 0.35 - pos.y * 0.28 + t * 2.8) * 0.05 * storm;

	// FBM surface texture
	h += (fbm(pos * 0.015, t) - 0.5) * 0.3 * storm;

	return h;
}

vec3 get_displacement(vec2 pos, float t) {
	float storm = 1.0 + storm_intensity * 2.5;
	vec2 d1 = normalize(wind_direction.xz + vec2(0.1, 0.0));
	vec3 disp = gerstner(pos, d1, 0.025, 1.2 * storm, wave_speed * 0.7, 0.7, t);
	vec2 d2 = normalize(wind_direction.xz + vec2(0.6, 0.4));
	disp += gerstner(pos, d2, 0.04, 0.7 * storm, wave_speed * 0.9, 0.55, t);
	disp += gerstner(pos, vec2(0.8, -0.6), 0.07, 0.35 * storm, wave_speed * 1.3, 0.4, t);
	return disp;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;

	vec3 disp = get_displacement(world_pos.xz, t);
	VERTEX.x += disp.x * 0.25;
	VERTEX.y += disp.y;
	VERTEX.z += disp.z * 0.25;
	wave_height = disp.y;

	// Foam on crests
	float storm = 1.0 + storm_intensity * 2.5;
	foam_factor = smoothstep(0.4 * storm, 0.9 * storm, wave_height);
	foam_factor += smoothstep(0.2, 0.5, wave_height) * 0.25;

	// Normal from gradient
	float eps = 0.35;
	float hc = get_height(world_pos.xz, t);
	float hx = get_height(world_pos.xz + vec2(eps, 0.0), t);
	float hz = get_height(world_pos.xz + vec2(0.0, eps), t);
	NORMAL = normalize(vec3(hc - hx, eps * 0.4, hc - hz));
}

void fragment() {
	// Wave height drives color bands with sharper transitions
	float h = clamp(wave_height * 0.6 + 0.5, 0.0, 1.0);
	vec3 base = deep_color;
	base = mix(base, mid_color, smoothstep(0.15, 0.35, h));
	base = mix(base, shallow_color, smoothstep(0.35, 0.55, h));
	base = mix(base, crest_color, smoothstep(0.55, 0.75, h));
	
	// Cataclysm Shift (Boiling Red)
	vec3 boil_color = vec3(0.9, 0.3, 0.1);
	base = mix(base, boil_color, cataclysm_intensity * 0.8);

	// Surface texture variation
	float surface_noise = fbm(world_pos.xz * 0.08, TIME * 0.3);
	base = mix(base, base * 1.15, surface_noise * 0.3);

	// Foam — bright streaks on crests
	float foam_noise = noise2D(world_pos.xz * 0.3 + TIME * 0.5);
	float foam = foam_factor * (0.5 + foam_noise * 0.5);
	foam += smoothstep(0.6, 1.1, wave_height) * 0.5;
	// Foam streaks in wind direction
	float streak = sin(dot(world_pos.xz, wind_direction.xz) * 0.8 + TIME) * 0.5 + 0.5;
	foam += streak * foam_factor * 0.3;
	base = mix(base, foam_color, clamp(foam, 0.0, 0.9));

	// Subsurface scattering simulation — light through wave peaks
	float sss = smoothstep(0.3, 0.8, wave_height) * 0.15;
	base += vec3(0.0, sss * 0.4, sss * 0.5);

	// Caustic shimmer
	float caustic = sin(world_pos.x * 0.25 + TIME * 0.6) * sin(world_pos.z * 0.2 + TIME * 0.4);
	caustic = caustic * caustic * 0.12;
	base += vec3(caustic * 0.4, caustic * 0.7, caustic * 0.9);

	// Fresnel rim — horizon glow
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 5.0);
	vec3 horizon_color = crest_color * 1.5 + vec3(0.1, 0.15, 0.2);
	base = mix(base, horizon_color, fresnel * 0.45);

	ALBEDO = base;
	ROUGHNESS = 0.06 + storm_intensity * 0.08;
	METALLIC = 0.3;
	SPECULAR = 1.0;
	ALPHA = 0.96;
}
"""

func _setup_light() -> void:
	var light: DirectionalLight3D = get_node_or_null("../DirectionalLight3D")
	if not light:
		return
	light.light_color = Color(1.0, 0.95, 0.85)
	light.light_energy = 2.5
	light.shadow_enabled = true
	_light_ref = light

	# Connect to TimeSystem for weather progression
	var ts = get_node_or_null("/root/TimeSystem")
	if not ts:
		ts = get_node_or_null("../TimeSystem")
	if ts and ts.has_signal("day_advanced"):
		ts.day_advanced.connect(_on_day_advanced)
		ts.cataclysm_building.connect(_on_cataclysm_building)
		_on_day_advanced(ts.cycle_day, ts.cycle_count)

func _on_day_advanced(cycle_day: int, _cycle_count: int) -> void:
	var progress: float = float(cycle_day) / 28.0

	# Light shifts
	if _light_ref:
		_light_ref.light_energy = lerpf(2.5, 1.4, clampf((progress - 0.4) * 2.5, 0.0, 1.0))
		_light_ref.light_color = Color(1.0, 0.95, 0.85).lerp(
			Color(0.65, 0.65, 0.75), clampf((progress - 0.4) * 2.5, 0.0, 1.0))

	# Sky — tropical to overcast
	if _sky_mat:
		var t: float = clampf((progress - 0.4) * 2.5, 0.0, 1.0)
		_sky_mat.sky_top_color = Color(0.18, 0.45, 0.88).lerp(Color(0.25, 0.28, 0.38), t)
		_sky_mat.sky_horizon_color = Color(0.62, 0.78, 0.95).lerp(Color(0.4, 0.42, 0.5), t)
		_sky_mat.sky_energy_multiplier = lerpf(1.2, 0.6, t)
		_sky_mat.ground_horizon_color = Color(0.5, 0.68, 0.85).lerp(Color(0.35, 0.38, 0.45), t)

	# Fog management (Region + Time)
	var base_fog := 0.0002
	var sky_energy_mult := 1.0
	
	if _region_system:
		base_fog = _region_system.get_region_fog_density()
		sky_energy_mult = _region_system.get_region_sky_energy()
	
	if _env:
		# Night thickens fog slightly, morning clears it
		var time_fog_mod: float = 1.0
		if progress > 0.6: time_fog_mod = 1.5 # Thicker at night
		elif progress < 0.2: time_fog_mod = 0.8 # Clearer in morning
		
		_env.fog_density = base_fog * time_fog_mod
		
		# Sky colors (Basic day cycle interpolation)
		# NOTE: Ideally RegionSystem would provide these colors too for full control
		if _sky_mat:
			var t: float = clampf((progress - 0.4) * 2.5, 0.0, 1.0)
			_sky_mat.sky_top_color = Color(0.18, 0.45, 0.88).lerp(Color(0.25, 0.28, 0.38), t)
			_sky_mat.sky_horizon_color = Color(0.62, 0.78, 0.95).lerp(Color(0.4, 0.42, 0.5), t)
			_sky_mat.sky_energy_multiplier = lerpf(1.2, 0.6, t) * sky_energy_mult
			_sky_mat.ground_horizon_color = Color(0.5, 0.68, 0.85).lerp(Color(0.35, 0.38, 0.45), t)

	# Pass cataclysm intensity to shader
	if _ocean_mat:
		var ts = get_node_or_null("/root/TimeSystem")
		if ts:
			_ocean_mat.set_shader_parameter("cataclysm_intensity", ts.cataclysm_intensity)

func _on_cataclysm_building(intensity: float) -> void:
	# Dramatic cataclysm progression
	if _light_ref:
		_light_ref.light_energy = lerpf(1.6, 0.6, intensity)
		_light_ref.light_color = Color(0.75, 0.7, 0.72).lerp(Color(0.45, 0.35, 0.5), intensity)

	if _sky_mat:
		_sky_mat.sky_top_color = Color(0.25, 0.28, 0.38).lerp(Color(0.15, 0.1, 0.2), intensity)
		_sky_mat.sky_horizon_color = Color(0.4, 0.42, 0.5).lerp(Color(0.35, 0.25, 0.3), intensity)
		_sky_mat.sky_energy_multiplier = lerpf(0.6, 0.25, intensity)

	if _env:
		_env.fog_density = lerpf(0.004, 0.012, intensity)
		_env.fog_light_color = Color(0.4, 0.42, 0.48).lerp(Color(0.3, 0.22, 0.28), intensity)
		_env.fog_depth_begin = lerpf(30.0, 10.0, intensity)
		_env.volumetric_fog_density = lerpf(0.025, 0.06, intensity)
		_env.volumetric_fog_emission_energy = lerpf(0.15, 0.5, intensity)
		_env.ambient_light_energy = lerpf(0.45, 0.2, intensity)

# ═══════════════════════════════════════════════════════════════════════════

# AMBIENT AUDIO — procedural ocean + wind via AudioStreamGenerator
# ═══════════════════════════════════════════════════════════════════════════
func _setup_ambient_audio() -> void:
	# Initialize FastNoiseLite
	_ocean_noise = FastNoiseLite.new()
	_ocean_noise.seed = randi()
	_ocean_noise.frequency = 0.02
	_ocean_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	
	_wind_noise = FastNoiseLite.new()
	_wind_noise.seed = randi()
	_wind_noise.frequency = 0.05
	_wind_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED

	# Ocean waves
	_ocean_gen = AudioStreamGenerator.new()
	_ocean_gen.mix_rate = 44100
	_ocean_gen.buffer_length = 0.1

	_ocean_player = AudioStreamPlayer.new()
	_ocean_player.name = "OceanAmbience"
	_ocean_player.stream = _ocean_gen
	_ocean_player.volume_db = 2.0
	add_child(_ocean_player)
	_ocean_player.play()
	_ocean_playback = _ocean_player.get_stream_playback() as AudioStreamGeneratorPlayback

	# Wind
	_wind_gen = AudioStreamGenerator.new()
	_wind_gen.mix_rate = 44100
	_wind_gen.buffer_length = 0.1

	_wind_player = AudioStreamPlayer.new()
	_wind_player.name = "WindAmbience"
	_wind_player.stream = _wind_gen
	_wind_player.volume_db = -2.0
	add_child(_wind_player)
	_wind_player.play()
	_wind_playback = _wind_player.get_stream_playback() as AudioStreamGeneratorPlayback

	print("🔊 High-Def Ambient audio started (ocean + wind)")

func _generate_audio(_delta: float) -> void:
	_fill_ocean_buffer()
	_fill_wind_buffer()

func _fill_ocean_buffer() -> void:
	if not _ocean_playback: return
	var frames: int = _ocean_playback.get_frames_available()
	if frames <= 0: return
	var rate: float = 44100.0
	var storm_vol: float = 1.0 + _storm_level * 1.5

	# Buffer filling
	var data = PackedVector2Array()
	data.resize(frames)
	
	for i in range(frames):
		_audio_phase_ocean += 1.0 / rate
		var t: float = _audio_phase_ocean
		
		# Use FastNoiseLite for roar
		var roar = _ocean_noise.get_noise_1d(t * 80.0) * 0.5
		var wash = _ocean_noise.get_noise_1d(t * 200.0 + 500.0) * 0.3
		
		# Rhythmic swelling
		var swell = sin(t * 0.2 * TAU) * 0.5 + 0.5
		
		var sample = (roar + wash * swell) * 0.4 * storm_vol
		data[i] = Vector2(sample, sample)
		
	_ocean_playback.push_buffer(data)

func _fill_wind_buffer() -> void:
	if not _wind_playback: return
	var frames: int = _wind_playback.get_frames_available()
	if frames <= 0: return
	var rate: float = 44100.0
	
	var wind_vol: float = 0.3
	if _wind_system:
		wind_vol = clampf(_wind_system.wind_strength / 5.0, 0.15, 1.0)
	wind_vol *= (1.0 + _storm_level * 1.0)
	
	var data = PackedVector2Array()
	data.resize(frames)

	for i in range(frames):
		_audio_phase_wind += 1.0 / rate
		var t: float = _audio_phase_wind
		
		# High pitched wind noise
		var base = _wind_noise.get_noise_1d(t * 400.0) * 0.4
		var gust = _wind_noise.get_noise_1d(t * 50.0) * 0.5 + 0.5
		
		var sample = base * gust * wind_vol * 0.5
		data[i] = Vector2(sample, sample)
		
	_wind_playback.push_buffer(data)


extends Node3D
class_name RegionSystem

## World region management system.
##
## Defines 5 distinct regions with unique visual identities:
## - Inner Sea (safe harbor zone, teal waters)
## - Trade Wind Corridor (structured routes, deep blue)
## - Shattered Reef Belt (dangerous fragmented zone, murky green)
## - Tempest Expanse (storm-dominated, dark gray)
## - Far Horizon (mythic edge, pale ethereal)
##
## Tracks the boat's current region and provides color data
## to the ocean shader for smooth transitions.

enum Region {
	INNER_SEA,
	TRADE_WIND_CORRIDOR,
	SHATTERED_REEF_BELT,
	TEMPEST_EXPANSE,
	FAR_HORIZON
}

# ── Region definitions ──────────────────────────────────────────────────────
const REGION_DATA: Dictionary = {
	Region.INNER_SEA: {
		"name": "Inner Sea",
		"description": "Safe waters near the harbor",
		"deep_color": Color(0.01, 0.08, 0.14),
		"mid_color": Color(0.02, 0.18, 0.28),
		"shallow_color": Color(0.05, 0.32, 0.42),
		"crest_color": Color(0.12, 0.48, 0.55),
		"fog_density": 0.0002, # Very clear
		"sky_energy": 1.3,
	},
	Region.TRADE_WIND_CORRIDOR: {
		"name": "Trade Wind Corridor",
		"description": "Strong steady winds for swift travel",
		"deep_color": Color(0.008, 0.04, 0.12),
		"mid_color": Color(0.015, 0.10, 0.25),
		"shallow_color": Color(0.03, 0.20, 0.40),
		"crest_color": Color(0.08, 0.32, 0.52),
		"fog_density": 0.0008,
		"sky_energy": 1.1,
	},
	Region.SHATTERED_REEF_BELT: {
		"name": "Shattered Reef Belt",
		"description": "Treacherous waters full of hidden dangers",
		"deep_color": Color(0.02, 0.05, 0.04),
		"mid_color": Color(0.04, 0.10, 0.08),
		"shallow_color": Color(0.08, 0.18, 0.12),
		"crest_color": Color(0.15, 0.28, 0.18),
		"fog_density": 0.006, # Heavy fog
		"sky_energy": 0.75,
	},
	Region.TEMPEST_EXPANSE: {
		"name": "Tempest Expanse",
		"description": "Perpetual storms rage here",
		"deep_color": Color(0.015, 0.02, 0.05),
		"mid_color": Color(0.025, 0.04, 0.10),
		"shallow_color": Color(0.05, 0.08, 0.16),
		"crest_color": Color(0.10, 0.14, 0.25),
		"fog_density": 0.012, # Extremely dense
		"sky_energy": 0.45,
	},
	Region.FAR_HORIZON: {
		"name": "Far Horizon",
		"description": "The edge of the known world",
		"deep_color": Color(0.08, 0.10, 0.16),
		"mid_color": Color(0.14, 0.18, 0.26),
		"shallow_color": Color(0.22, 0.28, 0.38),
		"crest_color": Color(0.35, 0.42, 0.52),
		"fog_density": 0.006,
		"sky_energy": 0.55,
	},
}

# ── State ───────────────────────────────────────────────────────────────────
var current_region: Region = Region.INNER_SEA
var _previous_region: Region = Region.INNER_SEA
var _boat: Node3D
var _blend_progress: float = 1.0  ## 0 = previous colors, 1 = current colors
var _discovered_regions: Dictionary = {
	Region.INNER_SEA: true,
	Region.TRADE_WIND_CORRIDOR: false,
	Region.SHATTERED_REEF_BELT: false,
	Region.TEMPEST_EXPANSE: false,
	Region.FAR_HORIZON: false,
}

@export var color_blend_speed: float = 0.5  ## How fast ocean color transitions

signal region_changed(new_region: Region, region_name: String)
signal region_discovered(region: Region, region_name: String)

func _ready() -> void:
	await get_tree().process_frame
	_boat = get_tree().get_first_node_in_group("boat")
	if not _boat:
		_boat = get_node_or_null("../Boat")
	print("🗺️ RegionSystem ready — 5 regions defined")

func _process(delta: float) -> void:
	if not _boat:
		return
	
	var new_region: Region = _get_region_at(_boat.global_position)
	
	if new_region != current_region:
		_previous_region = current_region
		current_region = new_region
		_blend_progress = 0.0
		
		var data: Dictionary = REGION_DATA[current_region]
		print("🗺️ Entered: %s" % data.name)
		region_changed.emit(current_region, data.name)
		
		# Check for first discovery
		if not _discovered_regions[current_region]:
			_discovered_regions[current_region] = true
			region_discovered.emit(current_region, data.name)
			print("✨ Discovered: %s" % data.name)
	
	# Blend colors over time
	if _blend_progress < 1.0:
		_blend_progress = minf(_blend_progress + delta * color_blend_speed, 1.0)

func _get_region_at(pos: Vector3) -> Region:
	var dist: float = Vector2(pos.x, pos.z).length()
	var angle: float = atan2(pos.z, pos.x)  ## Angle from +X axis
	
	# Inner Sea — circle around harbor (expanded)
	if dist < 150.0:
		return Region.INNER_SEA
	
	# Far Horizon — outer edge of the world (expanded)
	if dist > 550.0:
		return Region.FAR_HORIZON
	
	# Tempest Expanse — northwest quadrant (storms)
	if dist > 180.0 and angle > PI * 0.35 and angle < PI * 0.85:
		return Region.TEMPEST_EXPANSE
	
	# Shattered Reef Belt — northeast quadrant (dangers)
	if dist > 150.0 and angle > -PI * 0.35 and angle < PI * 0.35:
		return Region.SHATTERED_REEF_BELT
	
	# Trade Wind Corridor — southern arc (main routes)
	if dist > 120.0 and (angle < -PI * 0.35 or angle > PI * 0.85):
		return Region.TRADE_WIND_CORRIDOR
	
	# Default fallback
	return Region.INNER_SEA

# ── Public API ──────────────────────────────────────────────────────────────

## Returns blended ocean colors for the current transition state
func get_ocean_colors() -> Dictionary:
	var prev_data: Dictionary = REGION_DATA[_previous_region]
	var curr_data: Dictionary = REGION_DATA[current_region]
	var t: float = _blend_progress
	
	return {
		"deep_color": prev_data.deep_color.lerp(curr_data.deep_color, t),
		"mid_color": prev_data.mid_color.lerp(curr_data.mid_color, t),
		"shallow_color": prev_data.shallow_color.lerp(curr_data.shallow_color, t),
		"crest_color": prev_data.crest_color.lerp(curr_data.crest_color, t),
	}

## Returns current region data
func get_current_region_data() -> Dictionary:
	return REGION_DATA[current_region]

## Returns region name string
func get_region_name() -> String:
	return REGION_DATA[current_region].name

## Returns blend factor for fog/sky adjustments
func get_region_fog_density() -> float:
	var prev_data: Dictionary = REGION_DATA[_previous_region]
	var curr_data: Dictionary = REGION_DATA[current_region]
	return lerpf(prev_data.fog_density, curr_data.fog_density, _blend_progress)

func get_region_sky_energy() -> float:
	var prev_data: Dictionary = REGION_DATA[_previous_region]
	var curr_data: Dictionary = REGION_DATA[current_region]
	return lerpf(prev_data.sky_energy, curr_data.sky_energy, _blend_progress)

## Check if a region has been discovered
func is_region_discovered(region: Region) -> bool:
	return _discovered_regions.get(region, false)

## Get all discovered regions
func get_discovered_regions() -> Array:
	var result: Array = []
	for region in _discovered_regions:
		if _discovered_regions[region]:
			result.append(region)
	return result

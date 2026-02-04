extends Control
class_name ChartSystem

## A diegetic "Sea Chart" overlay.
## Divides the world (4000x4000) into 8x8 quadrants (500 units each).
## Tracks which quadrants have been visited.

const WORLD_SIZE = 4000
const GRID_CELLS = 8
const CELL_SIZE = 500 # WORLD_SIZE / GRID_CELLS

var _visited_cells: Dictionary = {} # "x,y" -> bool
var _player: Node3D
var _grid_container: GridContainer
var _cells: Array[ColorRect] = []
var _player_marker: ColorRect
var _m_was_down := false

func _ready() -> void:
	name = "ChartSystem"
	# Standard UI setup
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false 
	
	_build_ui()

func _build_ui() -> void:
	# Background (Parchment)
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.1, 0.08, 0.98)
	bg.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	bg.custom_minimum_size = Vector2(700, 700)
	bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bg.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(bg)
	
	# Title
	var title = Label.new()
	title.text = "SEA CHART of VOLTA DO MAR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.position.y += 10
	bg.add_child(title)

	# Grid Container (for revealed squares)
	_grid_container = GridContainer.new()
	_grid_container.columns = GRID_CELLS
	_grid_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var m = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_top", 50)
	m.add_theme_constant_override("margin_left", 50)
	m.add_theme_constant_override("margin_right", 50)
	m.add_theme_constant_override("margin_bottom", 50)
	bg.add_child(m)
	m.add_child(_grid_container)
	
	# Initial Secret Cells
	for y in range(GRID_CELLS):
		for x in range(GRID_CELLS):
			var cell = ColorRect.new()
			cell.custom_minimum_size = Vector2(600.0/GRID_CELLS, 600.0/GRID_CELLS)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
			cell.color = Color(0.15, 0.12, 0.1) 
			_grid_container.add_child(cell)
			_cells.append(cell)
			
	# Player Marker
	_player_marker = ColorRect.new()
	_player_marker.size = Vector2(12, 12)
	_player_marker.pivot_offset = Vector2(6,6)
	_player_marker.color = Color(1.0, 0.3, 0.2) # Crimson marker
	bg.add_child(_player_marker)
	
	# Heading arrow
	var arrow = ColorRect.new()
	arrow.size = Vector2(4, 16)
	arrow.position = Vector2(4, -8)
	arrow.color = Color(1, 1, 1)
	_player_marker.add_child(arrow)

func _process(_delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("boat")
		return
		
	# Update Visited
	var px = _player.global_position.x + (WORLD_SIZE * 0.5) 
	var pz = _player.global_position.z + (WORLD_SIZE * 0.5)
	
	var gx = int(px / CELL_SIZE)
	var gy = int(pz / CELL_SIZE)
	
	if gx >= 0 and gx < GRID_CELLS and gy >= 0 and gy < GRID_CELLS:
		var key = "%d,%d" % [gx, gy]
		if not _visited_cells.has(key):
			_visited_cells[key] = true
			_reveal_cell(gx, gy)
			
	# Update Player Visuals on Map
	if visible:
		var map_w = 600.0
		var mx = (px / WORLD_SIZE) * map_w + 50
		var mz = (pz / WORLD_SIZE) * map_w + 50
		_player_marker.position = Vector2(mx - 6, mz - 6)
		_player_marker.rotation = -_player.global_rotation.y
			
	# Input Toggle (Safe check for InputMap)
	var toggle = false
	if InputMap.has_action("toggle_map"):
		toggle = Input.is_action_just_pressed("toggle_map")
	else:
		toggle = Input.is_key_pressed(KEY_M) and not _m_was_down
		_m_was_down = Input.is_key_pressed(KEY_M)

	if toggle:
		visible = not visible

func _reveal_cell(gx: int, gy: int) -> void:
	var idx = gy * GRID_CELLS + gx
	if idx < _cells.size():
		_cells[idx].color = Color(0.8, 0.7, 0.55) 

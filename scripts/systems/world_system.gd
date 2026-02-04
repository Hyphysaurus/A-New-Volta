extends Node3D
class_name WorldSystem

@onready var ocean_mesh: Node3D = get_parent().get_node("Ocean")

func _ready():
	print("WorldSystem ready")

	await get_tree().process_frame
	
	# Inject CurrentSystem if missing
	if not get_node_or_null("CurrentSystem"):
		var cs = load("res://scripts/systems/current_system.gd").new()
		cs.name = "CurrentSystem"
		add_child(cs)
		
	# Inject ChartSystem (UI)
	var ui_layer = get_node_or_null("/root/World/UICanvasLayer")
	if ui_layer and not ui_layer.get_node_or_null("ChartSystem"):
		var ch = load("res://scripts/systems/chart_system.gd").new()
		ui_layer.add_child(ch)
		print("Reparented ChartSystem to UI")


	# Connect to autoload singleton
	TimeSystem.day_advanced.connect(_on_day_advanced)
	TimeSystem.cataclysm_building.connect(_on_cataclysm_building)
	TimeSystem.cataclysm_triggered.connect(_on_cataclysm_reset)

	print("✓ Connected to TimeSystem")

func _on_day_advanced(_day: int, _week: int) -> void:
	pass # Logic moved to EnvSetup

func _on_cataclysm_building(intensity: float) -> void:
	print("Intensity:", intensity)

func _on_cataclysm_reset() -> void:
	pass


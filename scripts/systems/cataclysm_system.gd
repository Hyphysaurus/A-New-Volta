extends Node
class_name CataclysmSystem

# Get references (siblings in World scene)
@onready var shrine_system = get_node("../ShrineSystem")
@onready var time_system = get_node("../TimeSystem")

func _ready():
	print("CataclysmSystem ready")
	if time_system:
		time_system.cataclysm_triggered.connect(_on_convergence)
		print("✓ Connected to TimeSystem cataclysm signal")

func _on_convergence():
	var active: bool = shrine_system.is_activated("trade_wind")
	
	if active:
		print("✓ Cycle stabilized. No cataclysm.")
	else:
		print("💥 CATASTROPHE: BOILING SEAS")
	
	# Reset the cycle - stabilized cycles don't increment, failed ones do
	time_system.reset_cycle(active)

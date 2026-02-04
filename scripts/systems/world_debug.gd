extends Node3D

@onready var time_system = get_node("../TimeSystem")

func _ready():
	print("World Debug Active")
	print("Press SPACE to advance day")

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			print("Advance action triggered")
			time_system.advance_day()

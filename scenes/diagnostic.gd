extends Node

## Simple diagnostic - checks if boat is set up correctly

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("\n========================================")
	print("VOLTA DIAGNOSTIC")
	print("========================================\n")
	
	var wind_system: Node = get_node_or_null("../WindSystem")
	if wind_system:
		print("✅ WindSystem found")
	else:
		print("❌ WindSystem NOT found")
	
	var boat: Node = get_node_or_null("../Boat")
	if not boat:
		print("❌ Boat NOT found")
	else:
		print("✅ Boat found at:", boat.global_position)
		
		if boat.global_position.y <= 0:
			print("   ❌ Boat is underwater! Y =", boat.global_position.y)
		else:
			print("   ✅ Boat above water, Y =", boat.global_position.y)
		
		if boat is RigidBody3D:
			var rb: RigidBody3D = boat as RigidBody3D
			print("   Mass:", rb.mass)
			print("   Freeze mode:", rb.freeze_mode, "(0=ok, 1=frozen)")
			
			if rb.freeze_mode != 0:
				print("   ❌ BOAT IS FROZEN!")
		
		var wind_path = boat.get("wind_system_path")
		if wind_path == NodePath(""):
			print("   ❌ Wind system path NOT SET!")
		else:
			print("   ✅ Wind path:", wind_path)
	
	print("\n========================================\n")
	
	await get_tree().create_timer(1.0).timeout
	queue_free()

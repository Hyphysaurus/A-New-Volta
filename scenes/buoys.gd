extends Node3D

## Adds floating reference objects (buoys) to ocean
## Attach this to your World node

@export var num_buoys: int = 30
@export var spread_radius: float = 100.0
@export var buoy_color: Color = Color(1, 0.5, 0)  # Orange

func _ready() -> void:
	_create_buoys()

func _create_buoys() -> void:
	for i in range(num_buoys):
		var buoy := MeshInstance3D.new()
		
		# Create buoy mesh (small sphere or cylinder)
		var mesh := SphereMesh.new()
		mesh.radius = 0.8
		mesh.height = 1.5
		buoy.mesh = mesh
		
		# Create material
		var material := StandardMaterial3D.new()
		material.albedo_color = buoy_color
		material.metallic = 0.3
		material.roughness = 0.7
		buoy.material_override = material
		
		# Random position on ocean
		var random_pos := Vector3(
			randf_range(-spread_radius, spread_radius),
			1.5,  # Float on water surface
			randf_range(-spread_radius, spread_radius)
		)
		buoy.position = random_pos
		
		add_child(buoy)
	
	print("✅ Created ", num_buoys, " reference buoys")

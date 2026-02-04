# New Island Meshes Needed

The following island meshes need to be added to this folder:

1. **eternal_sanctuary.glb** - Eternal Sanctuary island mesh
2. **overflow_island.glb** - Overflow Island mesh

Once these are added, update `island_system.gd` to load and position them in the world.

## Suggested Integration

Add methods similar to `_build_harbor_island()` and `_build_home_base_island()`:

```gdscript
func _build_eternal_sanctuary() -> void:
    var mesh_path := "res://assets/meshes/eternal_sanctuary.glb"
    var scene = load(mesh_path)
    if not scene: return
    
    var pos := Vector3(400, 5.0, -600)  # Adjust as needed
    var body := StaticBody3D.new()
    body.name = "EternalSanctuary"
    body.position = pos
    body.collision_layer = COLLISION_LAYER_ISLAND
    body.collision_mask = 0
    
    var mesh_inst = scene.instantiate()
    mesh_inst.scale = Vector3(50, 50, 50)  # Adjust scale
    body.add_child(mesh_inst)
    
    _add_col_cylinder(body, 40.0, 10.0, 2.0)
    _add_dock(body, pos, 45.0, 0.0)
    
    _container.add_child(body)
```

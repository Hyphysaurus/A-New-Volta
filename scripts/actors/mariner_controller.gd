extends CharacterBody3D
class_name MarinerController

## Player character controller for on-foot movement
## Only active when in ON_FOOT state

@export var move_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002

# Get the gravity from the project settings
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var camera_pivot: Node3D
var camera: Camera3D

func _ready() -> void:
	# Find or create camera pivot
	camera_pivot = get_node_or_null("CameraPivot")
	if not camera_pivot:
		camera_pivot = Node3D.new()
		camera_pivot.name = "CameraPivot"
		camera_pivot.position = Vector3(0, 1.6, 0)  # Eye height
		add_child(camera_pivot)
	
	camera = camera_pivot.get_node_or_null("Camera3D")
	
	# Disable by default (StateManager will enable)
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	# Get input direction
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Calculate movement direction relative to camera
	var direction := Vector3.ZERO
	if camera_pivot:
		var forward = -camera_pivot.global_transform.basis.z
		var right = camera_pivot.global_transform.basis.x
		forward.y = 0
		right.y = 0
		forward = forward.normalized()
		right = right.normalized()
		
		direction = (right * input_dir.x + forward * input_dir.y).normalized()
	
	# Apply movement
	var speed = sprint_speed if Input.is_action_pressed("sprint") else move_speed
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	# Mouse look (only when active)
	if not is_physics_processing():
		return
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Rotate body left/right
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Rotate camera up/down
		if camera_pivot:
			camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/2, PI/2)

func enable_control() -> void:
	set_physics_process(true)
	if camera:
		camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func disable_control() -> void:
	set_physics_process(false)
	velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

extends CharacterBody3D
# The player: walks, looks around with the mouse, jumps, and shoots.
# Stage 1 only - no health, no teams, no weapons list yet.

# --- Settings you can tweak in the Godot editor (Inspector panel) ---
@export var walk_speed: float = 6.0        # how fast we walk (metres per second)
@export var jump_speed: float = 5.0        # how strong a jump is
@export var mouse_sensitivity: float = 0.003  # how fast the camera turns
@export var fire_delay: float = 0.15       # seconds between shots
@export var shoot_range: float = 100.0     # how far a bullet can reach

# Gravity comes from the project's physics settings.
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Time left before we are allowed to shoot again.
var cooldown: float = 0.0

# Shortcuts to child nodes (the "$" means "find the child with this name").
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D


func _ready() -> void:
	# Hide the mouse cursor and lock it to the window so we can look around.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	# Mouse movement turns the camera.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Left/right: turn the whole body.
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Up/down: tilt only the head, and stop at straight up / straight down.
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	# Escape frees the mouse; clicking the window grabs it again.
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	# --- Gravity and jumping ---
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_speed

	# --- Walking ---
	# get_vector gives a direction from the W/A/S/D keys.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Turn that direction so "forward" means where the player is facing.
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed
	move_and_slide()

	# --- Shooting ---
	cooldown -= delta
	if Input.is_action_pressed("shoot") and cooldown <= 0.0 \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cooldown = fire_delay
		shoot()


func shoot() -> void:
	# Fire an invisible line (a "ray") from the camera straight ahead.
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z) * shoot_range
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]  # don't hit ourselves

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return  # we shot at the sky

	# We hit something: show a small orange dot where the bullet landed.
	spawn_hit_marker(hit["position"])


func spawn_hit_marker(position: Vector3) -> void:
	var marker := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.08
	ball.height = 0.16
	marker.mesh = ball

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.6, 0.1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # always bright
	marker.material_override = mat

	# Add it to the level (not to the player) so it stays where it landed.
	get_tree().current_scene.add_child(marker)
	marker.global_position = position

	# Remove the dot after a short time so they don't pile up.
	get_tree().create_timer(2.0).timeout.connect(marker.queue_free)

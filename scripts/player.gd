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

# Where we started. We go back here if we fall off the map or get stuck for good.
var spawn_position: Vector3

# A slightly smaller copy of our body, used only to check if we are inside a wall.
# (It is smaller so that standing on the floor or touching a wall doesn't count.)
var stuck_check_shape := CapsuleShape3D.new()

# Shortcuts to child nodes (the "$" means "find the child with this name").
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D


func _ready() -> void:
	spawn_position = global_position
	stuck_check_shape.radius = 0.35
	stuck_check_shape.height = 1.5
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

	# --- Safety: rooms move, so we might fall off the map or end up inside a wall ---
	if global_position.y < -20.0:
		respawn()
	elif is_stuck_at(global_position):
		push_to_safe_spot()

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


# --- Safety code for moving rooms ---

# Returns true if our (slightly smaller) body is inside something solid at this position.
func is_stuck_at(pos: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = stuck_check_shape
	# The check shape is centred 0.95 m above our feet.
	query.transform = Transform3D(Basis(), pos + Vector3(0, 0.95, 0))
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


# Moves us to the nearest free spot that has a floor under it.
func push_to_safe_spot() -> void:
	var space := get_world_3d().direct_space_state
	# Try rings around us: 1 metre away, then 2, then 3... up to 8.
	for distance in range(1, 9):
		for i in 8:
			var angle := i * TAU / 8.0
			var x := global_position.x + cos(angle) * distance
			var z := global_position.z + sin(angle) * distance
			# Look straight down from just above us to find the floor there.
			var top := Vector3(x, global_position.y + 2.5, z)
			var ray := PhysicsRayQueryParameters3D.create(top, top + Vector3(0, -8, 0))
			ray.exclude = [get_rid()]
			var hit := space.intersect_ray(ray)
			if hit.is_empty():
				continue  # no floor here
			var spot: Vector3 = hit["position"] + Vector3(0, 0.05, 0)
			if not is_stuck_at(spot):
				global_position = spot
				velocity = Vector3.ZERO
				return
	# Nowhere safe nearby: go back to the start.
	respawn()


# Puts us back where we started.
func respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO

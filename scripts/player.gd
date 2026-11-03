extends Fighter
# The player: walks, looks around with the mouse, jumps, and shoots.
# Team, health, damage, respawning and the "stuck in a wall" rescue all come
# from fighter.gd (the "extends Fighter" line above).

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

var health_label: Label   # "Health: 100" at the bottom-left
var dead_label: Label     # "DEFEATED" message in the middle


func _ready() -> void:
	super._ready()   # run the setup from fighter.gd first
	# Hide the mouse cursor and lock it to the window so we can look around.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_hud()
	health_changed.connect(_update_hud)
	_update_hud()


func _process(delta: float) -> void:
	super._process(delta)   # the respawn countdown lives in fighter.gd
	if is_dead:
		dead_label.text = "DEFEATED\nRespawning in %d" % ceili(respawn_left)
	dead_label.visible = is_dead


func _input(event: InputEvent) -> void:
	# (_input gets every event first, so mouse look keeps working while walking.)
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
	if is_dead:
		return   # defeated: no moving or shooting until we respawn

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

	# Rooms move, so we might fall off the map or end up inside a wall.
	safety_check()

	# --- Shooting ---
	cooldown -= delta
	if Input.is_action_pressed("shoot") and cooldown <= 0.0 \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cooldown = fire_delay
		shoot()


func shoot() -> void:
	# Fire from the camera straight ahead (shoot_ray is in fighter.gd).
	var hit := shoot_ray(camera.global_position, -camera.global_transform.basis.z, shoot_range)
	if not hit.is_empty():
		spawn_hit_marker(hit["position"])   # orange dot where the bullet landed


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


# Builds the health text and the "DEFEATED" message on the screen.
func _build_hud() -> void:
	var hud: CanvasLayer = $HUD
	health_label = Label.new()
	health_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	health_label.offset_left = 20
	health_label.offset_top = -60
	health_label.add_theme_font_size_override("font_size", 32)
	hud.add_child(health_label)

	dead_label = Label.new()
	dead_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dead_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dead_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	dead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dead_label.add_theme_font_size_override("font_size", 56)
	dead_label.modulate = Color(1, 0.3, 0.3)
	dead_label.visible = false
	hud.add_child(dead_label)


func _update_hud() -> void:
	health_label.text = "Health: %d" % health

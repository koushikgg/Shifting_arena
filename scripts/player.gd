extends Fighter
# The player: walks, looks around with the mouse, jumps, and shoots.
# Team, health, damage, respawning and the "stuck in a wall" rescue all come
# from fighter.gd (the "extends Fighter" line above).

# --- Settings you can tweak in the Godot editor (Inspector panel) ---
@export var walk_speed: float = 5.0        # base walking speed (metres per second); the role changes it
@export var jump_speed: float = 5.0        # how strong a jump is
@export var mouse_sensitivity: float = 0.003  # how fast the camera turns
@export var key_look_speed: float = 2.0    # how fast the J/L/I/K keys turn the camera (radians per second)
@export var fire_delay: float = 0.15       # base seconds between shots; the role can change it
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
var role_label: Label     # role and ability hints in the top-left corner
var notice_label: Label   # short messages like "Too far from your core"
var notice_left: float = 0.0
var map_view: MapView     # the Shift Controller's top-down map (made when first needed)


func _ready() -> void:
	super._ready()   # run the setup from fighter.gd first
	# Hide the mouse cursor and lock it to the window so we can look around.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("player")   # lets bots know which team the human is on
	camera.cull_mask = 1   # our own camera does not show the map markers (or our own head)
	# Give ourselves a human body: when you look down you see your arms, gun and legs.
	body_visual = Node3D.new()
	add_child(body_visual)
	var person := Humanoid.new()
	person.shirt_color = Team.color_of(team)
	person.mover = self
	person.first_person = true
	body_visual.add_child(person)
	_build_hud()
	health_changed.connect(_update_hud)
	role_changed.connect(_update_hud)
	_update_hud()


func _process(delta: float) -> void:
	super._process(delta)   # the respawn countdown lives in fighter.gd
	if is_dead:
		dead_label.text = "DEFEATED\nRespawning in %d" % ceili(respawn_left)
	dead_label.visible = is_dead
	if is_dead and map_view:
		map_view.close()
	_update_role_text()
	notice_left -= delta
	notice_label.visible = notice_left > 0.0


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

	# --- Looking with the keyboard (J/L = left/right, I/K = up/down) ---
	# Useful if the mouse stops working while you walk (e.g. touchpad "disable while typing").
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	rotate_y(-look.x * key_look_speed * delta)
	head.rotation.x = clamp(head.rotation.x - look.y * key_look_speed * delta,
			deg_to_rad(-89), deg_to_rad(89))

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
	var speed := walk_speed * role_speed_mult   # the role makes us faster or slower
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()

	# Rooms move, so we might fall off the map or end up inside a wall.
	safety_check()

	# --- Role abilities ---
	if role == Role.Type.DEFENDER and Input.is_action_just_pressed("place_turret"):
		# Put a turret 2 metres in front of us.
		var spot := global_position + (-transform.basis.z) * 2.0
		if turret_placer.try_place(spot):
			_notice("Turret placed")
		else:
			_notice(turret_placer.message)
	if role == Role.Type.SHIFT_CONTROLLER:
		if Input.is_action_just_pressed("toggle_map"):
			if map_view == null:
				map_view = MapView.new()
				add_child(map_view)
				map_view.setup(self, camera, $HUD)
			map_view.toggle()
		if Input.is_action_just_pressed("early_shift"):
			var manager = get_tree().get_first_node_in_group("shift_manager")
			if manager.call_early_shift(team):
				_notice("Early shift called!")
			else:
				_notice("Early shift not available")

	# --- Shooting ---
	cooldown -= delta
	if Input.is_action_pressed("shoot") and cooldown <= 0.0 \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cooldown = fire_delay * role_fire_delay_mult
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

	role_label = Label.new()
	role_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	role_label.offset_left = 20
	role_label.offset_top = 15
	role_label.add_theme_font_size_override("font_size", 26)
	hud.add_child(role_label)

	notice_label = Label.new()
	notice_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	notice_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	notice_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	notice_label.offset_top = 60
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_size_override("font_size", 28)
	notice_label.visible = false
	hud.add_child(notice_label)


func _update_hud() -> void:
	health_label.text = "Health: %d" % health


# Shows a short message in the middle of the screen for 2 seconds.
func _notice(text: String) -> void:
	notice_label.text = text
	notice_left = 2.0


# The small text in the top-left corner: our role and what its keys do.
func _update_role_text() -> void:
	var text := "%s - %s" % [Team.name_of(team).to_upper(), Role.name_of(role).to_upper()]
	if role == Role.Type.DEFENDER and turret_placer:
		var wait := ""
		if turret_placer.cooldown_left > 0.0:
			wait = "  (ready in %d)" % ceili(turret_placer.cooldown_left)
		text += "\n[T] Turret  %d/%d%s" % [turret_placer.active_count(), RoleSettings.TURRET_MAX, wait]
	elif role == Role.Type.SHIFT_CONTROLLER:
		var manager = get_tree().get_first_node_in_group("shift_manager")
		var left: int = manager.early_shifts_left(team) if manager else 0
		text += "\n[M] Map   [F] Early shift: %s" % ("READY" if left > 0 else "used")
	role_label.text = text
	role_label.modulate = Role.color_of(role)

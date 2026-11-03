extends Fighter
# A computer-controlled fighter. Simple behaviour:
#   1. Walk toward the enemy core (using Godot's navigation to find the way).
#   2. If an enemy player or bot is visible and close enough, stop and shoot it.
#   3. If we are defeated, fighter.gd respawns us at our base after 5 seconds.
# Bots never shoot teammates or their own core (fighter.gd / core.gd ignore same-team hits).

const SIGHT_RANGE := 25.0       # how far a bot can see enemies (metres)
const CORE_SHOOT_RANGE := 18.0  # how close a bot gets before shooting a core
const REPLAN_EVERY := 0.5       # seconds between "find me a new path" checks

# Difficulty numbers (the BotSpawner sets these; see difficulty.gd).
var settings: Dictionary = Difficulty.settings(Difficulty.Level.EASY)

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var agent: NavigationAgent3D   # finds a path around walls for us
var label: Label3D             # shows our health above our head
var shoot_cooldown: float = 0.0
var seen_time: float = 0.0     # how long we have been looking at an enemy
var replan_timer: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group("bots")
	_build_body()
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.8
	agent.target_desired_distance = 1.5
	add_child(agent)
	health_changed.connect(_update_label)
	_update_label()


# Called (by the NavManager) after every room shift: forget the old path.
func replan() -> void:
	replan_timer = 0.0


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	shoot_cooldown -= delta

	# Do we see an enemy? We only react after "reaction_time" seconds of seeing it.
	var enemy := _find_visible_enemy()
	if enemy:
		seen_time += delta
	else:
		seen_time = 0.0

	var core := _find_enemy_core()
	var core_point := Vector3.ZERO
	if core:
		core_point = core.global_position + Vector3(0, 1.25, 0)

	if enemy and seen_time >= settings["reaction_time"]:
		# 2. Stop and shoot the enemy.
		_stop_and_shoot(enemy.global_position + Vector3(0, 1.2, 0), delta)
	elif core and global_position.distance_to(core.global_position) <= CORE_SHOOT_RANGE \
			and _can_see(core_point, core):
		# Close enough to the core with a clear view: stop and shoot it.
		_stop_and_shoot(core_point, delta)
	else:
		# 1. Walk toward the enemy core.
		_walk_toward(core, delta)

	move_and_slide()
	safety_check()   # rescue us if a moving room traps us


# Where our eyes (and gun) are.
func _eye() -> Vector3:
	return global_position + Vector3(0, 1.5, 0)


# Returns the closest enemy fighter we can see, or null.
func _find_visible_enemy() -> Fighter:
	var best: Fighter = null
	var best_distance := SIGHT_RANGE
	for other in get_tree().get_nodes_in_group("fighters"):
		if other == self or other.team == team or other.is_dead:
			continue
		var distance := global_position.distance_to(other.global_position)
		if distance < best_distance and _can_see(other.global_position + Vector3(0, 1.2, 0), other):
			best = other
			best_distance = distance
	return best


func _find_enemy_core() -> Node3D:
	for core in get_tree().get_nodes_in_group("cores"):
		if core.team != team and not core.is_destroyed:
			return core
	return null


# True if a straight line from our eyes to "point" hits "target" first (nothing in the way).
func _can_see(point: Vector3, target: Node) -> bool:
	var query := PhysicsRayQueryParameters3D.create(_eye(), point)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == target


func _stop_and_shoot(point: Vector3, delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	var direction := point - _eye()
	_face(direction, delta)
	if shoot_cooldown > 0.0:
		return
	shoot_cooldown = settings["fire_delay"]

	# Bad aim: turn the shot a random small amount. Lower accuracy = bigger miss.
	var spread := deg_to_rad((1.0 - settings["accuracy"]) * 10.0)
	var side := direction.cross(Vector3.UP).normalized()
	var aim := direction.rotated(Vector3.UP, randf_range(-spread, spread))
	aim = aim.rotated(side, randf_range(-spread, spread))
	shoot_ray(_eye(), aim, SIGHT_RANGE + 5.0, true)


func _walk_toward(core: Node3D, delta: float) -> void:
	if core == null:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	# Every half second (and right after a shift) ask the navigation system for a fresh path.
	replan_timer -= delta
	if replan_timer <= 0.0:
		replan_timer = REPLAN_EVERY
		agent.target_position = core.global_position

	if agent.is_navigation_finished():
		velocity.x = 0.0   # reached the end of the path (or no path exists): wait here
		velocity.z = 0.0
		return

	var next_point := agent.get_next_path_position()
	var direction := next_point - global_position
	direction.y = 0.0
	direction = direction.normalized()
	velocity.x = direction.x * settings["speed"]
	velocity.z = direction.z * settings["speed"]
	_face(direction, delta)


# Smoothly turn to look in a direction.
func _face(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length() < 0.01:
		return
	var wanted := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, wanted, 8.0 * delta)


# Builds the bot's body: a coloured capsule, a "gun" so you can see where it faces,
# a health label, and the solid shape.
func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)

	body_visual = Node3D.new()   # fighter.gd hides this when we are defeated
	add_child(body_visual)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Team.color_of(team)

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.4
	body_mesh.height = 1.8
	body.mesh = body_mesh
	body.position = Vector3(0, 0.9, 0)
	body.material_override = mat
	body_visual.add_child(body)

	var gun := MeshInstance3D.new()
	var gun_mesh := BoxMesh.new()
	gun_mesh.size = Vector3(0.15, 0.15, 0.7)
	gun.mesh = gun_mesh
	gun.position = Vector3(0.3, 1.3, -0.5)
	gun.material_override = mat
	body_visual.add_child(gun)

	label = Label3D.new()
	label.position = Vector3(0, 2.3, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.01
	label.font_size = 40
	label.outline_size = 10
	label.modulate = Team.color_of(team).lightened(0.4)
	body_visual.add_child(label)


func _update_label() -> void:
	label.text = "%s BOT  %d" % [Team.name_of(team).to_upper(), health]

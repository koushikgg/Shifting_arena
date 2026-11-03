extends Fighter
# A computer-controlled fighter. What it does depends on its role:
#   ATTACKER:         walks toward the enemy core and shoots it.
#   DEFENDER:         stays near its own core, places turrets.
#   SHIFT CONTROLLER: stays safe at its base, and calls the early shift when an
#                     enemy stands in a room that is about to move.
# Every role: if an enemy is visible and in range, stop and shoot it.
# If we are defeated, fighter.gd respawns us at our base after 5 seconds.
# Bots never shoot teammates or their own core (fighter.gd / core.gd ignore same-team hits).

const SIGHT_RANGE := 25.0       # how far a bot can see enemies (metres)
const CORE_SHOOT_RANGE := 18.0  # how close an attacker gets before shooting a core
const REPLAN_EVERY := 0.5       # seconds between "find me a new path" checks
const GUARD_RADIUS := 3.0       # defenders/controllers stand still within this of their post

# Difficulty numbers (the BotSpawner sets these; see difficulty.gd).
var settings: Dictionary = Difficulty.settings(Difficulty.Level.EASY)

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var agent: NavigationAgent3D   # finds a path around walls for us
var label: Label3D             # shows our team, role and health above our head
var hat: MeshInstance3D        # a little block above the head, coloured by role
var shoot_cooldown: float = 0.0
var seen_time: float = 0.0     # how long we have been looking at an enemy
var replan_timer: float = 0.0
var turret_retry: float = 0.0  # defenders: wait a moment between placement tries
var early_check_timer: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group("bots")
	_build_body()
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.8
	agent.target_desired_distance = 1.5
	add_child(agent)
	health_changed.connect(_update_label)
	role_changed.connect(_update_label)
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

	if enemy and seen_time >= settings["reaction_time"]:
		# Stop and shoot the enemy (any role).
		_stop_and_shoot(enemy.global_position + Vector3(0, 1.2, 0), delta)
	else:
		match role:
			Role.Type.ATTACKER:
				_act_as_attacker(delta)
			Role.Type.DEFENDER:
				_act_as_defender(delta)
			_:
				_act_as_shift_controller(delta)

	move_and_slide()
	safety_check()   # rescue us if a moving room traps us


# --- The three roles ---

func _act_as_attacker(delta: float) -> void:
	var core := _find_core(false)
	if core == null:
		_stand_still()
		return
	var core_point := core.global_position + Vector3(0, 1.25, 0)
	if global_position.distance_to(core.global_position) <= CORE_SHOOT_RANGE \
			and _can_see(core_point, core):
		_stop_and_shoot(core_point, delta)   # close enough with a clear view: shoot the core
	else:
		_walk_to(core.global_position, delta)   # walk toward the enemy core


func _act_as_defender(delta: float) -> void:
	var own_core := _find_core(true)
	if own_core == null:
		_stand_still()
		return

	# Place turrets near our core whenever we are allowed to.
	turret_retry -= delta
	if turret_placer and turret_retry <= 0.0 and turret_placer.can_place():
		turret_retry = 1.0
		# First turret on the side toward our base, the second to the side of that.
		var toward_base := (spawn_position - own_core.global_position)
		toward_base.y = 0.0
		var angle := atan2(toward_base.z, toward_base.x) + turret_placer.active_count() * PI / 2.0
		turret_placer.try_place(own_core.global_position + Vector3(cos(angle), 0, sin(angle)) * 3.5)

	# Stay between our core and our base.
	var toward := (spawn_position - own_core.global_position)
	toward.y = 0.0
	_guard(own_core.global_position + toward.normalized() * 4.0, delta)


func _act_as_shift_controller(delta: float) -> void:
	# Look for a chance to spring the trap (twice a second is plenty).
	early_check_timer -= delta
	if early_check_timer <= 0.0:
		early_check_timer = 0.5
		var manager = get_tree().get_first_node_in_group("shift_manager")
		if manager and manager.can_call_early(team) and manager.enemy_in_next_moving_room(team):
			manager.call_early_shift(team)
	# Stay safe at our base.
	_guard(spawn_position, delta)


# --- Helpers ---

# Where our eyes (and gun) are.
func _eye() -> Vector3:
	return global_position + Vector3(0, 1.5, 0)


# Returns the closest enemy (player, bot or turret) we can see, or null.
func _find_visible_enemy() -> Node3D:
	var best: Node3D = null
	var best_distance := SIGHT_RANGE
	for other in get_tree().get_nodes_in_group("fighters"):
		if other == self or other.team == team or other.is_dead:
			continue
		var distance := global_position.distance_to(other.global_position)
		if distance < best_distance and _can_see(other.global_position + Vector3(0, 1.2, 0), other):
			best = other
			best_distance = distance
	return best


# Finds our own core (own = true) or the enemy's core (own = false).
func _find_core(own: bool) -> Node3D:
	for core in get_tree().get_nodes_in_group("cores"):
		if (core.team == team) == own and not core.is_destroyed:
			return core
	return null


# True if a straight line from our eyes to "point" hits "target" first (nothing in the way).
func _can_see(point: Vector3, target: Node) -> bool:
	var query := PhysicsRayQueryParameters3D.create(_eye(), point)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == target


func _stop_and_shoot(point: Vector3, delta: float) -> void:
	_stand_still()
	var direction := point - _eye()
	_face(direction, delta)
	if shoot_cooldown > 0.0:
		return
	shoot_cooldown = settings["fire_delay"] * role_fire_delay_mult

	# Bad aim: turn the shot a random small amount. Lower accuracy = bigger miss.
	var spread := deg_to_rad((1.0 - settings["accuracy"]) * 10.0)
	var side := direction.cross(Vector3.UP).normalized()
	var aim := direction.rotated(Vector3.UP, randf_range(-spread, spread))
	aim = aim.rotated(side, randf_range(-spread, spread))
	shoot_ray(_eye(), aim, SIGHT_RANGE + 5.0, true)


func _stand_still() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


# Walk to "post", and stand still once we are close to it.
func _guard(post: Vector3, delta: float) -> void:
	var flat := Vector2(global_position.x - post.x, global_position.z - post.z)
	if flat.length() <= GUARD_RADIUS:
		_stand_still()
	else:
		_walk_to(post, delta)


func _walk_to(point: Vector3, delta: float) -> void:
	# Every half second (and right after a shift) ask the navigation system for a fresh path.
	replan_timer -= delta
	if replan_timer <= 0.0:
		replan_timer = REPLAN_EVERY
		agent.target_position = point

	if agent.is_navigation_finished():
		_stand_still()   # reached the end of the path (or no path exists): wait here
		return

	var next_point := agent.get_next_path_position()
	var direction := next_point - global_position
	direction.y = 0.0
	direction = direction.normalized()
	var speed: float = settings["speed"] * role_speed_mult   # roles change our speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_face(direction, delta)


# Smoothly turn to look in a direction.
func _face(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length() < 0.01:
		return
	var wanted := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, wanted, 8.0 * delta)


# Builds the bot's body: a coloured capsule, a "gun" so you can see where it faces,
# a role-coloured hat, a text label, and the solid shape.
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

	hat = MeshInstance3D.new()
	var hat_mesh := BoxMesh.new()
	hat_mesh.size = Vector3(0.35, 0.35, 0.35)
	hat.mesh = hat_mesh
	hat.position = Vector3(0, 2.05, 0)
	hat.material_override = StandardMaterial3D.new()
	body_visual.add_child(hat)

	label = Label3D.new()
	label.position = Vector3(0, 2.6, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.01
	label.font_size = 40
	label.outline_size = 10
	body_visual.add_child(label)


# Updates the text (team, role, health) and the role colour.
func _update_label() -> void:
	label.text = "%s %s  %d" % [Team.name_of(team).to_upper(), Role.name_of(role).to_upper(), health]
	label.modulate = Role.color_of(role)
	hat.material_override.albedo_color = Role.color_of(role)

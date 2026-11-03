class_name Fighter
extends CharacterBody3D
# The shared parts of anything that fights: the player and the bots.
# It handles team, health, taking damage, dying, respawning after 5 seconds,
# shooting, and being rescued if a moving room traps us.
# player.gd and bot.gd both "extend" this file, so they get all of this for free.

signal health_changed
signal died
signal respawned

# Physics layers: rooms and cores are on layer 1, fighters are on layer 2.
# (This lets us check "am I inside a wall?" without counting other fighters.)
const LAYER_WORLD := 1
const LAYER_FIGHTER := 2

@export var team: Team.Type = Team.Type.BLUE
@export var max_health: int = 100
@export var respawn_time: float = 5.0   # seconds until we come back
@export var shot_damage: int = 5        # damage of one bullet

var health: int
var is_dead: bool = false
var respawn_left: float = 0.0
var spawn_position: Vector3      # our base: where we start and come back to
var body_visual: Node3D          # the see-able body (bots set this; the player has none)

# A slightly smaller copy of our body, used only to check if we are inside a wall.
var stuck_check_shape := CapsuleShape3D.new()


func _ready() -> void:
	health = max_health
	spawn_position = global_position
	collision_layer = LAYER_FIGHTER
	collision_mask = LAYER_WORLD | LAYER_FIGHTER
	add_to_group("fighters")   # lets everyone find all fighters
	stuck_check_shape.radius = 0.35
	stuck_check_shape.height = 1.5


# Counts down the respawn timer while we are defeated.
func _process(delta: float) -> void:
	if is_dead:
		respawn_left -= delta
		if respawn_left <= 0.0:
			respawn()


# Called when something hits us. "from_team" is the shooter's team.
func take_damage(amount: int, from_team: Team.Type) -> void:
	if is_dead or from_team == team:
		return   # no damage to the dead or to our own teammates
	health = max(health - amount, 0)
	health_changed.emit()
	if health == 0:
		die()


func die() -> void:
	is_dead = true
	respawn_left = respawn_time
	velocity = Vector3.ZERO
	collision_layer = 0   # nobody can bump into us or shoot us while defeated
	if body_visual:
		body_visual.visible = false
	died.emit()


# Brings us back at our base with full health.
func respawn() -> void:
	is_dead = false
	health = max_health
	teleport_to_spawn()
	collision_layer = LAYER_FIGHTER
	if body_visual:
		body_visual.visible = true
	health_changed.emit()
	respawned.emit()


func teleport_to_spawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO


# --- Shooting (the same for the player and for bots) ---
# Fires an invisible line from "origin" in "direction". If it hits something that
# can take damage (a core, a player, a bot), that thing is damaged.
# Returns the hit information (empty if we hit nothing).
func shoot_ray(origin: Vector3, direction: Vector3, shoot_range: float = 100.0,
		show_tracer: bool = false) -> Dictionary:
	var to := origin + direction.normalized() * shoot_range
	var query := PhysicsRayQueryParameters3D.create(origin, to)
	query.exclude = [get_rid()]   # don't hit ourselves
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	var end: Vector3 = hit["position"] if not hit.is_empty() else to
	if show_tracer:
		_spawn_tracer(origin, end)
	if hit.is_empty():
		return hit

	var target = hit["collider"]
	if target.has_method("take_damage"):
		target.take_damage(shot_damage, team)   # the target decides if it ignores us
	return hit


# A short-lived thin line so you can SEE where a bot is shooting.
func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.1:
		return
	var tracer := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.04, 0.04, length)
	tracer.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Team.color_of(team)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer.material_override = mat
	get_tree().current_scene.add_child(tracer)
	var up := Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT
	tracer.look_at_from_position((from + to) / 2.0, to, up)
	get_tree().create_timer(0.08).timeout.connect(tracer.queue_free)


# --- Safety code for moving rooms ---

# Call this every physics frame. Rescues us if we fell off the map or got trapped in a wall.
func safety_check() -> void:
	if global_position.y < -20.0:
		teleport_to_spawn()
	elif is_stuck_at(global_position):
		push_to_safe_spot()


# True if our (slightly smaller) body is inside a wall or floor at this position.
func is_stuck_at(pos: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = stuck_check_shape
	query.transform = Transform3D(Basis(), pos + Vector3(0, 0.95, 0))
	query.collision_mask = LAYER_WORLD   # only rooms and cores count
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


# Moves us to the nearest free spot that has a floor under it.
func push_to_safe_spot() -> void:
	var space := get_world_3d().direct_space_state
	for distance in range(1, 9):       # rings 1 metre, 2 metres, ... 8 metres away
		for i in 8:
			var angle := i * TAU / 8.0
			var x := global_position.x + cos(angle) * distance
			var z := global_position.z + sin(angle) * distance
			var top := Vector3(x, global_position.y + 2.5, z)
			var ray := PhysicsRayQueryParameters3D.create(top, top + Vector3(0, -8, 0))
			ray.collision_mask = LAYER_WORLD
			var hit := space.intersect_ray(ray)
			if hit.is_empty():
				continue   # no floor here
			var spot: Vector3 = hit["position"] + Vector3(0, 0.05, 0)
			if not is_stuck_at(spot):
				global_position = spot
				velocity = Vector3.ZERO
				return
	teleport_to_spawn()   # nowhere safe nearby: go back to base

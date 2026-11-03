extends StaticBody3D
# A turret placed by a Defender. It automatically shoots enemies that come in range
# and that it can see. Enemies can shoot it too, and destroy it.

@export var team: Team.Type = Team.Type.BLUE

var health: int
var is_dead: bool = false     # (other scripts check this, just like for players and bots)
var shoot_cooldown: float = 0.0
var head: Node3D              # the turning part with the gun

const MUZZLE_HEIGHT := 1.2    # how high above the floor the gun is


func _ready() -> void:
	health = RoleSettings.TURRET["health"]
	collision_layer = Fighter.LAYER_TURRET
	collision_mask = 0
	add_to_group("fighters")   # so bots treat it as something to shoot at
	_build_body()


func take_damage(amount: int, from_team: Team.Type) -> void:
	if is_dead or from_team == team:
		return
	health -= amount
	if health <= 0:
		is_dead = true
		queue_free()   # destroyed


func _physics_process(delta: float) -> void:
	shoot_cooldown -= delta
	var origin := global_position + Vector3(0, MUZZLE_HEIGHT, 0)
	var target := _find_target(origin)
	if target == null:
		return

	var direction := target.global_position + Vector3(0, 1.2, 0) - origin
	head.rotation.y = atan2(-direction.x, -direction.z)   # turn to face the enemy
	if shoot_cooldown <= 0.0:
		shoot_cooldown = RoleSettings.TURRET["fire_delay"]
		Shooting.fire(self, [get_rid()], origin, direction,
				RoleSettings.TURRET["range"] + 2.0, RoleSettings.TURRET["damage"], team, true)


# Returns the closest enemy that is in range and not hidden behind a wall.
func _find_target(origin: Vector3) -> Node3D:
	var best: Node3D = null
	var best_distance: float = RoleSettings.TURRET["range"]
	for other in get_tree().get_nodes_in_group("fighters"):
		if other == self or other.team == team or other.is_dead:
			continue
		var distance := global_position.distance_to(other.global_position)
		if distance >= best_distance:
			continue
		var query := PhysicsRayQueryParameters3D.create(origin, other.global_position + Vector3(0, 1.2, 0))
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit["collider"] == other:
			best = other
			best_distance = distance
	return best


func _build_body() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Team.color_of(team)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.9, 1.4, 0.9)
	shape.shape = box_shape
	shape.position = Vector3(0, 0.7, 0)
	add_child(shape)

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.45
	base_mesh.bottom_radius = 0.55
	base_mesh.height = 0.9
	base.mesh = base_mesh
	base.position = Vector3(0, 0.45, 0)
	base.material_override = mat
	add_child(base)

	head = Node3D.new()
	head.position = Vector3(0, MUZZLE_HEIGHT, 0)
	add_child(head)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.2, 0.2, 0.9)
	barrel.mesh = barrel_mesh
	barrel.position = Vector3(0, 0, -0.4)
	barrel.material_override = mat
	head.add_child(barrel)

class_name Shooting
# Shared shooting code, used by players, bots and turrets, so a "bullet" always
# works the same way: an invisible line that damages the first thing it hits.


# Fires a line from "origin" along "direction".
#   shooter:   whoever fires (used to find the game world)
#   exclude:   things the line should ignore (the shooter itself)
#   damage:    how much damage the thing hit takes
#   team:      the shooter's team (a target ignores damage from its own team)
# Returns the hit information (empty if nothing was hit).
static func fire(shooter: Node3D, exclude: Array, origin: Vector3, direction: Vector3,
		shoot_range: float, damage: int, team: Team.Type, show_tracer: bool) -> Dictionary:
	var to := origin + direction.normalized() * shoot_range
	var query := PhysicsRayQueryParameters3D.create(origin, to)
	query.exclude = exclude
	var hit := shooter.get_world_3d().direct_space_state.intersect_ray(query)

	var end: Vector3 = hit["position"] if not hit.is_empty() else to
	if show_tracer:
		_spawn_tracer(shooter, team, origin, end)
	if hit.is_empty():
		return hit

	var target = hit["collider"]
	if target.has_method("take_damage"):
		target.take_damage(damage, team)
	return hit


# A short-lived thin line so you can SEE where a shot went.
static func _spawn_tracer(shooter: Node3D, team: Team.Type, from: Vector3, to: Vector3) -> void:
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
	shooter.get_parent().add_child(tracer)
	var up := Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT
	tracer.look_at_from_position((from + to) / 2.0, to, up)
	shooter.get_tree().create_timer(0.08).timeout.connect(tracer.queue_free)

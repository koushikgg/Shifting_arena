class_name TurretPlacer
extends Node
# Lets a Defender place turrets. Players and bots both use this.
# Rules (numbers are in role_settings.gd): at most 2 turrets at once, a cooldown
# between placements, and you must be near your own core.

const TURRET_SCENE := preload("res://scenes/turret.tscn")

var fighter: Fighter           # the defender this belongs to
var turrets: Array = []        # the turrets we placed
var cooldown_left: float = 0.0
var message: String = ""       # why the last placement failed (shown to the player)


func _process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


# How many of our turrets are still alive.
func active_count() -> int:
	turrets = turrets.filter(func(t): return is_instance_valid(t) and not t.is_dead)
	return turrets.size()


func can_place() -> bool:
	return not fighter.is_dead and cooldown_left <= 0.0 \
			and active_count() < RoleSettings.TURRET_MAX


# Tries to place a turret at "position". Returns true if it worked.
func try_place(position: Vector3) -> bool:
	message = ""
	if fighter.is_dead:
		return false
	if active_count() >= RoleSettings.TURRET_MAX:
		message = "Turret limit reached"
		return false
	if cooldown_left > 0.0:
		message = "Turret not ready (%d)" % ceili(cooldown_left)
		return false
	var core := _own_core()
	if core == null or core.global_position.distance_to(position) > RoleSettings.TURRET_PLACE_RANGE:
		message = "Too far from your core"
		return false
	if fighter.is_stuck_at(position):
		message = "No room here"
		return false

	var turret := TURRET_SCENE.instantiate()
	turret.team = fighter.team
	fighter.get_parent().add_child(turret)
	turret.global_position = position
	turrets.append(turret)
	cooldown_left = RoleSettings.TURRET_PLACE_COOLDOWN
	return true


func _own_core() -> Node3D:
	for core in fighter.get_tree().get_nodes_in_group("cores"):
		if core.team == fighter.team:
			return core
	return null

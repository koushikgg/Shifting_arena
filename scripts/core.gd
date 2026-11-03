extends StaticBody3D
# A team's core. Each team defends its own core and tries to destroy the enemy's.
# When a core runs out of health it is destroyed and the "destroyed" signal tells
# the rest of the game (the MatchManager listens for it and ends the match).

# A signal is a way for this script to shout "something happened!" without
# needing to know who is listening.
signal destroyed(team: Team.Type)

@export var team: Team.Type = Team.Type.BLUE   # which team owns this core
@export var max_health: int = 100

var health: int
var is_destroyed: bool = false

var mesh: MeshInstance3D
var collision: CollisionShape3D
var label: Label3D


func _ready() -> void:
	health = max_health
	add_to_group("cores")   # lets other scripts find every core easily
	_build_body()
	_update_label()


# Called by a bullet. "from_team" is the team of whoever shot.
func take_damage(amount: int, from_team: Team.Type) -> void:
	if is_destroyed:
		return
	if from_team == team:
		return   # a core never takes damage from its own team
	health = max(health - amount, 0)
	_update_label()
	if health == 0:
		_destroy()


func _destroy() -> void:
	is_destroyed = true
	mesh.visible = false
	collision.set_deferred("disabled", true)   # nothing to bump into any more
	label.text = "%s CORE DESTROYED" % Team.name_of(team).to_upper()
	_play_explosion()
	destroyed.emit(team)


# A simple effect: a bright ball that grows and fades away.
func _play_explosion() -> void:
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	ball.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.7, 0.2, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.1)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball.material_override = mat
	ball.position = Vector3(0, 1.25, 0)
	add_child(ball)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ball, "scale", Vector3(6, 6, 6), 0.8)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.8)
	tween.chain().tween_callback(ball.queue_free)


# Shows the core's name and a health bar made of text, e.g.  [#######---]  70
func _update_label() -> void:
	var filled := int(round(10.0 * health / max_health))
	var bar := "#".repeat(filled) + "-".repeat(10 - filled)
	label.text = "%s CORE\n[%s] %d" % [Team.name_of(team).to_upper(), bar, health]


# Builds the visible shape, the solid shape, and the health text.
func _build_body() -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.2
	cylinder.bottom_radius = 1.2
	cylinder.height = 2.5
	mesh = MeshInstance3D.new()
	mesh.mesh = cylinder
	mesh.position = Vector3(0, 1.25, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Team.color_of(team)
	mat.emission_enabled = true
	mat.emission = Team.color_of(team)
	mat.emission_energy_multiplier = 0.6
	mesh.material_override = mat
	add_child(mesh)

	var shape := CylinderShape3D.new()
	shape.radius = 1.2
	shape.height = 2.5
	collision = CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0, 1.25, 0)
	add_child(collision)

	label = Label3D.new()
	label.position = Vector3(0, 3.4, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED   # always faces the camera
	label.pixel_size = 0.01
	label.font_size = 48
	label.outline_size = 12
	label.modulate = Team.color_of(team).lightened(0.4)
	add_child(label)

class_name Humanoid
extends Node3D
# A simple human-shaped model built from boxes and balls: head, body, two arms with
# hands, two legs, and a gun. It swings its legs when the character walks.
# Bots and the player both use it, so every fighter looks like a person.
#
# The model is 1.8 metres tall, stands on the floor (feet at y = 0) and faces -Z.

# Set these BEFORE adding the model to the scene.
var shirt_color: Color = Color(0.5, 0.5, 0.5)   # the body and arms (we use the team colour)
var mover: CharacterBody3D                       # whose walking speed drives the animation
var first_person: bool = false                   # true = hide the head from the player's own camera

const SKIN_COLOR := Color(0.9, 0.72, 0.58)
const PANTS_COLOR := Color(0.2, 0.22, 0.3)
const GUN_COLOR := Color(0.15, 0.15, 0.17)
const HEAD_ONLY_LAYER := 16   # a visual layer the player's own camera does not draw

var leg_left: Node3D
var leg_right: Node3D
var arm_left: Node3D
var arm_right: Node3D
var walk_phase: float = 0.0   # where we are in the walking cycle
var swing: float = 0.0        # how much the legs swing right now (0 = standing still)


func _ready() -> void:
	# --- Torso ---
	_add_box(self, Vector3(0, 1.15, 0), Vector3(0.55, 0.6, 0.28), shirt_color)

	# --- Head (a ball) ---
	var head := _add_ball(self, Vector3(0, 1.64, 0), 0.17, SKIN_COLOR)
	if first_person:
		head.layers = HEAD_ONLY_LAYER   # so it doesn't get in the way of our own view

	# --- Legs: each hangs from a "hip" point, so rotating the hip swings the leg ---
	leg_left = _make_leg(-0.14)
	leg_right = _make_leg(0.14)

	# --- Arms: each hangs from a "shoulder" point and holds the gun forward ---
	arm_left = _make_arm(-0.37)
	arm_right = _make_arm(0.37)
	arm_left.rotation.x = deg_to_rad(70)    # raised forward, supporting the gun
	arm_right.rotation.x = deg_to_rad(80)   # raised forward, holding the gun

	# --- Gun (held in the right hand; the arm's -Y direction points forward) ---
	var gun := _add_box(arm_right, Vector3(0, -0.8, 0.0), Vector3(0.08, 0.5, 0.1), GUN_COLOR)
	gun.name = "Gun"


func _process(delta: float) -> void:
	if mover == null:
		return
	# How fast are we walking (sideways speed only, not falling)?
	var speed := Vector2(mover.velocity.x, mover.velocity.z).length()
	var wanted := clampf(speed / 4.0, 0.0, 1.0) * deg_to_rad(35)
	swing = lerpf(swing, wanted, 10.0 * delta)   # ease in and out of walking
	walk_phase += speed * delta * 1.8

	# Legs swing opposite to each other.
	leg_left.rotation.x = sin(walk_phase) * swing
	leg_right.rotation.x = -sin(walk_phase) * swing
	# The arms hold the gun, so they only bob a little.
	var bob := cos(walk_phase * 2.0) * swing * 0.12
	arm_left.rotation.x = deg_to_rad(70) + bob
	arm_right.rotation.x = deg_to_rad(80) + bob


# A leg: a hip point at 0.85 m high, with the leg and a foot hanging below it.
func _make_leg(x: float) -> Node3D:
	var hip := Node3D.new()
	hip.position = Vector3(x, 0.85, 0)
	add_child(hip)
	_add_box(hip, Vector3(0, -0.4, 0), Vector3(0.2, 0.8, 0.22), PANTS_COLOR)
	_add_box(hip, Vector3(0, -0.82, -0.05), Vector3(0.22, 0.12, 0.34), GUN_COLOR)   # boot
	return hip


# An arm: a shoulder point at 1.4 m high, with the arm and a hand hanging below it.
func _make_arm(x: float) -> Node3D:
	var shoulder := Node3D.new()
	shoulder.position = Vector3(x, 1.4, 0)
	add_child(shoulder)
	_add_box(shoulder, Vector3(0, -0.27, 0), Vector3(0.14, 0.54, 0.14), shirt_color)
	_add_ball(shoulder, Vector3(0, -0.58, 0), 0.08, SKIN_COLOR)   # the hand
	return shoulder


func _add_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = _material(color)
	parent.add_child(mesh)
	return mesh


func _add_ball(parent: Node3D, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2.0
	mesh.mesh = ball
	mesh.position = pos
	mesh.material_override = _material(color)
	parent.add_child(mesh)
	return mesh


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat

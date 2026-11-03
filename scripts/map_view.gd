class_name MapView
extends Node
# The Shift Controller's top-down map. Press M to open and close it.
# It is a second camera high above the map. Colored balls over the cores and
# teammates (see fighter.gd and core.gd) are only visible to this camera.

var camera: Camera3D
var normal_camera: Camera3D   # the player's usual first-person camera
var legend: Label
var is_open: bool = false


func setup(fighter: Fighter, first_person_camera: Camera3D, hud: CanvasLayer) -> void:
	normal_camera = first_person_camera

	camera = Camera3D.new()
	camera.top_level = true            # ignore the player's position and turning
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 56.0                 # how many metres tall the view is
	# This camera sees the normal world (layer 1) plus our own team's markers.
	camera.cull_mask = 1 | (2 if fighter.team == Team.Type.BLUE else 4)
	add_child(camera)
	camera.global_position = Vector3(12.5, 40, 12.5)   # above the middle of the map
	camera.rotation_degrees = Vector3(-90, 0, 0)       # look straight down

	legend = Label.new()
	legend.text = "MAP VIEW  (M to close)\nBig balls: your cores and teammates"
	legend.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	legend.offset_left = 20
	legend.offset_top = 90
	legend.add_theme_font_size_override("font_size", 24)
	legend.visible = false
	hud.add_child(legend)


func toggle() -> void:
	is_open = not is_open
	if is_open:
		camera.make_current()
	else:
		normal_camera.make_current()
	legend.visible = is_open


func close() -> void:
	if is_open:
		toggle()

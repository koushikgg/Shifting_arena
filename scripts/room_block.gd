extends Node3D
# A reusable room-block: a floor and four walls, with optional doorways.
# You do not draw it by hand. Instead, you set a few options in the Inspector
# (size, which sides have doorways, floor colour) and the script builds it.
#
# The block's origin (its middle point) is at the CENTRE of the room.
# That makes it easy to move or rotate the whole room later (Stage 3).
#
# Directions: North = -Z, South = +Z, East = +X, West = -X.

# --- Options you set for each room ---
@export var room_size: Vector2 = Vector2(10, 10)   # width (X) and depth (Z) in metres
@export var floor_color: Color = Color(0.5, 0.5, 0.5)  # colour that tells rooms apart
@export var door_north: bool = false   # true = cut a doorway in the north wall
@export var door_east: bool = false
@export var door_south: bool = false
@export var door_west: bool = false

# --- Fixed measurements (the same for every room so doorways always line up) ---
const WALL_HEIGHT := 4.0
const WALL_THICKNESS := 0.5
const DOOR_WIDTH := 4.0
const DOOR_HEIGHT := 3.0
const WALL_COLOR := Color(0.75, 0.75, 0.78)


func _ready() -> void:
	_build_floor()
	# North and south walls run along the X direction ("is_ns" = true).
	_build_side(true, -room_size.y / 2.0 + WALL_THICKNESS / 2.0, room_size.x, door_north)
	_build_side(true, room_size.y / 2.0 - WALL_THICKNESS / 2.0, room_size.x, door_south)
	# East and west walls run along the Z direction. They are a little shorter
	# so they don't overlap the north/south walls in the corners.
	var side_length := room_size.y - 2.0 * WALL_THICKNESS
	_build_side(false, room_size.x / 2.0 - WALL_THICKNESS / 2.0, side_length, door_east)
	_build_side(false, -room_size.x / 2.0 + WALL_THICKNESS / 2.0, side_length, door_west)


func _build_floor() -> void:
	# The floor is 1 metre thick, with its top surface at height 0.
	_add_box(Vector3(0, -0.5, 0), Vector3(room_size.x, 1.0, room_size.y), floor_color)


# Builds one side of the room.
#   is_ns:    true for north/south walls, false for east/west walls
#   fixed:    where the wall sits (its Z for north/south, its X for east/west)
#   length:   how long the wall is
#   has_door: whether to leave a doorway in the middle
func _build_side(is_ns: bool, fixed: float, length: float, has_door: bool) -> void:
	if not has_door:
		# No doorway: one solid wall.
		_add_wall(is_ns, fixed, 0.0, length, WALL_HEIGHT / 2.0, WALL_HEIGHT)
		return

	# Doorway: two wall pieces, one on each side of the gap...
	var piece := (length - DOOR_WIDTH) / 2.0
	var offset := (DOOR_WIDTH + piece) / 2.0
	_add_wall(is_ns, fixed, -offset, piece, WALL_HEIGHT / 2.0, WALL_HEIGHT)
	_add_wall(is_ns, fixed, offset, piece, WALL_HEIGHT / 2.0, WALL_HEIGHT)
	# ...plus a small piece above the gap so it looks like a real doorway.
	var top_height := WALL_HEIGHT - DOOR_HEIGHT
	_add_wall(is_ns, fixed, 0.0, DOOR_WIDTH, DOOR_HEIGHT + top_height / 2.0, top_height)


# Places one wall piece.
#   along:  position along the wall (0 = middle of the wall)
#   len:    length of this piece
#   y:      height of the piece's middle
#   height: how tall the piece is
func _add_wall(is_ns: bool, fixed: float, along: float, len: float, y: float, height: float) -> void:
	if is_ns:
		_add_box(Vector3(along, y, fixed), Vector3(len, height, WALL_THICKNESS), WALL_COLOR)
	else:
		_add_box(Vector3(fixed, y, along), Vector3(WALL_THICKNESS, height, len), WALL_COLOR)


# Makes a solid box (something you can see AND bump into) at a position.
func _add_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()   # a solid thing that never moves by itself
	body.position = pos

	var shape := CollisionShape3D.new()   # the invisible part you bump into
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)

	var mesh := MeshInstance3D.new()      # the visible part
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	body.add_child(mesh)

	add_child(body)

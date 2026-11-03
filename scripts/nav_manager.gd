extends Node
# Builds the "navigation mesh": a map of where bots can walk. Walls and gaps between
# rooms are left out of it. Rooms move, so the map is rebuilt after every shift,
# and then every bot is told to find a new path.

@export var map_path: NodePath = ^"../Map"                 # the node holding all rooms
@export var shift_manager_path: NodePath = ^"../ShiftManager"

var region: NavigationRegion3D
var is_baking: bool = false
var bake_again: bool = false   # a shift ended while we were still baking


func _ready() -> void:
	# Mark every room as "walkable ground" for the navigation builder.
	for room in get_node(map_path).get_children():
		room.add_to_group("nav_geometry")

	var navmesh := NavigationMesh.new()
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	navmesh.geometry_source_group_name = &"nav_geometry"
	navmesh.agent_radius = 0.5    # a bit bigger than a bot, so bots keep off the walls
	navmesh.agent_height = 2.0
	navmesh.agent_max_climb = 0.25

	region = NavigationRegion3D.new()
	region.navigation_mesh = navmesh
	region.bake_finished.connect(_on_bake_finished)
	add_child(region)

	get_node(shift_manager_path).shift_finished.connect(rebuild)
	rebuild()


# Rebuilds the navigation map from where the rooms are right now.
func rebuild() -> void:
	if is_baking:
		bake_again = true
		return
	is_baking = true
	region.bake_navigation_mesh(true)   # true = work in the background, no stutter


func _on_bake_finished() -> void:
	is_baking = false
	get_tree().call_group("bots", "replan")   # every bot finds a new path
	if bake_again:
		bake_again = false
		rebuild()

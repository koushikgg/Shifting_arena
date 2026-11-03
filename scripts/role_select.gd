extends CanvasLayer
# The role-select screen shown before the match. You pick a role, then the bots
# are created with the remaining roles, and the match starts.
#
# TO CHANGE THE ROLE WITHOUT THE MENU: turn off "show_menu" in the Inspector and
# set "default_role" to the role you want. (This is the one place to change it.)

@export var show_menu: bool = true
@export var default_role: Role.Type = Role.Type.ATTACKER
@export var player_path: NodePath = ^"../Player"
@export var spawner_path: NodePath = ^"../BotSpawner"

var menu: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep working while the game is paused
	layer = 20
	if show_menu:
		_build_menu()
		get_tree().paused = true   # nothing moves until you choose
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_choose(default_role)


func _input(event: InputEvent) -> void:
	# Keys 1, 2, 3 also choose a role.
	if menu and menu.visible and event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _choose(Role.Type.ATTACKER)
			KEY_2: _choose(Role.Type.DEFENDER)
			KEY_3: _choose(Role.Type.SHIFT_CONTROLLER)


func _choose(role: Role.Type) -> void:
	get_node(player_path).set_role(role)
	get_node(spawner_path).spawn_bots(role)
	if menu:
		menu.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_menu() -> void:
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	menu = background

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 14)
	background.add_child(box)

	var title := Label.new()
	title.text = "Choose your role"
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var number := 1
	for role in [Role.Type.ATTACKER, Role.Type.DEFENDER, Role.Type.SHIFT_CONTROLLER]:
		var button := Button.new()
		button.text = "[%d]  %s\n%s" % [number, Role.name_of(role).to_upper(), Role.description_of(role)]
		button.add_theme_font_size_override("font_size", 26)
		button.add_theme_color_override("font_color", Role.color_of(role))
		button.pressed.connect(_choose.bind(role))
		box.add_child(button)
		number += 1

	var help := Label.new()
	help.text = "Move: W A S D / arrows    Look: mouse or I J K L    Shoot: left click\nDefender: T places a turret    Shift Controller: M map, F early shift"
	help.add_theme_font_size_override("font_size", 20)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(help)

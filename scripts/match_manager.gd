extends Node
# The MatchManager watches the cores. When one is destroyed, the match is over:
# it shows who won, and lets you restart with a button or the R key.

var overlay: Control
var title: Label
var match_over: bool = false


func _ready() -> void:
	# Keep working even when the game is paused (we pause the game at the end).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_screen()
	# Listen to every core. (Deferred so all cores exist before we look for them.)
	_connect_cores.call_deferred()


func _connect_cores() -> void:
	for core in get_tree().get_nodes_in_group("cores"):
		core.destroyed.connect(_on_core_destroyed)


# Runs when a core is destroyed. The OTHER team wins.
func _on_core_destroyed(team: Team.Type) -> void:
	if match_over:
		return
	match_over = true
	var winner := Team.opponent_of(team)
	title.text = "%s team wins!" % Team.name_of(winner)
	title.modulate = Team.color_of(winner).lightened(0.3)
	overlay.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # show the mouse so we can click Restart
	# Let the explosion play for a second, then freeze the game.
	await get_tree().create_timer(1.0).timeout
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if match_over and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_restart()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()   # reloading the scene resets everything


# Builds the "team wins" screen (hidden until the match ends).
func _build_screen() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	layer.add_child(overlay)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(box)

	title = Label.new()
	title.add_theme_font_size_override("font_size", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var button := Button.new()
	button.text = "Restart (R)"
	button.add_theme_font_size_override("font_size", 32)
	button.pressed.connect(_restart)
	box.add_child(button)

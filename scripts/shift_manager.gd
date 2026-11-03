extends Node
# The ShiftManager: every 30 seconds it makes some rooms slide or rotate.
# It also shows the countdown on screen and warns the player before a shift.
#
# To change WHICH rooms move, edit SHIFT_PATTERN below. Nothing else needs to change.

# --- The shift pattern ---
# This is a list of shifts. Shift 1 happens first, then shift 2, and so on.
# When the list ends it starts again from the top.
# Each shift is a list of moves. A move names a room (by its name in the Map node) and says:
#   "slide":  how far the room sits from its ORIGINAL spot, as (x, y, z) in metres
#   "rotate": how far the room is turned from its ORIGINAL angle, in degrees
# A room that is not named in a shift stays where it is.
const SHIFT_PATTERN := [
	# Shift 1: the corridor slides sideways, so the blue room is cut off.
	[
		{"room": "CorridorB", "slide": Vector3(0, 0, 8)},
	],
	# Shift 2: the corridor slides back, and the yellow room slides north.
	[
		{"room": "CorridorB", "slide": Vector3(0, 0, 0)},
		{"room": "SmallRoomE", "slide": Vector3(0, 0, -10)},
	],
	# Shift 3: the yellow room slides back, and the red room turns 90 degrees.
	[
		{"room": "SmallRoomE", "slide": Vector3(0, 0, 0)},
		{"room": "SmallRoomC", "rotate": -90.0},
	],
	# Shift 4: the red room turns back.
	[
		{"room": "SmallRoomC", "rotate": 0.0},
	],
]

# Sent when the rooms have finished moving (the NavManager listens for this).
signal shift_finished

# --- Settings (change them in the Inspector) ---
@export var map_path: NodePath = ^"../Map"   # where the node that holds all the rooms is
@export var shift_interval: float = 30.0   # seconds between shifts
@export var warning_time: float = 5.0      # warning starts this many seconds before
@export var move_time: float = 2.0         # how long a shift takes

var map: Node3D                  # the node that holds all the rooms (found in _ready)
var time_left: float = 0.0       # seconds until the next shift
var is_moving: bool = false      # true while rooms are moving
var next_shift: int = 0          # which shift in the pattern comes next
var early_team: int = -1          # which team called an early shift (-1 = nobody)
var early_used: Dictionary = {}   # team -> how many early shifts it has used
var last_second: int = -1        # used to beep once per second
var home_positions: Dictionary = {}   # room name -> its original position

var label: Label
var beep_player: AudioStreamPlayer


func _ready() -> void:
	map = get_node(map_path)
	add_to_group("shift_manager")   # so bots and players can find us
	time_left = shift_interval

	# Remember where each room started, so slides are measured from there.
	for room in map.get_children():
		home_positions[room.name] = room.position

	_build_screen_text()
	_build_beep()


func _process(delta: float) -> void:
	if is_moving:
		return  # the countdown is paused while rooms move

	time_left -= delta
	if time_left <= 0.0:
		_start_shift()
		return

	var seconds := ceili(time_left)
	if time_left <= warning_time:
		# Warning: red text that flashes, and one beep per second.
		if early_team >= 0:
			label.text = "%s EARLY SHIFT IN %d!" % [Team.name_of(early_team).to_upper(), seconds]
		else:
			label.text = "SHIFT IN %d!" % seconds
		var flash_on := int(time_left * 4.0) % 2 == 0
		label.modulate = Color(1, 0.2, 0.2) if flash_on else Color(1, 1, 1)
		if seconds != last_second:
			beep_player.play()
	else:
		label.text = "Next shift in %d" % seconds
		label.modulate = Color(1, 1, 1)
	last_second = seconds


# Starts the next shift in the pattern.
func _start_shift() -> void:
	is_moving = true
	label.text = "ROOMS SHIFTING!"
	label.modulate = Color(1, 0.8, 0.2)

	# One tween (a smooth animation) moves every room in this shift at the same time.
	var tween := create_tween()
	# Move in step with the physics, so the player is carried properly.
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_parallel(true)

	for move in SHIFT_PATTERN[next_shift]:
		var room: Node3D = map.get_node(move["room"])
		if move.has("slide"):
			var target: Vector3 = home_positions[room.name] + move["slide"]
			tween.tween_property(room, "position", target, move_time) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if move.has("rotate"):
			var angle := Vector3(0, move["rotate"], 0)
			tween.tween_property(room, "rotation_degrees", angle, move_time) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.finished.connect(_end_shift)
	next_shift = (next_shift + 1) % SHIFT_PATTERN.size()


# Called when all rooms have stopped moving.
func _end_shift() -> void:
	is_moving = false
	early_team = -1
	time_left = shift_interval
	last_second = -1
	shift_finished.emit()


# Makes the text at the top of the screen.
func _build_screen_text() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 20
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	layer.add_child(label)


# Makes a short beep sound in code, so we don't need any sound file.
func _build_beep() -> void:
	var rate := 22050
	var count := int(rate * 0.15)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var fade := 1.0 - float(i) / count   # fade out so it doesn't click
		var sample := sin(TAU * 880.0 * float(i) / rate) * 0.4 * fade
		data.encode_s16(i * 2, int(sample * 32767.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = data

	beep_player = AudioStreamPlayer.new()
	beep_player.stream = sound
	add_child(beep_player)


# --- Early shift (used by the Shift Controller role) ---

# Can this team call an early shift right now?
# Not if it has used up its early shifts, rooms are already moving, or the warning has started.
func can_call_early(team: Team.Type) -> bool:
	return not is_moving and time_left > warning_time \
			and early_used.get(team, 0) < RoleSettings.EARLY_SHIFTS_PER_MATCH


func early_shifts_left(team: Team.Type) -> int:
	return RoleSettings.EARLY_SHIFTS_PER_MATCH - early_used.get(team, 0)


# Jumps the countdown to the warning, so everyone gets the flashing warning and
# beeps, and then the next shift happens. Returns true if it worked.
func call_early_shift(team: Team.Type) -> bool:
	if not can_call_early(team):
		return false
	early_used[team] = early_used.get(team, 0) + 1
	early_team = team
	time_left = warning_time
	last_second = -1
	return true


# The rooms that will move in the NEXT shift.
func rooms_moving_next() -> Array:
	var rooms := []
	for move in SHIFT_PATTERN[next_shift]:
		rooms.append(map.get_node(move["room"]))
	return rooms


# True if an ENEMY of "team" is standing in a room that moves next,
# and none of the team's own players are in that room (so we don't trap ourselves).
func enemy_in_next_moving_room(team: Team.Type) -> bool:
	for room in rooms_moving_next():
		var enemy_inside := false
		var friend_inside := false
		for other in get_tree().get_nodes_in_group("fighters"):
			if not other is Fighter or other.is_dead or not _is_in_room(room, other.global_position):
				continue
			if other.team == team:
				friend_inside = true
			else:
				enemy_inside = true
		if enemy_inside and not friend_inside:
			return true
	return false


func _is_in_room(room: Node3D, point: Vector3) -> bool:
	var local := room.to_local(point)
	return absf(local.x) < room.room_size.x / 2.0 and absf(local.z) < room.room_size.y / 2.0 \
			and local.y > -1.0 and local.y < 4.0

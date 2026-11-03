extends Node
# Creates the bots when the match starts (the RoleSelect screen calls spawn_bots()
# once you have chosen your role). THIS IS THE PLACE to change how many bots there
# are and how hard they are. Select the BotSpawner node and use the Inspector,
# or change the numbers below.
#
# Bot counts do NOT include you (you are the first blue player).
# A full 4 vs 4 match is blue_bots = 3 and red_bots = 4.

@export var blue_bots: int = 3
@export var red_bots: int = 4
@export var difficulty: Difficulty.Level = Difficulty.Level.EASY

const BOT_SCENE := preload("res://scenes/bot.tscn")

# Where each team's bots start (and come back to after being defeated).
# Blue base = the blue room, red base = the green room. Up to 3 blue bots, 4 red bots.
const BLUE_SPAWNS := [Vector3(-3, 0.1, 3), Vector3(3, 0.1, 3), Vector3(3, 0.1, -3)]
const RED_SPAWNS := [Vector3(22, 0.1, 22), Vector3(28, 0.1, 22), Vector3(22, 0.1, 28), Vector3(28, 0.1, 28)]


# "player_role" is the role you picked. Blue bots get the roles that are left over
# (each team needs 2 Attackers, 1 Defender and 1 Shift Controller).
func spawn_bots(player_role: Role.Type) -> void:
	var blue_roles := RoleSettings.TEAM_ROLES.duplicate()
	blue_roles.erase(player_role)   # removes one copy: the one you are using
	_spawn_team(Team.Type.BLUE, blue_bots, BLUE_SPAWNS, blue_roles)
	_spawn_team(Team.Type.RED, red_bots, RED_SPAWNS, RoleSettings.TEAM_ROLES.duplicate())


func _spawn_team(team: Team.Type, count: int, spawns: Array, roles: Array) -> void:
	for i in mini(mini(count, spawns.size()), roles.size()):
		var bot := BOT_SCENE.instantiate()
		bot.team = team
		bot.role = roles[i]
		bot.settings = Difficulty.settings(difficulty)
		bot.position = spawns[i]
		bot.name = "%sBot%d" % [Team.name_of(team), i + 1]
		# Added a moment later, because the scene may still be setting up.
		get_parent().add_child.call_deferred(bot)

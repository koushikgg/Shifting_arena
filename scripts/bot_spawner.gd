extends Node
# Creates the bots when the match starts. THIS IS THE PLACE to change how many bots
# there are and how hard they are. Select the BotSpawner node and use the Inspector,
# or change the numbers below.
#
# Bot counts do NOT include you (you are the first blue player).
# For 4 vs 4 set blue_bots = 3 and red_bots = 4.

@export var blue_bots: int = 1
@export var red_bots: int = 2
@export var difficulty: Difficulty.Level = Difficulty.Level.EASY

const BOT_SCENE := preload("res://scenes/bot.tscn")

# Where each team's bots start (and come back to after being defeated).
# Blue base = the blue room, red base = the green room. Up to 3 blue bots, 4 red bots.
const BLUE_SPAWNS := [Vector3(-3, 0.1, 3), Vector3(3, 0.1, 3), Vector3(3, 0.1, -3)]
const RED_SPAWNS := [Vector3(22, 0.1, 22), Vector3(28, 0.1, 22), Vector3(22, 0.1, 28), Vector3(28, 0.1, 28)]


func _ready() -> void:
	_spawn_team(Team.Type.BLUE, blue_bots, BLUE_SPAWNS)
	_spawn_team(Team.Type.RED, red_bots, RED_SPAWNS)


func _spawn_team(team: Team.Type, count: int, spawns: Array) -> void:
	for i in mini(count, spawns.size()):
		var bot := BOT_SCENE.instantiate()
		bot.team = team
		bot.settings = Difficulty.settings(difficulty)
		bot.position = spawns[i]
		bot.name = "%sBot%d" % [Team.name_of(team), i + 1]
		# Added a moment later, because the scene is still being set up right now.
		get_parent().add_child.call_deferred(bot)

class_name Difficulty
# Bot difficulty settings, all in one place. Change the numbers here to make bots
# easier or harder. The BotSpawner picks which level the bots use.
#
#   speed:         how fast bots walk (metres per second). You walk at 6.
#   accuracy:      0 = terrible aim, 1 = perfect aim.
#   reaction_time: seconds a bot waits after first seeing an enemy before it reacts.
#   fire_delay:    seconds between bot shots (you fire every 0.15).

enum Level { EASY, MEDIUM, HARD }


static func settings(level: Level) -> Dictionary:
	match level:
		Level.EASY:
			return {"speed": 3.5, "accuracy": 0.3, "reaction_time": 1.0, "fire_delay": 0.6}
		Level.MEDIUM:
			return {"speed": 5.0, "accuracy": 0.6, "reaction_time": 0.5, "fire_delay": 0.35}
		_:
			return {"speed": 6.0, "accuracy": 0.85, "reaction_time": 0.2, "fire_delay": 0.2}

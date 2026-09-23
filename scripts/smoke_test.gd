extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_fight()
	game.state = "combat"
	game.enemy.global_position = game.player.global_position + Vector3(0, 0, -2.0)
	game.player.facing = Vector3.FORWARD
	var original_health: float = game.enemy.health
	assert(game.player.action("light"), "light attack must start")
	assert(game.enemy.health < original_health, "light attack must damage a nearby rival")
	game.player.attack_clock = 0.0
	game.player.ki = 100.0
	assert(game.player.action("blast"), "ki blast must start")
	assert(game.player.ki < 100.0, "blast must consume ki")
	game.player.attack_clock = 0.0
	assert(game.player.action("vanish"), "vanish must start with resources")
	assert(game.player.global_position.distance_to(game.enemy.global_position) < 2.3,
		"vanish must reposition behind the rival")
	game.player.attack_clock = 0.0
	game.player.ki = 100.0
	assert(game.player.action("ultimate"), "ultimate must start with full ki")
	assert(game.enemy.health < original_health - 25.0, "ultimate must damage the rival")
	print("SMOKE PASS: melee, ki cost, vanish, ultimate")
	quit()

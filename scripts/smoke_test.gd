extends SceneTree

func _initialize() -> void:
	_run.call_deferred()


func require(condition: bool, message: String) -> bool:
	if condition: return true
	push_error(message)
	quit(1)
	return false

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_fight()
	game.state = "combat"
	game.enemy.global_position = game.player.global_position + Vector3(0, 0, -2.0)
	game.player.facing = Vector3.FORWARD
	var original_health: float = game.enemy.health
	if not require(game.player.action("light"), "light attack must start"): return
	if not require(game.enemy.health < original_health, "light attack must damage a nearby rival"): return
	game.player.attack_clock = 0.0
	game.player.ki = 100.0
	if not require(game.player.action("blast"), "ki blast must start"): return
	if not require(game.player.ki < 100.0, "blast must consume ki"): return
	game.player.attack_clock = 0.0
	if not require(game.player.action("vanish"), "vanish must start with resources"): return
	if not require(game.player.global_position.distance_to(game.enemy.global_position) < 2.3,
		"vanish must reposition behind the rival"): return
	game.player.attack_clock = 0.0
	game.player.ki = 100.0
	game.enemy.stunned = 2.0
	game.enemy.guarding = false
	if not require(game.player.action("ultimate"), "ultimate must start with full ki"): return
	for _frame in range(65): game.update_effects(.02)
	if game.enemy.health >= original_health - 25.0:
		push_error("ultimate must damage the rival after its charge stage")
		quit(1)
		return
	game.start_fight()
	game.state = "combat"
	game.player.ki = 100.0
	game.player.attack_clock = 0.0
	if not require(game.player.action("sphere"), "charged sphere must start"): return
	if not require(game.projectile_data.size() > 0, "charged sphere must spawn"): return
	game.player.ki = 100.0
	game.player.attack_clock = 0.0
	var projectile_count: int = game.projectile_data.size()
	if not require(game.player.action("volley"), "volley must start"): return
	if not require(game.projectile_data.size() >= projectile_count + 5, "volley must fire five distinct shots"): return
	game.select_fighter(1)
	if not require(game.player.fighter_id == "nova" and game.player.max_ki == 120.0,
		"Nova selection must load its model and high ki stats"): return
	game.select_fighter(2)
	if not require(game.player.fighter_id == "dusk" and game.enemy.fighter_id == "solar",
		"Dusk selection must switch both combatants"): return
	game.select_fighter(0)
	game.state = "combat"
	game.player.ki = 80.0
	game.execute_action("transform")
	if not require(game.player.fighter_id == "nova" and game.player.ki < 80.0,
		"Solar must transform to Nova and spend ki"): return
	print("SMOKE PASS: melee, ki, vanish, ultimate, sphere, volley, three choices, transformation")
	game.queue_free()
	for _frame in range(3): await process_frame
	quit()

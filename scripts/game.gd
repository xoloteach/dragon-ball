extends Node3D

const Fighter = preload("res://scripts/fighter.gd")
const ARENA = preload("res://assets/models/sunscar_arena.glb")
const FONT = preload("res://assets/fonts/Rajdhani-Bold.ttf")

var player: ArenaFighter
var enemy: ArenaFighter
var camera: Camera3D
var ui: Control
var hud: Control
var overlay: Control
var touch_ui: Control
var p_health: ProgressBar
var e_health: ProgressBar
var ki_bar: ProgressBar
var stamina_bar: ProgressBar
var combo_label: Label
var status_label: Label
var lock_marker: Label
var state := "menu"
var fight_timer := 0.0
var shake := 0.0
var fov_pulse := 0.0
var hit_stop := 0.0
var camera_yaw := 0.0
var camera_pitch := -0.13
var touch_move := Vector2.ZERO
var touch_axis_id := -1
var touch_look_id := -1
var touch_hold := {}
var touch_detected := false
var ai_timer := 0.0
var ai_mode := "approach"
var ai_mood := 0.0
var projectile_data: Array[Dictionary] = []
var effect_data: Array[Dictionary] = []
var combo_count := 0
var combo_timer := 0.0
var player_choice := 0
var was_charging := false
var sun: DirectionalLight3D
var world: WorldEnvironment


func _ready() -> void:
	create_world()
	create_ui()
	show_menu()
	if OS.get_environment("SOLAR_CAPTURE") != "":
		capture_scene.call_deferred(OS.get_environment("SOLAR_CAPTURE"))


func capture_scene(variant: String) -> void:
	if variant == "combat":
		start_fight()
		state = "combat"
		status_label.text = ""
	elif variant == "touch":
		start_fight()
		state = "combat"
		status_label.text = ""
		touch_ui.visible = true
	elif variant == "select":
		show_select()
	elif variant == "portrait":
		clear_overlay()
		hud.visible = false
		state = "portrait"
		camera.global_position = player.global_position + Vector3(1.25, 2.75, -6.2)
		camera.look_at(player.global_position + Vector3.UP * 2.0)
		camera.fov = 51.0
	await get_tree().create_timer(0.8).timeout
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://builds/" + variant + ".png")
	get_tree().quit()


func create_world() -> void:
	var arena = ARENA.instantiate()
	arena.name = "SunscarArena"
	add_child(arena)
	world = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.33, 0.57, 0.77)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.90, 0.84, 0.76)
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 150, 0)
	sun.light_color = Color(1.0, 0.79, 0.57)
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, -40, 0)
	fill.light_color = Color(0.32, 0.61, 1.0)
	fill.light_energy = 0.22
	add_child(fill)
	camera = Camera3D.new()
	camera.fov = 60
	camera.current = true
	add_child(camera)
	player = Fighter.new()
	player.name = "SolarAscendant"
	player.configure(true)
	player.position = Vector3(0, 0, 5.5)
	add_child(player)
	enemy = Fighter.new()
	enemy.name = "DuskRival"
	enemy.configure(false)
	enemy.position = Vector3(0, 0, -5.5)
	add_child(enemy)
	player.rival = enemy
	enemy.rival = player
	for f in [player, enemy]:
		f.impact.connect(on_impact)
		f.blast.connect(on_blast)
		f.beam.connect(on_beam)
		f.ultimate.connect(on_ultimate)
		f.defeated.connect(on_defeated)
	camera.global_position = Vector3(0, 4, 12)
	camera.look_at(Vector3(0, 2, 0))


func panel(color: Color, border: Color = Color.TRANSPARENT, radius := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(2 if border.a > 0.0 else 0)
	s.set_corner_radius_all(radius)
	return s


func label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0.03, 0.02, 0.04, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func button(text: String, size: Vector2, color := Color(0.13, 0.13, 0.19, 0.91)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color(1.0, 0.92, 0.76))
	b.add_theme_stylebox_override("normal", panel(color, Color(1.0, 0.67, 0.17, 0.85), 8))
	b.add_theme_stylebox_override("hover", panel(Color(0.37, 0.21, 0.11, 0.96), Color(1.0, 0.84, 0.33), 8))
	b.add_theme_stylebox_override("pressed", panel(Color(0.85, 0.45, 0.10), Color.WHITE, 8))
	return b


func create_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas.add_child(ui)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	var top := ColorRect.new()
	top.color = Color(0.025, 0.034, 0.065, 0.78)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 96
	hud.add_child(top)
	var name_p := label("SOLAR ASCENDANT", 23, Color(1, .82, .35))
	name_p.position = Vector2(37, 6)
	hud.add_child(name_p)
	var name_e := label("DUSK RIVAL", 23, Color(.47, .77, 1))
	name_e.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	name_e.position = Vector2(-260, 6)
	hud.add_child(name_e)
	p_health = bar(Color(1, .64, .12), Vector2(37, 38), Vector2(412, 22))
	hud.add_child(p_health)
	e_health = bar(Color(.3, .66, 1), Vector2(-449, 38), Vector2(412, 22), true)
	hud.add_child(e_health)
	ki_bar = bar(Color(.96, .77, .22), Vector2(37, 77), Vector2(288, 11))
	hud.add_child(ki_bar)
	stamina_bar = bar(Color(.56, .90, .93), Vector2(335, 77), Vector2(114, 11))
	hud.add_child(stamina_bar)
	var ki_text := label("KI", 14, Color(1,.83,.43))
	ki_text.position = Vector2(37, 59)
	hud.add_child(ki_text)
	var stamina_text := label("STAMINA", 14, Color(.67,.93,.97))
	stamina_text.position = Vector2(335, 59)
	hud.add_child(stamina_text)
	combo_label = label("", 42, Color(1, .81, .28))
	combo_label.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	combo_label.position = Vector2(38, -60)
	hud.add_child(combo_label)
	status_label = label("", 44, Color.WHITE)
	status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position = Vector2(-250, 115)
	status_label.custom_minimum_size = Vector2(500, 70)
	hud.add_child(status_label)
	lock_marker = label("◇", 37, Color(1, .80, .27))
	lock_marker.visible = false
	hud.add_child(lock_marker)
	var pause_button := button("Ⅱ", Vector2(48, 44))
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-70, 111)
	pause_button.pressed.connect(toggle_pause)
	hud.add_child(pause_button)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	create_touch_controls()
	hud.visible = false


func bar(fill: Color, pos: Vector2, size: Vector2, right := false) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = 100
	b.value = 100
	b.custom_minimum_size = size
	if right: b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b.position = pos
	b.add_theme_stylebox_override("background", panel(Color(.04, .05, .08, .95), Color(1, 1, 1, .15), 4))
	b.add_theme_stylebox_override("fill", panel(fill, Color.TRANSPARENT, 3))
	return b


func create_touch_controls() -> void:
	touch_ui = Control.new()
	touch_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_ui.mouse_filter = Control.MOUSE_FILTER_PASS
	touch_ui.visible = DisplayServer.is_touchscreen_available()
	ui.add_child(touch_ui)
	var stick := label("◎\nMOVE", 29, Color(1, 1, 1, .58))
	stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	stick.position = Vector2(95, -200)
	stick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	touch_ui.add_child(stick)
	var specs := [
		["HIT", "light", Vector2(-305, -145), Vector2(83, 69)],
		["HEAVY", "heavy", Vector2(-200, -145), Vector2(95, 69)],
		["BLAST", "blast", Vector2(-205, -245), Vector2(92, 66)],
		["DASH", "dodge", Vector2(-430, -245), Vector2(92, 66)],
		["GUARD", "guard", Vector2(-410, -145), Vector2(98, 69)],
		["CHARGE", "charge", Vector2(-320, -245), Vector2(106, 66)],
		["BEAM", "beam", Vector2(-325, -335), Vector2(87, 59)],
		["ULT", "ultimate", Vector2(-205, -335), Vector2(75, 59)],
		["↑", "up", Vector2(38, -298), Vector2(62, 57)],
		["↓", "down", Vector2(112, -298), Vector2(62, 57)],
		["LOCK", "lock", Vector2(-100, -335), Vector2(70, 56)],
		["VANISH", "vanish", Vector2(-440, -335), Vector2(92, 56)]
	]
	for spec in specs:
		var b := button(spec[0], spec[3], Color(.1, .12, .21, .68))
		b.add_theme_font_size_override("font_size", 19)
		b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT if spec[2].x < 0 else Control.PRESET_BOTTOM_LEFT)
		b.position = spec[2]
		b.button_down.connect(func(): touch_hold[spec[1]] = true; execute_action(spec[1]))
		b.button_up.connect(func(): touch_hold[spec[1]] = false)
		touch_ui.add_child(b)


func clear_overlay() -> void:
	for child in overlay.get_children(): child.queue_free()


func add_backdrop() -> void:
	var bg := ColorRect.new()
	bg.color = Color(.025, .035, .07, .79)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)


func menu_layout(title: String, subtitle: String) -> VBoxContainer:
	clear_overlay()
	add_backdrop()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-285, -200)
	box.custom_minimum_size = Vector2(570, 400)
	box.add_theme_constant_override("separation", 13)
	overlay.add_child(box)
	var title_label := label(title, 58, Color(1, .77, .24))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)
	var subtitle_label := label(subtitle, 23, Color(.81, .85, .92))
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(subtitle_label)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	box.add_child(spacer)
	return box


func show_menu() -> void:
	state = "menu"
	hud.visible = false
	touch_ui.visible = false
	var box := menu_layout("SOLAR ASCENDANT", "SKYBREAK ARENA  •  3D ANIME COMBAT")
	var start := button("ENTER THE ARENA", Vector2(0, 58))
	start.pressed.connect(show_select)
	box.add_child(start)
	var hint := label("WASD MOVE   •   J COMBO   •   K HEAVY   •   L KI BLAST\nSPACE RISE   •   C DESCEND   •   SHIFT DASH   •   E CHARGE", 20, Color(.9,.86,.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func show_select() -> void:
	state = "select"
	var box := menu_layout("CHOOSE YOUR FIGHTER", "A warrior of solar fire faces the guardian of dusk")
	var card := button("☀  SOLAR ASCENDANT\nGolden aura  •  Quick combos  •  Celestial beam", Vector2(0, 106))
	card.add_theme_font_size_override("font_size", 24)
	card.pressed.connect(start_fight)
	box.add_child(card)
	var rival_label := label("VERSUS  •  DUSK RIVAL  •  AN ADAPTIVE AIRBORNE FOE", 22, Color(.55, .79, 1))
	rival_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rival_label)
	var back := button("BACK", Vector2(0, 50))
	back.pressed.connect(show_menu)
	box.add_child(back)


func start_fight() -> void:
	clear_overlay()
	player.health = player.max_health
	player.ki = 45.0
	player.stamina = 100.0
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0, 0, 5.5)
	player.rotation = Vector3.ZERO
	enemy.health = enemy.max_health
	enemy.ki = 55.0
	enemy.stamina = 100.0
	enemy.velocity = Vector3.ZERO
	enemy.global_position = Vector3(0, 0, -5.5)
	enemy.rotation = Vector3.ZERO
	combo_count = 0
	combo_timer = 0.0
	was_charging = false
	state = "intro"
	fight_timer = 2.0
	hud.visible = true
	touch_ui.visible = DisplayServer.is_touchscreen_available() or touch_detected
	status_label.text = "ROUND 01  •  READY"


func show_result(winner: bool) -> void:
	state = "result"
	status_label.text = ""
	touch_ui.visible = false
	var box := menu_layout("VICTORY" if winner else "DEFEAT", "The sky remembers this battle.")
	var retry := button("RETRY FIGHT", Vector2(0, 55))
	retry.pressed.connect(start_fight)
	box.add_child(retry)
	var select := button("CHARACTER SELECT", Vector2(0, 55))
	select.pressed.connect(show_select)
	box.add_child(select)
	var menu := button("MAIN MENU", Vector2(0, 55))
	menu.pressed.connect(show_menu)
	box.add_child(menu)


func toggle_pause() -> void:
	if state == "combat":
		state = "pause"
		var box := menu_layout("PAUSED", "Resume the fight or leave the arena")
		var resume := button("RESUME", Vector2(0, 54))
		resume.pressed.connect(toggle_pause)
		box.add_child(resume)
		var menu := button("MAIN MENU", Vector2(0, 54))
		menu.pressed.connect(show_menu)
		box.add_child(menu)
	elif state == "pause":
		clear_overlay()
		state = "combat"


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_detected = true
		if state == "combat": touch_ui.visible = true
		if event.pressed:
			if event.position.x < get_viewport().size.x * .38 and event.position.y > get_viewport().size.y * .46:
				touch_axis_id = event.index
			elif event.position.x > get_viewport().size.x * .42 and (event.position.x < get_viewport().size.x * .66 or event.position.y < get_viewport().size.y * .48):
				touch_look_id = event.index
		else:
			if event.index == touch_axis_id:
				touch_axis_id = -1
				touch_move = Vector2.ZERO
			if event.index == touch_look_id: touch_look_id = -1
	elif event is InputEventScreenDrag:
		if event.index == touch_axis_id:
			var anchor := Vector2(150, get_viewport().size.y - 145)
			touch_move = ((event.position - anchor) / 76.0).limit_length(1.0)
		elif event.index == touch_look_id:
			camera_yaw -= event.relative.x * .004
			camera_pitch = clampf(camera_pitch - event.relative.y * .004, -.65, .53)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_yaw -= event.relative.x * .004
		camera_pitch = clampf(camera_pitch - event.relative.y * .004, -.65, .53)
	elif event is InputEventMouseButton and event.pressed and state == "combat":
		if event.button_index == MOUSE_BUTTON_LEFT: execute_action("light")
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: toggle_pause()
			KEY_J: execute_action("light")
			KEY_K: execute_action("heavy")
			KEY_L: execute_action("blast")
			KEY_R: execute_action("beam")
			KEY_F: execute_action("ultimate")
			KEY_V: execute_action("vanish")
			KEY_SHIFT: execute_action("dodge")
			KEY_TAB: execute_action("lock")


func execute_action(kind: String) -> void:
	if state != "combat": return
	if kind == "lock":
		player.locked = not player.locked
		return
	if kind == "up" or kind == "down" or kind == "charge" or kind == "guard": return
	if kind == "heavy" and Input.is_key_pressed(KEY_SPACE): kind = "launcher"
	if player.action(kind):
		if kind == "dodge" or kind == "vanish":
			spawn_afterimage(player, Color(1,.65,.12,.36))
		if kind == "blast": play_sfx("ki_blast", -.6)
		if kind == "beam" or kind == "ultimate": play_sfx("beam", -1.2)
		if kind == "light" or kind == "heavy" or kind == "launcher":
			if enemy.stunned > 0.0:
				combo_count += 1
				combo_timer = 2.0


func _physics_process(delta: float) -> void:
	update_camera(delta)
	update_hud(delta)
	if state == "intro":
		fight_timer -= delta
		if fight_timer < 0.65: status_label.text = "FIGHT!"
		if fight_timer <= 0.0:
			state = "combat"
			status_label.text = ""
		return
	if state != "combat": return
	if hit_stop > 0.0:
		hit_stop -= delta
		return
	var wish := get_move_input()
	var rise := float(Input.is_key_pressed(KEY_SPACE) or touch_hold.get("up", false)) - float(Input.is_key_pressed(KEY_C) or touch_hold.get("down", false))
	player.set_guard(Input.is_key_pressed(KEY_Q) or touch_hold.get("guard", false))
	player.charging = Input.is_key_pressed(KEY_E) or touch_hold.get("charge", false)
	if player.charging and not was_charging: play_sfx("charge", -3.0)
	was_charging = player.charging
	player.simulate(delta, wish, rise, Input.is_key_pressed(KEY_SHIFT))
	ai_step(delta)
	update_projectiles(delta)
	update_effects(delta)
	combo_timer = maxf(0.0, combo_timer - delta)
	if combo_timer <= 0.0: combo_count = 0
	combo_label.text = str(combo_count) + " HIT COMBO" if combo_count >= 2 else ""


func get_move_input() -> Vector3:
	var x := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)) + touch_move.x
	var z := float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)) + touch_move.y
	var view_forward := Vector3(sin(camera_yaw), 0, -cos(camera_yaw))
	var view_right := Vector3(cos(camera_yaw), 0, sin(camera_yaw))
	return (view_right * x + view_forward * -z).limit_length(1.0)


func ai_step(delta: float) -> void:
	ai_timer -= delta
	var choose_action := ai_timer <= 0.0
	var separation := player.global_position - enemy.global_position
	var distance := separation.length()
	if ai_timer <= 0.0:
		ai_timer = randf_range(.38, .9)
		ai_mood = randf()
		if enemy.health < 32.0 and enemy.ki < 25.0:
			ai_mode = "retreat"
		elif distance > 10.0:
			ai_mode = "approach"
		elif enemy.stamina < 25.0:
			ai_mode = "guard"
		else:
			ai_mode = ["approach", "strafe", "guard", "attack", "retreat"][randi_range(0,4)]
	var dir := Vector3(separation.x, 0, separation.z).normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	var wish := Vector3.ZERO
	match ai_mode:
		"approach": wish = dir if distance > 2.1 else side * .6
		"retreat": wish = -dir
		"strafe": wish = side * (1.0 if ai_mood > .5 else -1.0)
		"attack": wish = dir * .35
		"guard": wish = side * .25
	enemy.set_guard(ai_mode == "guard" or (player.attack_name != "" and distance < 3.2 and ai_mood < .23))
	enemy.charging = ai_mode == "retreat" and enemy.ki < 40.0
	var rise := 0.0
	if player.global_position.y > enemy.global_position.y + 1.0: rise = 1.0
	elif enemy.global_position.y > player.global_position.y + 2.2: rise = -1.0
	elif ai_mood > .88 and distance > 4.0: rise = .6
	enemy.simulate(delta, wish, rise, ai_mode == "approach" and distance > 8.0)
	if choose_action and enemy.stunned <= 0.0:
		if distance < 3.4:
			if player.guarding and enemy.stamina > 14.0: enemy.action("heavy")
			elif ai_mood > .77: enemy.action("dodge")
			elif ai_mood > .55: enemy.action("heavy")
			else: enemy.action("light")
		elif distance < 15.0:
			if enemy.ki > 40.0 and ai_mood > .84: enemy.action("beam")
			elif enemy.ki > 9.0 and ai_mood > .42: enemy.action("blast")
			elif ai_mood > .75: enemy.action("dodge")
		if player.attack_name == "blast" and distance < 7.0 and ai_mood > .6:
			enemy.action("dodge")


func update_camera(delta: float) -> void:
	if not camera or not player: return
	if state == "portrait": return
	var pivot := player.global_position + Vector3.UP * 1.7
	if player.locked and enemy and enemy.health > 0.0:
		var toward := enemy.global_position - player.global_position
		var angle := atan2(-toward.x, -toward.z)
		camera_yaw = lerp_angle(camera_yaw, angle + 0.64, minf(1.0, delta * 3.0))
		pivot = pivot.lerp((player.global_position + enemy.global_position) * .5 + Vector3.UP * 1.5, .31)
	var forward := Vector3(sin(camera_yaw) * cos(camera_pitch), sin(camera_pitch), -cos(camera_yaw) * cos(camera_pitch))
	var distance := clampf(6.1 + player.global_position.distance_to(enemy.global_position) * .11, 6.4, 8.2)
	var target := pivot - forward * distance + Vector3.UP * .65 + Vector3(cos(camera_yaw), 0, sin(camera_yaw)) * 0.7
	shake = move_toward(shake, 0.0, delta * 4.5)
	if shake > 0.0: target += Vector3(randf_range(-1,1), randf_range(-1,1), randf_range(-1,1)) * shake
	camera.global_position = camera.global_position.lerp(target, minf(1.0, delta * 10.0))
	camera.look_at(pivot + forward * 2.0)
	fov_pulse = move_toward(fov_pulse, 0.0, delta * 24.0)
	camera.fov = lerpf(camera.fov, 55.0 + fov_pulse, minf(1.0, delta * 8.0))
	if lock_marker and state == "combat" and player.locked and enemy.health > 0.0:
		lock_marker.visible = not camera.is_position_behind(enemy.global_position + Vector3.UP * 1.5)
		lock_marker.position = camera.unproject_position(enemy.global_position + Vector3.UP * 3.0) - Vector2(13, 14)
	else:
		lock_marker.visible = false


func update_hud(_delta: float) -> void:
	if not p_health: return
	p_health.value = player.health / player.max_health * 100.0
	e_health.value = enemy.health / enemy.max_health * 100.0
	ki_bar.value = player.ki
	stamina_bar.value = player.stamina


func energy_ball(radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var ob := MeshInstance3D.new()
	ob.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	ob.material_override = mat
	add_child(ob)
	return ob


func on_blast(origin: Vector3, direction: Vector3, power: float, owner: ArenaFighter) -> void:
	var color := Color(1, .72, .13) if owner == player else Color(.23, .67, 1)
	var ball := energy_ball(.24, color)
	ball.global_position = origin
	projectile_data.append({"node":ball,"direction":direction,"owner":owner,"power":power,"life":1.6})
	spawn_flash(origin, color, .45)
	if owner != player: play_sfx("ki_blast", -4.5)


func on_beam(origin: Vector3, direction: Vector3, power: float, owner: ArenaFighter) -> void:
	var color := Color(1, .85, .25) if owner == player else Color(.32, .72, 1)
	var length := 18.0
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = .33
	beam_mesh.bottom_radius = .33
	beam_mesh.height = length
	var beam_node := MeshInstance3D.new()
	beam_node.mesh = beam_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	beam_node.material_override = mat
	add_child(beam_node)
	beam_node.global_position = origin + direction * length * .5
	beam_node.quaternion = Quaternion(Vector3.UP, direction)
	effect_data.append({"node":beam_node,"life":.45,"max":.45,"scale":1.0,"kind":"beam"})
	var target := enemy if owner == player else player
	if target.global_position.distance_to(origin) < length and distance_to_ray(target.global_position + Vector3.UP, origin, direction) < 1.7:
		target.take_hit(power, direction * 14.0 + Vector3.UP * 5.0, owner)
		on_impact(target.global_position + Vector3.UP * 1.2, 2.0)
	spawn_flash(origin, color, 1.0)
	fov_pulse = 12.0


func on_ultimate(origin: Vector3, direction: Vector3, owner: ArenaFighter) -> void:
	var color := Color(1, .79, .15) if owner == player else Color(.27, .72, 1)
	var sphere := energy_ball(1.45, color)
	sphere.global_position = origin + direction * 2.0
	effect_data.append({"node":sphere,"life":1.7,"max":1.7,"scale":1.0,"kind":"ultimate"})
	for i in range(6):
		var at := origin + direction * float(i + 1) * 3.0
		spawn_ring(at, color, 1.6 + i * .28)
	var target := enemy if owner == player else player
	if target.global_position.distance_to(origin) < 22.0:
		target.take_hit(44.0, direction * 18.0 + Vector3.UP * 9.0, owner)
		on_impact(target.global_position, 3.0)
	sun.light_energy = 3.4
	get_tree().create_tween().tween_property(sun, "light_energy", 0.72, 1.4)
	fov_pulse = 20.0
	shake = 1.0


func distance_to_ray(point: Vector3, origin: Vector3, direction: Vector3) -> float:
	return (point - (origin + direction * maxf(0.0, (point - origin).dot(direction)))).length()


func update_projectiles(delta: float) -> void:
	for i in range(projectile_data.size()-1, -1, -1):
		var p := projectile_data[i]
		p.life -= delta
		var ob: MeshInstance3D = p.node
		ob.global_position += p.direction * delta * 23.0
		ob.rotate_y(delta * 13.0)
		var target: ArenaFighter = enemy if p.owner == player else player
		if ob.global_position.distance_to(target.global_position + Vector3.UP * 1.4) < 1.15:
			target.take_hit(p.power, p.direction * 6.0 + Vector3.UP * 1.5, p.owner)
			on_impact(ob.global_position, .9)
			p.life = 0.0
		if p.life <= 0.0:
			ob.queue_free()
			projectile_data.remove_at(i)
		else:
			projectile_data[i] = p


func spawn_flash(where: Vector3, color: Color, scale: float) -> void:
	var ob := energy_ball(.37, color)
	ob.global_position = where
	ob.scale = Vector3.ONE * scale
	effect_data.append({"node":ob,"life":.19,"max":.19,"scale":scale,"kind":"flash"})


func spawn_ring(where: Vector3, color: Color, radius: float) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = radius * .93
	torus.outer_radius = radius
	var ob := MeshInstance3D.new()
	ob.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	ob.material_override = mat
	add_child(ob)
	ob.global_position = where
	effect_data.append({"node":ob,"life":.5,"max":.5,"scale":1.0,"kind":"ring"})


func on_impact(where: Vector3, severity: float) -> void:
	shake = maxf(shake, severity * .22)
	fov_pulse = maxf(fov_pulse, severity * 2.3)
	hit_stop = maxf(hit_stop, minf(.085, severity * .035))
	spawn_flash(where, Color(1, .85, .36), severity)
	spawn_ring(where, Color(1, .70, .24), .55 * severity)
	play_sfx("impact_bass", -1.5)
	play_sfx("impact_crack", -5.0)
	if where.y < 2.3:
		spawn_ring(Vector3(where.x, .06, where.z), Color(.8, .58, .32), severity * 1.1)
		spawn_ground_mark(Vector3(where.x,.025,where.z), severity)


func spawn_ground_mark(where: Vector3, severity: float) -> void:
	var disk := CylinderMesh.new()
	disk.top_radius = .58 * severity
	disk.bottom_radius = .58 * severity
	disk.height = .012
	var ob := MeshInstance3D.new()
	ob.mesh = disk
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(.17,.12,.10,.57)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ob.material_override = mat
	add_child(ob)
	ob.global_position = where
	effect_data.append({"node":ob,"life":5.5,"max":5.5,"scale":1.0,"kind":"mark"})


func spawn_afterimage(who: ArenaFighter, color: Color) -> void:
	var ghost := preload("res://assets/models/solar_ascendant.glb").instantiate()
	ghost.scale = Vector3.ONE * .92
	ghost.rotation.y = who.model.rotation.y
	for part in ghost.find_children("*", "MeshInstance3D", true, false):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = color
		part.material_override = m
	add_child(ghost)
	ghost.global_position = who.global_position
	ghost.rotation.y += who.rotation.y
	effect_data.append({"node":ghost,"life":.3,"max":.3,"scale":1.0,"kind":"ghost"})


func play_sfx(sound: String, volume: float = 0.0) -> void:
	var stream = load("res://audio/" + sound + ".wav")
	if stream == null: return
	var audio := AudioStreamPlayer.new()
	audio.stream = stream
	audio.volume_db = volume
	audio.pitch_scale = randf_range(.94, 1.06)
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()


func update_effects(delta: float) -> void:
	for i in range(effect_data.size()-1, -1, -1):
		var e := effect_data[i]
		e.life -= delta
		var node: Node3D = e.node
		if e.kind == "flash": node.scale = Vector3.ONE * e.scale * (1.0 + 2.0 * (1.0 - e.life/e.max))
		elif e.kind == "ring": node.scale = Vector3.ONE * (1.0 + 1.8 * (1.0 - e.life/e.max))
		elif e.kind == "ultimate": node.scale = Vector3.ONE * (1.0 + 3.0 * (1.0 - e.life/e.max))
		elif e.kind == "beam": node.scale.x = maxf(.02, e.life/e.max)
		if e.life <= 0.0:
			node.queue_free()
			effect_data.remove_at(i)
		else:
			effect_data[i] = e


func on_defeated(who: ArenaFighter) -> void:
	if state != "combat": return
	state = "finisher"
	fight_timer = 1.2
	status_label.text = "K.O."
	var won := who == enemy
	get_tree().create_timer(1.2).timeout.connect(func(): show_result(won))

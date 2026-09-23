extends Node3D
class_name ArenaFighter

signal impact(where: Vector3, severity: float)
signal blast(origin: Vector3, direction: Vector3, power: float, owner: ArenaFighter)
signal charged_sphere(origin: Vector3, direction: Vector3, power: float, owner: ArenaFighter)
signal beam(origin: Vector3, direction: Vector3, power: float, owner: ArenaFighter)
signal ultimate(origin: Vector3, direction: Vector3, owner: ArenaFighter)
signal defeated(who: ArenaFighter)

const TOON = preload("res://shaders/toon.gdshader")
const OUTLINE = preload("res://shaders/outline.gdshader")
const AURA = preload("res://shaders/aura.gdshader")
const FLAME = preload("res://shaders/flame.gdshader")
const LIGHTNING = preload("res://shaders/lightning.gdshader")
const SOLAR = preload("res://assets/models/solar_ascendant.glb")
const NOVA = preload("res://assets/models/solar_nova.glb")
const RIVAL = preload("res://assets/models/dusk_rival.glb")
const RIVAL_LOD = preload("res://assets/models/dusk_rival_lod.glb")

var is_player := false
var fighter_id := "solar"
var rival: ArenaFighter
var health := 100.0
var max_health := 100.0
var ki := 45.0
var max_ki := 100.0
var starting_ki := 45.0
var stamina := 100.0
var velocity := Vector3.ZERO
var facing := Vector3.FORWARD
var locked := true
var guarding := false
var charging := false
var flying := false
var invincible := 0.0
var stunned := 0.0
var attack_clock := 0.0
var attack_length := 0.0
var attack_active := false
var attack_name := ""
var attack_serial := 0
var combo_step := 0
var combo_window := 0.0
var move_amount := 0.0
var dash_timer := 0.0
var dash_direction := Vector3.FORWARD
var last_wish := Vector3.ZERO
var counter_timer := 0.0
var flash_timer := 0.0
var aura_strength := 0.55
var animation_time := 0.0
var model: Node3D
var animation_player: AnimationPlayer
var lod_model: Node3D
var lod_animation_player: AnimationPlayer
var lod_pivots := {}
var torso: Node3D
var head: Node3D
var l_arm: Node3D
var r_arm: Node3D
var l_forearm: Node3D
var r_forearm: Node3D
var l_leg: Node3D
var r_leg: Node3D
var aura_shell: MeshInstance3D
var aura_material: ShaderMaterial
var aura_particles: GPUParticles3D
var flame_material: ShaderMaterial
var lightning_material: ShaderMaterial
var move_speed := 9.0
var melee_power := 1.0
var ki_power := 1.0
var tint := Color(1.0, 0.7, 0.05)


func configure(player: bool, id: String = "") -> void:
	is_player = player
	fighter_id = id if id != "" else ("solar" if player else "dusk")
	match fighter_id:
		"nova":
			max_health = 92.0
			max_ki = 120.0
			starting_ki = 68.0
			move_speed = 10.6
			melee_power = 1.12
			ki_power = 1.28
			tint = Color(1.0, .88, .33)
		"dusk":
			max_health = 116.0
			max_ki = 90.0
			starting_ki = 55.0
			move_speed = 8.1
			melee_power = 1.23
			ki_power = .95
			tint = Color(.28, .66, 1.0)
		_:
			max_health = 100.0
			max_ki = 100.0
			starting_ki = 45.0
			move_speed = 9.0
			melee_power = 1.0
			ki_power = 1.0
			tint = Color(1.0, .70, .05)
	health = max_health
	ki = starting_ki


func reset_round(at: Vector3) -> void:
	health = max_health
	ki = starting_ki
	stamina = 100.0
	velocity = Vector3.ZERO
	facing = Vector3.FORWARD if is_player else Vector3.BACK
	locked = true
	guarding = false
	charging = false
	flying = false
	invincible = 0.0
	stunned = 0.0
	attack_clock = 0.0
	attack_length = 0.0
	attack_name = ""
	combo_step = 0
	combo_window = 0.0
	dash_timer = 0.0
	counter_timer = 0.0
	flash_timer = 0.0
	aura_strength = .55
	global_position = at
	rotation = Vector3.ZERO
	if animation_player: animation_player.stop()
	if lod_animation_player: lod_animation_player.stop()
	if lod_model:
		lod_model.visible = false
		model.visible = true
	for pivot in [torso, head, l_arm, r_arm, l_forearm, r_forearm, l_leg, r_leg]:
		if pivot: pivot.rotation = Vector3.ZERO


func _ready() -> void:
	match fighter_id:
		"nova": model = NOVA.instantiate()
		"dusk": model = RIVAL.instantiate()
		_: model = SOLAR.instantiate()
	add_child(model)
	model.scale = Vector3.ONE * 0.92
	model.rotation.y = PI
	animation_player = model.find_child("AnimationPlayer", true, false)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		style_mesh(node)
	if fighter_id == "dusk":
		lod_model = RIVAL_LOD.instantiate()
		add_child(lod_model)
		lod_model.scale = model.scale
		lod_model.rotation.y = PI
		lod_model.visible = false
		lod_animation_player = lod_model.find_child("AnimationPlayer", true, false)
		for node in lod_model.find_children("*", "MeshInstance3D", true, false):
			style_mesh(node)
		for pivot_name in ["Torso","Head","LArm","RArm","LForearm","RForearm","LLeg","RLeg"]:
			lod_pivots[pivot_name] = lod_model.find_child(pivot_name, true, false)
	torso = model.find_child("Torso", true, false)
	head = model.find_child("Head", true, false)
	l_arm = model.find_child("LArm", true, false)
	r_arm = model.find_child("RArm", true, false)
	l_forearm = model.find_child("LForearm", true, false)
	r_forearm = model.find_child("RForearm", true, false)
	l_leg = model.find_child("LLeg", true, false)
	r_leg = model.find_child("RLeg", true, false)
	build_aura()


func style_mesh(mesh_node: MeshInstance3D) -> void:
	if mesh_node.mesh == null:
		return
	for i in range(mesh_node.mesh.get_surface_count()):
		var original = mesh_node.mesh.surface_get_material(i)
		var color := Color(0.9, 0.7, 0.5)
		var material_name := ""
		if original is BaseMaterial3D:
			color = original.albedo_color
			material_name = original.resource_name.to_lower()
		if "skin warm contour" in material_name:
			color = Color(0.52, 0.26, 0.17)
		elif "skin warm" in material_name or "porcelain" in material_name:
			color = Color(0.77, 0.49, 0.35)
		elif "umber martial gi" in material_name:
			color = Color(0.20, 0.075, 0.045)
		elif "gi top" in material_name:
			color = Color(0.30, 0.135, 0.09)
		elif "cobalt" in material_name:
			color = Color(0.018, 0.12, 0.49)
		elif "blue highlight" in material_name:
			color = Color(0.06, 0.26, 0.75)
		elif "hair lit" in material_name:
			color = Color(1.0, 0.71, 0.10)
		elif "sun gold" in material_name:
			color = Color(0.95, 0.45, 0.013)
		elif "hair amber" in material_name:
			color = Color(0.61, 0.23, 0.01)
		elif "teal" in material_name:
			color = Color(0.025, 0.43, 0.39)
		elif "ivory" in material_name:
			color = Color(0.82, 0.87, 0.74)
		var name_low := mesh_node.name.to_lower()
		if fighter_id == "nova" and ("hair" in name_low or "spike" in name_low):
			color = Color(1.0, .83, .32) if i == 0 else Color(1.0, .65, .10)
		if fighter_id == "dusk":
			if "hair" in name_low or "spike" in name_low:
				color = Color(0.10, 0.17, 0.27) if i != 0 else Color(0.34, 0.55, 0.76)
			elif "gi" in name_low or "trouser" in name_low:
				color = Color(0.13, 0.16, 0.24)
			elif "blue" in name_low or "sash" in name_low or "sleeve" in name_low or "boot" in name_low:
				color = Color(0.63, 0.09, 0.14)
			elif "halo" in name_low:
				mesh_node.visible = false
			elif "eye" in name_low or "iris" in name_low:
				color = Color(0.92, 0.23, 0.17)
		var m := ShaderMaterial.new()
		m.shader = TOON
		m.set_shader_parameter("base_color", color)
		if "halo" in name_low or "hair" in name_low or "spike" in name_low:
			m.set_shader_parameter("glow", 0.44 if fighter_id == "nova" else (0.23 if fighter_id == "solar" else 0.12))
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE
		outline.set_shader_parameter("outline_width", 0.013)
		m.next_pass = outline
		mesh_node.set_surface_override_material(i, m)


func build_aura() -> void:
	aura_shell = MeshInstance3D.new()
	aura_shell.name = "EnergyAura"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 20
	sphere.rings = 10
	aura_shell.mesh = sphere
	aura_shell.position.y = 1.44
	aura_shell.scale = Vector3(0.86, 1.8, 0.7)
	aura_material = ShaderMaterial.new()
	aura_material.shader = AURA
	aura_material.set_shader_parameter("aura_color", Color(tint.r, tint.g, tint.b, 0.55))
	aura_shell.material_override = aura_material
	add_child(aura_shell)
	var flame_mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for i in range(18):
		var angle := TAU * float(i) / 18.0
		var height := 2.7 + 0.85 * sin(float(i) * 2.4) + 0.5 * cos(float(i) * 4.1)
		var r := 0.69 + 0.13 * sin(float(i) * 3.7)
		var mid := Vector3(cos(angle) * (r + 0.24), height * .56, sin(angle) * (r + 0.24))
		var tip := Vector3(cos(angle + .16) * (r + .02), height, sin(angle + .16) * (r + .02))
		var wide := .28 + .06 * sin(float(i) * 2.1)
		var sideways := Vector3(-sin(angle), 0, cos(angle))
		var a := Vector3(cos(angle) * r, .04, sin(angle) * r) - sideways * wide
		var b := Vector3(cos(angle) * r, .04, sin(angle) * r) + sideways * wide
		var c := mid - sideways * (wide * .55)
		var d := mid + sideways * (wide * .55)
		for v in [a, b, c, b, d, c, c, d, tip]: vertices.append(v)
		for uv_point in [Vector2(0,0),Vector2(1,0),Vector2(.2,.57),
			Vector2(1,0),Vector2(.8,.57),Vector2(.2,.57),
			Vector2(.2,.57),Vector2(.8,.57),Vector2(.5,1)]: uvs.append(uv_point)
		for _j in range(9): colors.append(Color(1,1,1,0.55 if i%3 else 0.77))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	flame_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var flames := MeshInstance3D.new()
	flames.name = "EnergyFlames"
	flames.mesh = flame_mesh
	flame_material = ShaderMaterial.new()
	flame_material.shader = FLAME
	flame_material.set_shader_parameter("energy_color", Color(tint.r,tint.g,tint.b,.60))
	flames.material_override = flame_material
	add_child(flames)
	var bolt_mesh := ArrayMesh.new()
	var bolt_vertices := PackedVector3Array()
	var bolt_uvs := PackedVector2Array()
	var bolt_colors := PackedColorArray()
	for bolt in range(8):
		var angle := TAU * float(bolt) / 8.0
		var side := Vector3(-sin(angle),0,cos(angle))
		var points := []
		for step in range(6):
			var h := .14 + float(step) * .48
			var r := .71 + .13 * sin(float(step)*2.8 + float(bolt)*1.7)
			points.append(Vector3(cos(angle)*r,h,sin(angle)*r) + side * (.10 * sin(float(step)*4.1+float(bolt))))
		for step in range(5):
			var a: Vector3 = points[step]
			var b: Vector3 = points[step+1]
			var width := .014
			for point in [a-side*width,a+side*width,b-side*width,a+side*width,b+side*width,b-side*width]:
				bolt_vertices.append(point)
				bolt_colors.append(Color(1,1,1,.67 if bolt%2 else .95))
			for uv_point in [Vector2(float(bolt)/8.0,0),Vector2(float(bolt)/8.0,0),Vector2(float(bolt)/8.0,1),
				Vector2(float(bolt)/8.0,0),Vector2(float(bolt)/8.0,1),Vector2(float(bolt)/8.0,1)]:
				bolt_uvs.append(uv_point)
	var bolt_arrays := []
	bolt_arrays.resize(Mesh.ARRAY_MAX)
	bolt_arrays[Mesh.ARRAY_VERTEX] = bolt_vertices
	bolt_arrays[Mesh.ARRAY_TEX_UV] = bolt_uvs
	bolt_arrays[Mesh.ARRAY_COLOR] = bolt_colors
	bolt_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bolt_arrays)
	var bolts := MeshInstance3D.new()
	bolts.mesh = bolt_mesh
	bolts.name = "KiLightning"
	lightning_material = ShaderMaterial.new()
	lightning_material.shader = LIGHTNING
	lightning_material.set_shader_parameter("bolt_color", Color(tint.r,tint.g,tint.b,1))
	bolts.material_override = lightning_material
	add_child(bolts)
	aura_particles = GPUParticles3D.new()
	aura_particles.amount = 36
	aura_particles.lifetime = 0.8
	aura_particles.explosiveness = 0.0
	aura_particles.position.y = 1.2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.10, 0.24)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.albedo_color = Color(tint.r, tint.g, tint.b, 0.6)
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = pmat
	aura_particles.draw_pass_1 = quad
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.7
	process.direction = Vector3.UP
	process.initial_velocity_min = 0.7
	process.initial_velocity_max = 2.8
	process.gravity = Vector3(0, 0.2, 0)
	process.scale_min = 0.45
	process.scale_max = 1.1
	aura_particles.process_material = process
	add_child(aura_particles)
	aura_particles.emitting = true


func simulate(delta: float, wish: Vector3, rise: float, sprint: bool) -> void:
	animation_time += delta
	invincible = maxf(0.0, invincible - delta)
	stunned = maxf(0.0, stunned - delta)
	combo_window = maxf(0.0, combo_window - delta)
	counter_timer = maxf(0.0, counter_timer - delta)
	flash_timer = maxf(0.0, flash_timer - delta)
	dash_timer = maxf(0.0, dash_timer - delta)
	attack_clock = maxf(0.0, attack_clock - delta)
	ki = clampf(ki + (18.0 if charging else 2.0) * delta, 0.0, max_ki)
	stamina = clampf(stamina + (8.0 if guarding else 17.0) * delta, 0.0, 100.0)
	if attack_clock == 0.0:
		attack_name = ""
		attack_active = false
	if stunned > 0.0:
		wish = Vector3.ZERO
		rise = 0.0
		guarding = false
		charging = false
	if charging or guarding:
		wish *= 0.32
	var planar := Vector3(wish.x, 0, wish.z)
	if planar.length() > 0.1: last_wish = planar.normalized()
	move_amount = clampf(planar.length(), 0.0, 1.0)
	var speed := move_speed * (1.52 if sprint and stamina > 1.0 else 1.0)
	if sprint and move_amount > 0.1:
		stamina = maxf(0.0, stamina - 5.0 * delta)
	if dash_timer > 0.0:
		speed *= 3.0
	if planar.length() > 1.0:
		planar = planar.normalized()
	var goal := dash_direction * speed if dash_timer > 0.0 else planar * speed
	velocity.x = move_toward(velocity.x, goal.x, delta * 37.0)
	velocity.z = move_toward(velocity.z, goal.z, delta * 37.0)
	if rise != 0.0 and stunned <= 0.0:
		flying = true
		velocity.y = move_toward(velocity.y, rise * speed * 0.75, delta * 22.0)
	elif flying:
		velocity.y = move_toward(velocity.y, 0.0, delta * 12.0)
	else:
		velocity.y -= 24.0 * delta
	global_position += velocity * delta
	if global_position.y <= 0.0:
		global_position.y = 0.0
		velocity.y = maxf(0.0, velocity.y)
		flying = false
	var horizontal := Vector2(global_position.x, global_position.z)
	if horizontal.length() > 16.5:
		horizontal = horizontal.normalized() * 16.5
		global_position.x = horizontal.x
		global_position.z = horizontal.y
	if rival and locked and stunned <= 0.0:
		var toward := rival.global_position - global_position
		toward.y = 0.0
		if toward.length() > 0.1:
			facing = facing.slerp(toward.normalized(), minf(1.0, delta * 12.0))
	elif move_amount > 0.12:
		facing = facing.slerp(planar.normalized(), minf(1.0, delta * 8.0))
	if facing.length() > 0.1:
		rotation.y = atan2(-facing.x, -facing.z)
	if attack_name == "" and stunned <= 0.0 and not guarding and not charging and animation_player:
		var desired := "flight" if flying else ("sprint" if move_amount > .25 else "fight_idle")
		if animation_player.current_animation != desired or not animation_player.is_playing():
			play_clip(desired, 1.25 if desired == "sprint" else 1.0)
	animate_pose(delta)
	aura_strength = move_toward(aura_strength, 1.7 if charging else (1.1 if fighter_id == "nova" else (0.92 if ki > max_ki * .75 else 0.55)), delta * 3.5)
	aura_material.set_shader_parameter("strength", aura_strength * .31)
	flame_material.set_shader_parameter("strength", aura_strength)
	lightning_material.set_shader_parameter("strength", .8 if charging else (.32 if ki > max_ki * .82 else 0.0))
	aura_particles.amount_ratio = clampf(aura_strength / 1.6, 0.2, 1.0)
	if lod_model and rival:
		var distant := global_position.distance_to(rival.global_position) > 13.0
		model.visible = not distant
		lod_model.visible = distant
	if flash_timer > 0.0:
		aura_shell.scale = Vector3(1.3, 2.1, 1.2)
	else:
		aura_shell.scale = aura_shell.scale.lerp(Vector3(0.86, 1.8, 0.7), minf(1.0, delta * 8.0))


func animate_pose(delta: float) -> void:
	if not torso or not l_arm or not r_arm:
		return
	if animation_player and animation_player.is_playing():
		return
	var t := animation_time
	var pulse := sin(t * (11.0 if move_amount > 0.2 else 2.7))
	var attack_progress := 1.0 - attack_clock / maxf(attack_length, 0.001)
	var blow := sin(attack_progress * PI) if attack_name != "" else 0.0
	var target_tilt := 0.08 * pulse if move_amount > 0.2 else 0.025 * pulse
	if flying:
		target_tilt -= 0.25
	torso.rotation.x = lerpf(torso.rotation.x, target_tilt, minf(1.0, delta * 10.0))
	var guard_raise := -1.0 if guarding else 0.0
	var left_pitch := -0.38 + guard_raise + 0.25 * pulse * move_amount
	var right_pitch := -0.38 + guard_raise - 0.25 * pulse * move_amount
	var leg_swing := pulse * move_amount * 0.42
	if attack_name.begins_with("light"):
		if attack_name == "light2":
			leg_swing = -blow * 1.25
			right_pitch = -1.0
		elif attack_name == "light3":
			left_pitch = -1.2 - blow * .45
			right_pitch = -.8
		elif attack_serial % 2 == 0:
			left_pitch = -0.2 - blow * 1.75
		else:
			right_pitch = -0.2 - blow * 1.75
	elif attack_name == "heavy" or attack_name == "launcher":
		right_pitch = -0.2 - blow * 2.0
		leg_swing = blow * 0.8
	elif attack_name == "blast" or attack_name == "beam" or attack_name == "ultimate" or attack_name == "volley" or attack_name == "sphere":
		right_pitch = -1.4
		left_pitch = -1.1
	elif attack_name == "dodge":
		left_pitch = -0.7
		right_pitch = -0.7
	if stunned > 0.0:
		left_pitch = 0.65
		right_pitch = 0.7
		leg_swing = -0.25
	l_arm.rotation.x = lerpf(l_arm.rotation.x, left_pitch, minf(1.0, delta * 18.0))
	r_arm.rotation.x = lerpf(r_arm.rotation.x, right_pitch, minf(1.0, delta * 18.0))
	l_arm.rotation.z = lerpf(l_arm.rotation.z, -0.25 if guarding else -0.12, minf(1.0, delta * 10.0))
	r_arm.rotation.z = lerpf(r_arm.rotation.z, 0.25 if guarding else 0.12, minf(1.0, delta * 10.0))
	l_leg.rotation.x = lerpf(l_leg.rotation.x, leg_swing, minf(1.0, delta * 11.0))
	r_leg.rotation.x = lerpf(r_leg.rotation.x, -leg_swing, minf(1.0, delta * 11.0))
	l_forearm.rotation.x = lerpf(l_forearm.rotation.x, -0.75 if guarding else -0.16, minf(1.0, delta * 15.0))
	r_forearm.rotation.x = lerpf(r_forearm.rotation.x, -0.75 if guarding else -0.16, minf(1.0, delta * 15.0))
	head.rotation.y = sin(t * 1.5) * 0.025
	if lod_model:
		for pivot_name in lod_pivots:
			var source: Node3D = model.find_child(pivot_name, true, false)
			var destination: Node3D = lod_pivots[pivot_name]
			if source and destination: destination.rotation = source.rotation


func action(kind: String) -> bool:
	if health <= 0.0 or stunned > 0.0:
		return false
	if kind == "dodge":
		if stamina < 22.0: return false
		stamina -= 22.0
		invincible = 0.29
		dash_timer = 0.22
		dash_direction = last_wish if last_wish.length() > .1 else facing
		attack_name = "dodge"
		attack_clock = 0.24
		attack_length = 0.24
		if animation_player: animation_player.stop()
		if lod_animation_player: lod_animation_player.stop()
		velocity += facing * 12.0
		return true
	if kind == "vanish":
		if rival == null or ki < 18.0 or stamina < 19.0: return false
		ki -= 18.0
		stamina -= 19.0
		invincible = .33
		attack_name = "dodge"
		attack_clock = .22
		attack_length = .22
		if animation_player: animation_player.stop()
		if lod_animation_player: lod_animation_player.stop()
		global_position = rival.global_position - rival.facing * 1.9
		global_position.y = rival.global_position.y
		facing = rival.facing
		velocity = Vector3.ZERO
		return true
	if attack_clock > 0.08 and not (kind == "light" and combo_window > 0.0):
		return false
	if kind == "light":
		combo_step = (combo_step + 1) % 4 if combo_window > 0.0 else 0
		combo_window = 0.85
		attack_serial += 1
		attack_name = "light" + str(combo_step)
		attack_length = 0.28 + combo_step * 0.035
		attack_clock = attack_length
		play_clip(["jab", "cross", "rising_kick", "elbow"][combo_step])
		strike(5.5 + combo_step * 1.2, 2.8 if combo_step < 3 else 5.2, 3.3)
		return true
	if kind == "heavy" or kind == "launcher":
		if stamina < 13.0: return false
		stamina -= 13.0
		attack_name = kind
		attack_length = 0.52
		attack_clock = attack_length
		play_clip(kind)
		strike(15.0, 7.5, 3.5, kind == "launcher")
		return true
	if kind == "blast":
		if ki < 9.0: return false
		ki -= 9.0
		attack_name = kind
		attack_length = 0.26
		attack_clock = attack_length
		play_clip("cross", 1.55)
		blast.emit(global_position + Vector3.UP * 1.5 + facing * 0.8, aim(), 11.0 * ki_power, self)
		return true
	if kind == "volley":
		if ki < 25.0: return false
		ki -= 25.0
		attack_name = kind
		attack_length = .65
		attack_clock = attack_length
		play_clip("beam", 1.4)
		var base := aim()
		for i in range(5):
			var angle := (float(i)-2.0) * .065
			blast.emit(global_position + Vector3.UP * (1.3 + float(i%2)*.22) + facing * .85,
				base.rotated(Vector3.UP, angle), 5.8 * ki_power, self)
		return true
	if kind == "sphere":
		if ki < 40.0: return false
		ki -= 40.0
		attack_name = kind
		attack_length = .92
		attack_clock = attack_length
		play_clip("beam", .82)
		charged_sphere.emit(global_position + Vector3.UP * 1.7 + facing * .9, aim(), 27.0 * ki_power, self)
		return true
	if kind == "beam":
		if ki < 35.0: return false
		ki -= 35.0
		attack_name = kind
		attack_length = 0.85
		attack_clock = attack_length
		play_clip("beam")
		beam.emit(global_position + Vector3.UP * 1.5 + facing * 0.8, aim(), 25.0 * ki_power, self)
		return true
	if kind == "ultimate":
		if ki < 80.0: return false
		ki -= 80.0
		attack_name = kind
		attack_length = 1.8
		attack_clock = attack_length
		play_clip("ultimate")
		ultimate.emit(global_position + Vector3.UP * 1.8, aim(), self)
		return true
	return false


func play_clip(clip: String, speed := 1.0) -> void:
	if animation_player and animation_player.has_animation(clip):
		animation_player.play(clip, .075, speed)
	if lod_animation_player and lod_animation_player.has_animation(clip):
		lod_animation_player.play(clip, .075, speed)


func aim() -> Vector3:
	if rival and locked:
		return (rival.global_position + Vector3.UP * 1.3 - (global_position + Vector3.UP * 1.5)).normalized()
	return facing.normalized()


func strike(damage: float, force: float, reach: float, launch := false) -> void:
	if rival == null: return
	var offset := rival.global_position - global_position
	if offset.length() < reach and facing.dot(Vector3(offset.x, 0, offset.z).normalized()) > 0.05:
		var impulse := aim() * force + Vector3.UP * (5.5 if launch else 1.1)
		rival.take_hit(damage * melee_power, impulse, self)
		impact.emit(rival.global_position + Vector3.UP * 1.35, 1.7 if launch else 0.8)


func take_hit(damage: float, impulse: Vector3, attacker: ArenaFighter) -> void:
	if health <= 0.0 or invincible > 0.0: return
	if guarding and stamina > 0.0:
		if counter_timer > 0.0:
			attacker.stunned = 0.38
			attacker.velocity -= attacker.facing * 8.0
			impact.emit(global_position + Vector3.UP * 1.5, 1.4)
			return
		stamina -= damage * (2.0 if fighter_id == "dusk" else 2.7)
		damage *= 0.12 if fighter_id == "dusk" else 0.18
		impulse *= 0.19
		if stamina <= 0.0:
			stunned = 0.8
			guarding = false
	else:
		stunned = 0.24 if damage < 14.0 else 0.47
		health = maxf(0.0, health - damage)
		play_clip("hit" if damage < 14.0 else "knockback")
	velocity += impulse
	flying = true
	flash_timer = 0.18
	if health <= 0.0:
		defeated.emit(self)


func set_guard(value: bool) -> void:
	if value and not guarding:
		counter_timer = 0.15
		play_clip("guard")
	guarding = value and stamina > 0.0 and stunned <= 0.0

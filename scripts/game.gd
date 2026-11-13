extends Node3D

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const PORT := 2456
const ROOM_SIZE := 24.0
var peer: ENetMultiplayerPeer
var players: Dictionary = {}
var fuses := 0
var monster: Node3D
var status_label: Label
var mission_label: Label
var touch_move := Vector2.ZERO
var touch_look := Vector2.ZERO
var look_touch_id := -1
var move_touch_id := -1

func _ready() -> void:
	_build_world()
	_build_ui()
	_spawn_player(multiplayer.get_unique_id())
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	set_process(true)

func _build_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.30, 0.23)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.61, 0.48)
	env.ambient_light_energy = 0.7
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 0.45
	add_child(sun)
	_make_box("Floor", Vector3(0,-0.25,0), Vector3(ROOM_SIZE,0.5,ROOM_SIZE), Color(0.48,0.43,0.30))
	_make_box("Ceiling", Vector3(0,4.2,0), Vector3(ROOM_SIZE,0.35,ROOM_SIZE), Color(0.62,0.58,0.44))
	_make_box("NorthWall", Vector3(0,2,-ROOM_SIZE/2), Vector3(ROOM_SIZE,4.5,0.35), Color(0.67,0.62,0.47))
	_make_box("SouthWall", Vector3(0,2,ROOM_SIZE/2), Vector3(ROOM_SIZE,4.5,0.35), Color(0.67,0.62,0.47))
	_make_box("WestWall", Vector3(-ROOM_SIZE/2,2,0), Vector3(0.35,4.5,ROOM_SIZE), Color(0.64,0.59,0.43))
	_make_box("EastWall", Vector3(ROOM_SIZE/2,2,0), Vector3(0.35,4.5,ROOM_SIZE), Color(0.64,0.59,0.43))
	for i in range(5):
		_make_box("Divider"+str(i), Vector3(-7.0 + i*3.5,1.7,-3.0), Vector3(0.22,3.4,8.0), Color(0.56,0.51,0.38))
	for i in range(4):
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(-7+i*4.5,3.65,-5)
		lamp.light_color = Color(1.0,0.88,0.62)
		lamp.light_energy = 1.4
		lamp.omni_range = 7
		add_child(lamp)
	for i in range(3):
		var fuse := Area3D.new()
		fuse.name = "Fuse"+str(i)
		fuse.position = Vector3(-7+i*6,0.6,5)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.35,0.5,0.2)
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.1,0.75,0.95)
		mesh.material_override = mat
		fuse.add_child(mesh)
		var shape := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = Vector3(1.1,1.2,1.1)
		shape.shape = s
		fuse.add_child(shape)
		fuse.set_meta("collected", false)
		fuse.body_entered.connect(_on_fuse_body_entered.bind(fuse))
		add_child(fuse)
	monster = CharacterBody3D.new()
	monster.name = "Watcher"
	var m := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.48
	capsule.height = 2.2
	m.mesh = capsule
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.045,0.035,0.04)
	m.material_override = mm
	monster.add_child(m)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.48
	cap.height = 2.2
	cs.shape = cap
	monster.add_child(cs)
	monster.position = Vector3(8,1.1,-7)
	add_child(monster)

func _make_box(n: String, p: Vector3, sz: Vector3, c: Color) -> void:
	var body := StaticBody3D.new()
	body.name = n
	body.position = p
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = sz
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mesh.material_override = mat
	body.add_child(mesh)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = sz
	cs.shape = shape
	body.add_child(cs)
	add_child(body)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(18,18)
	panel.add_theme_constant_override("separation",8)
	layer.add_child(panel)
	status_label = Label.new()
	status_label.text = "LOST TOGETHER  •  LAN: Not connected"
	panel.add_child(status_label)
	mission_label = Label.new()
	mission_label.text = "MISSION: Find 3 power fuses (0/3)"
	panel.add_child(mission_label)
	var host_btn := Button.new()
	host_btn.text = "HOST GAME"
	host_btn.pressed.connect(host_game)
	panel.add_child(host_btn)
	var join_row := HBoxContainer.new()
	panel.add_child(join_row)
	var ip := LineEdit.new()
	ip.name = "HostIP"
	ip.placeholder_text = "Host IP (e.g. 192.168.43.1)"
	ip.custom_minimum_size.x = 230
	join_row.add_child(ip)
	var join_btn := Button.new()
	join_btn.text = "JOIN"
	join_btn.pressed.connect(func(): join_game(ip.text.strip_edges()))
	join_row.add_child(join_btn)
	var help := Label.new()
	help.text = "Desktop: WASD + mouse | Mobile: left drag to move, right drag to look"
	panel.add_child(help)
	var touch := Label.new()
	touch.text = "Touch: use left side to move and right side to turn"
	touch.position = Vector2(18,650)
	layer.add_child(touch)

func host_game() -> void:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 12)
	if err != OK:
		status_label.text = "Host failed: "+str(err)
		return
	multiplayer.multiplayer_peer = peer
	status_label.text = "HOSTING on port "+str(PORT)+" • Share your hotspot IP"

func join_game(ip: String) -> void:
	if ip.is_empty():
		status_label.text = "Enter host phone IP first"
		return
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		status_label.text = "Join failed: "+str(err)
		return
	multiplayer.multiplayer_peer = peer
	status_label.text = "Connecting to "+ip+"..."

func _on_peer_connected(id: int) -> void:
	# The server announces the new peer to every connected device.
	_spawn_player(id)
	_spawn_remote_player.rpc(id)
	# Also send every already-connected player to the newcomer.
	for existing_id in players.keys():
		_spawn_remote_player.rpc_id(id, int(existing_id))

@rpc("authority", "call_local", "reliable")
func _spawn_remote_player(id: int) -> void:
	if not players.has(id):
		_spawn_player(id)

func _on_peer_disconnected(id: int) -> void:
	if players.has(id):
		players[id].queue_free()
		players.erase(id)

func _spawn_player(id: int) -> void:
	if players.has(id):
		return
	var p := PLAYER_SCENE.instantiate()
	p.name = str(id)
	p.set_multiplayer_authority(id)
	p.position = Vector3(-9,0.1,8) if id == multiplayer.get_unique_id() else Vector3(-9,0.1,8)
	add_child(p)
	players[id] = p

func _on_fuse_body_entered(body: Node3D, fuse: Area3D) -> void:
	if body is CharacterBody3D and body.name == str(multiplayer.get_unique_id()) and not fuse.get_meta("collected"):
		if multiplayer.is_server():
			_collect_fuse(fuse.name)
		else:
			_request_fuse.rpc_id(1, fuse.name)

@rpc("any_peer", "reliable")
func _request_fuse(fuse_name: String) -> void:
	if multiplayer.is_server():
		_collect_fuse(fuse_name)

func _collect_fuse(fuse_name: String) -> void:
	var f := get_node_or_null(fuse_name)
	if f == null or f.get_meta("collected"):
		return
	f.set_meta("collected",true)
	fuses += 1
	f.hide()
	f.set_deferred("monitoring",false)
	_update_fuses.rpc(fuses)

@rpc("authority", "call_local", "reliable")
func _update_fuses(value: int) -> void:
	fuses = value
	mission_label.text = "MISSION: Find 3 power fuses ("+str(fuses)+"/3)"
	if fuses >= 3:
		mission_label.text = "POWER RESTORED — FIND THE EXIT"

func _process(delta: float) -> void:
	if multiplayer.is_server() and is_instance_valid(monster):
		var target: Node3D
		var best := INF
		for p in players.values():
			if not is_instance_valid(p): continue
			var d := monster.global_position.distance_to(p.global_position)
			if d < best:
				best = d
				target = p
		if target and best > 1.5:
			var dir := (target.global_position-monster.global_position).normalized()
			monster.velocity = dir * 2.3
			monster.move_and_slide()
			monster.look_at(Vector3(target.global_position.x,monster.global_position.y,target.global_position.z))
		_sync_monster.rpc(monster.global_position, monster.rotation.y)
			if best < 1.25:
				status_label.text = "THE WATCHER FOUND YOU — regroup and try again"

@rpc("authority", "call_remote", "unreliable")
func _sync_monster(pos: Vector3, yaw: float) -> void:
	if not multiplayer.is_server() and is_instance_valid(monster):
		monster.global_position = monster.global_position.lerp(pos, 0.7)
		monster.rotation.y = yaw

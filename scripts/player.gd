extends CharacterBody3D

@export var move_speed := 4.2
@export var look_sensitivity := 0.003
var gravity := 18.0
var camera: Camera3D
var pitch := 0.0
var mobile_move := Vector2.ZERO
var mobile_look := Vector2.ZERO
var move_finger := -1
var look_finger := -1
var touch_start := {}

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = 1.8
	mesh.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18,0.36,0.55) if is_multiplayer_authority() else Color(0.25,0.25,0.28)
	mesh.material_override = mat
	mesh.position.y = 0.9
	add_child(mesh)
	camera = Camera3D.new()
	camera.position.y = 1.55
	camera.current = is_multiplayer_authority()
	add_child(camera)
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * look_sensitivity)
		pitch = clamp(pitch-event.relative.y*look_sensitivity,-1.35,1.35)
		camera.rotation.x = pitch
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < get_viewport().get_visible_rect().size.x*0.48 and move_finger == -1:
				move_finger = event.index
				touch_start[move_finger] = event.position
			elif look_finger == -1:
				look_finger = event.index
				touch_start[look_finger] = event.position
		else:
			if event.index == move_finger:
				move_finger = -1
				mobile_move = Vector2.ZERO
			if event.index == look_finger:
				look_finger = -1
				mobile_look = Vector2.ZERO
	if event is InputEventScreenDrag:
		if event.index == move_finger:
			mobile_move = (event.position-touch_start[move_finger]).limit_length(90)/90.0
		elif event.index == look_finger:
			rotate_y(-event.relative.x*0.006)
			pitch = clamp(pitch-event.relative.y*0.006,-1.35,1.35)
			camera.rotation.x = pitch
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	var input_vec := Vector2(
		Input.get_action_strength("move_right")-Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back")-Input.get_action_strength("move_forward")
	)
	if mobile_move.length() > 0.08:
		input_vec = Vector2(mobile_move.x,mobile_move.y)
	var direction := (transform.basis * Vector3(input_vec.x,0,input_vec.y)).normalized()
	velocity.x = direction.x*move_speed
	velocity.z = direction.z*move_speed
	if not is_on_floor():
		velocity.y -= gravity*delta
	else:
		velocity.y = 0
	move_and_slide()
	_sync_state.rpc(global_position, rotation.y, pitch)

@rpc("authority", "call_remote", "unreliable")
func _sync_state(pos: Vector3, yaw: float, cam_pitch: float) -> void:
	if is_multiplayer_authority(): return
	global_position = global_position.lerp(pos,0.65)
	rotation.y = yaw
	if camera: camera.rotation.x = cam_pitch

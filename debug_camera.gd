class_name DebugCamera
extends Camera3D

# Modifier keys' speed multiplier
const SHIFT_MULTIPLIER = 2.5
const ALT_MULTIPLIER = 1.0 / SHIFT_MULTIPLIER

@export var verbose_console = false
@export_range(0.0, 1.0) var sensitivity: float = 0.25
@export var inspect_ray_length : float = 1000

# Mouse state
var _mouse_position = Vector2(0.0, 0.0)
var _total_pitch = 0.0

# Movement state
var _direction = Vector3(0.0, 0.0, 0.0)
var _velocity = Vector3(0.0, 0.0, 0.0)
@export var _acceleration = 30
@export var _deceleration = -10
@export var _vel_multiplier = 4

# Keyboard state
var _w = false
var _s = false
var _a = false
var _d = false
var _q = false
var _z = false
var _shift = false
var _alt = false
var _tab = false
var _esc = false

# Wireframe view mode
var wireframe = false
var wireframe_enable = false


func _init():
	RenderingServer.set_debug_generate_wireframes(true)


func _input(event):
	# Receives mouse motion
	if event is InputEventMouseMotion:
		_mouse_position = event.relative
	
	# Receives mouse button input
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT: # Only allows rotation if right click down
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE)
			
			MOUSE_BUTTON_WHEEL_UP: # Increases max velocity
				_vel_multiplier = clamp(_vel_multiplier * 1.1, 0.2, 20)
				if verbose_console:
					print("debug_camera: movement speed = ", _vel_multiplier)
			
			MOUSE_BUTTON_WHEEL_DOWN: # Decereases max velocity
				_vel_multiplier = clamp(_vel_multiplier / 1.1, 0.2, 20)
				if verbose_console:
					print("debug_camera: movement speed = ", _vel_multiplier)
			
			MOUSE_BUTTON_MIDDLE:
				if (event.pressed):
					inspect_node()

	# Receives key input
	if event is InputEventKey:
		match event.keycode:
			KEY_W:
				_w = event.pressed
			KEY_S:
				_s = event.pressed
			KEY_A:
				_a = event.pressed
			KEY_D:
				_d = event.pressed
			KEY_Q:
				_q = event.pressed
			KEY_Z:
				_z = event.pressed
			KEY_SHIFT:
				_shift = event.pressed
			KEY_ALT:
				_alt = event.pressed
			KEY_TAB:
				_tab = event.pressed
			KEY_ESCAPE:
				_esc = event.pressed


# Updates mouselook and movement every frame
func _process(delta):
	_update_mouselook()
	_update_movement(delta)


# Updates camera movement
func _update_movement(delta):
	# Computes desired direction from key states
	_direction = Vector3(
		(_d as float) - (_a as float), 
		(_q as float) - (_z as float),
		(_s as float) - (_w as float)
	)
	
	# Computes the change in velocity due to desired direction and "drag"
	# The "drag" is a constant acceleration on the camera to bring it's velocity to 0
	var offset = _direction.normalized() * _acceleration * _vel_multiplier * delta \
		+ _velocity.normalized() * _deceleration * _vel_multiplier * delta
	
	# Compute modifiers' speed multiplier
	var speed_multi = 1
	
	if _shift:
		speed_multi *= SHIFT_MULTIPLIER
	if _alt:
		speed_multi *= ALT_MULTIPLIER
	
	# Checks if we should bother translating the camera
	if _direction == Vector3.ZERO and offset.length_squared() > _velocity.length_squared():
		# Sets the velocity to 0 to prevent jittering due to imperfect deceleration
		_velocity = Vector3.ZERO
	else:
		# Clamps speed to stay within maximum value (_vel_multiplier)
		_velocity.x = clamp(_velocity.x + offset.x, -_vel_multiplier, _vel_multiplier)
		_velocity.y = clamp(_velocity.y + offset.y, -_vel_multiplier, _vel_multiplier)
		_velocity.z = clamp(_velocity.z + offset.z, -_vel_multiplier, _vel_multiplier)
	
		translate(_velocity * delta * speed_multi)
	
	# Toggle wireframe view
	if _tab:
		if wireframe_enable:
			wireframe_enable = false
			wireframe = !wireframe
			
			var vp = get_viewport()
			
			if wireframe:
				vp.debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
			
			else:
				vp.debug_draw = Viewport.DEBUG_DRAW_DISABLED
	else:
		wireframe_enable = true
	
	# Quit game
	if _esc:
		get_tree().quit()


# Updates mouse look 
func _update_mouselook():
	# Only rotates mouse if the mouse is captured
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_mouse_position *= sensitivity
		var yaw = _mouse_position.x
		var pitch = _mouse_position.y
		_mouse_position = Vector2(0, 0)
		
		# Prevents looking up/down too far
		pitch = clamp(pitch, -90 - _total_pitch, 90 - _total_pitch)
		_total_pitch += pitch
	
		rotate_y(deg_to_rad(-yaw))
		rotate_object_local(Vector3(1,0,0), deg_to_rad(-pitch))


func inspect_node():
	var space_state = get_world_3d().direct_space_state
	var mousepos = get_viewport().get_mouse_position()
	var origin = project_ray_origin(mousepos)
	var end = origin + project_ray_normal(mousepos) * inspect_ray_length
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	
	var result = space_state.intersect_ray(query)
	
	if _shift:
		print("debug_camera: ", result)
	else:
		print("debug_camera: ", result["collider"])
	
	return result


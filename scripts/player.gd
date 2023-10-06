extends CharacterBody3D

#testing git
# Player node refs
@onready var neck = $Neck
@onready var head = $Neck/Head
@onready var eyes = $Neck/Head/Eyes
@onready var camera = $Neck/Head/Eyes/Camera3D
@onready var default_collision = $DefaultCollision
@onready var crouching_collision = $CrouchingCollision
@onready var ray_cast = $RayCast3D
@onready var anim_player = $Neck/Head/Eyes/AnimationPlayer

# Movement vars
@export var crouch_speed = 3.0
@export var walk_speed = 5.0
@export var run_speed = 8.0
@export var slide_speed = 10.0
@export var current_speed = 5.0
@export var jump_velocity = 4.5
var slide_timer = 0.0
var slide_timer_max = 1.0
var slide_tilt = 7.0
var slide_dir = Vector2.ZERO
var last_velocity = Vector3.ZERO
var crouch_depth = -0.5

# States
var walking = false
var running = false
var crouching = false
var free_looking = false
var sliding = false

# Lerp multipliers
var lerp_speed = 10.0
var air_lerp_speed = 3.0

# Configurable controls
@export var h_mouse_sens = 0.08
@export var v_mouse_sens = 0.08

# Head bob
const HEAD_BOB_RUN = 22.0
const HEAD_BOB_WALK = 14.0
const HEAD_BOB_CROUCH = 10.0

const HEAD_BOB_RUN_INTENSITY = 0.2
const HEAD_BOB_WALK_INTENSITY = 0.1
const HEAD_BOB_CROUCH_INTENSITY = 0.05

var head_bob_temp_intensity = 0.0
var head_bob_vector = Vector2.ZERO
var head_bob_index = 0.0

# Misc
var direction = Vector3.ZERO
var free_look_tilt = 8

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta):
	# Get movement direction
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
		sliding = false
		anim_player.play("jump")
	
	# Handle landing
	if is_on_floor():
		if last_velocity.y < -10.0:
			anim_player.play("roll")
			print(last_velocity.y)
		elif last_velocity.y < 0.0:
			anim_player.play("land")
			print(last_velocity.y)
	
	# Movement states
	# Crouch
	if Input.is_action_pressed("crouch") or sliding:
		if is_on_floor():
			current_speed = lerp(current_speed, crouch_speed, delta * lerp_speed)
			head.position.y = lerp(head.position.y, crouch_depth, delta * lerp_speed)
			default_collision.disabled = true
			crouching_collision.disabled = false
		
		if running:
			if is_on_floor():
				# Slide
				slide_dir = Input.get_vector("left", "right", "forward", "backward")
				if slide_dir != Vector2.ZERO:
					sliding = true
					slide_timer = slide_timer_max
					free_looking = true
					print_rich("[color=green]Slide start[/color]")
		
		walking = false
		running = false
		crouching = false
	# Stand
	elif !ray_cast.is_colliding():
		default_collision.disabled = false
		crouching_collision.disabled = true
		head.position.y = lerp(head.position.y, 0.0, delta * lerp_speed)
		if Input.is_action_pressed("sprint"):
			# Run
			current_speed = lerp(current_speed, run_speed, delta * lerp_speed)
			walking = false
			running = true
			crouching = false
		else:
			# Walk
			current_speed = lerp(current_speed, walk_speed, delta * lerp_speed)
			walking = true
			running = false
			crouching = false
	
	# Free look
	if Input.is_action_pressed("free_look") or sliding:
		free_looking = true
		if sliding:
			eyes.rotation.z = lerp(eyes.rotation.z, -deg_to_rad(slide_tilt), delta * lerp_speed)
		else:
			eyes.rotation.z = -deg_to_rad(neck.rotation.y * free_look_tilt)
	else:
		free_looking = false
		neck.rotation.y = lerp(neck.rotation.y, 0.0, delta * lerp_speed)
		eyes.rotation.z = lerp(eyes.rotation.y, 0.0, delta * lerp_speed)
	
	if sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			sliding = false
			free_looking = false
			print_rich("[color=red]Slide end[/color]")
	
	# Head bob
	if running:
		head_bob_temp_intensity = HEAD_BOB_RUN_INTENSITY
		head_bob_index += HEAD_BOB_RUN * delta
	elif walking:
		head_bob_temp_intensity = HEAD_BOB_WALK_INTENSITY
		head_bob_index += HEAD_BOB_WALK * delta
	elif crouching:
		head_bob_temp_intensity = HEAD_BOB_CROUCH_INTENSITY
		head_bob_index += HEAD_BOB_CROUCH * delta
	
	if is_on_floor() and !sliding and input_dir != Vector2.ZERO:
		head_bob_vector.y = sin(head_bob_index)
		head_bob_vector.x = sin(head_bob_index / 2) + 0.5
		
		eyes.position.y = lerp(eyes.position.y, head_bob_vector.y * (head_bob_temp_intensity / 2), delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, head_bob_vector.x * head_bob_temp_intensity, delta * lerp_speed)
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_speed)
	
	# Handle movement/deceleration
	if is_on_floor():
		direction = lerp(direction,(transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * lerp_speed)
	else:
		if input_dir != Vector2.ZERO:
			direction = lerp(direction,(transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * air_lerp_speed)
	
	if sliding:
		direction = (transform.basis * Vector3(slide_dir.x, 0.0, slide_dir.y)).normalized()
		current_speed = (slide_timer + 0.1) * slide_speed
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	
	last_velocity = velocity
	
	move_and_slide()


func _input(event):
	if event is InputEventMouseMotion:
		if free_looking:
			neck.rotate_y(deg_to_rad(-event.relative.x * h_mouse_sens))
			neck.rotation.y = clamp(neck.rotation.y, deg_to_rad(-100), deg_to_rad(100))
		else:
			rotate_y(deg_to_rad(-event.relative.x * h_mouse_sens))
		head.rotate_x(deg_to_rad(-event.relative.y * v_mouse_sens))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))

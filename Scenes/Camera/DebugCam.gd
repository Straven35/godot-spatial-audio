extends CharacterBody3D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var speed := 2.0
var walkSpeed := 2.0
var sprintSpeed := 25.0
var accel := 10.0
var direction := Vector3()
var inputDir := Vector2()
var cameraAngle := 0.0
var ACTIVATED := false

@onready var mainCam := $camera

var mouselock := true
var movelock := false

func _physics_process(delta):
	_do_move(delta)
	$Control/FPS.text = str(Engine.get_frames_per_second())
	

func _do_move(delta):
	var head_basis : Basis
	direction = Vector3()
	
	if movelock:
		head_basis = get_global_transform().basis
	else:
		head_basis = mainCam.get_global_transform().basis
	
	if mouselock:
		inputDir = Input.get_vector("left", "right", "forward", "back").normalized()
		direction = (head_basis * Vector3(inputDir.x, 0, inputDir.y))
	
	# if Input.is_action_pressed("sprint"):
	# 	speed = sprintSpeed
	# else:
	speed = walkSpeed
	
	if Input.is_action_pressed("ui_page_up"):
		direction.y += speed
	if Input.is_action_pressed("ui_page_down"):
		direction.y -= speed
	
	direction = direction.normalized()
	velocity = lerp(velocity, direction * speed, accel * delta)
#	velocity.x = lerp(velocity.x, direction.x * speed, accel * delta)
#	velocity.z = lerp(velocity.z, direction.z * speed, accel * delta)
#	velocity.y = lerp(velocity.y, direction.y * speed, accel * delta)
	
	move_and_slide()
	

func _input(event):
	if Input.is_action_just_pressed("lock"):
		movelock = !movelock
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_UP):
		walkSpeed = min(walkSpeed + 0.1, sprintSpeed)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN):
		walkSpeed = max(walkSpeed - 0.1, 0.1)
	
	if Input.is_action_just_released("ui_cancel"):
		print("hi")
		mouselock = !mouselock
		if mouselock:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if event is InputEventMouseMotion && mouselock:
		rotate_y(deg_to_rad(-event.relative.x * 0.3))
		
		var x_delta = event.relative.y * 0.3
		
		if cameraAngle + x_delta > -90 and cameraAngle + x_delta < 90:
			mainCam.rotate_x(deg_to_rad(-x_delta))
			cameraAngle += x_delta

# Called when the node enters the scene tree for the first time.
# func _ready():
# 	Global.debugPlayer = self
#	if Global.debugCam:
#		Global.debugPlayer = self
#		Global.Player = self


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

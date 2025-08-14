extends Node3D

var do_move : bool = false
var going_up : bool = false
var offset : float = 4.0

func _physics_process(delta):
	if !do_move:
		return
	
	if going_up:
		position.y = lerp(position.y, -offset, delta * 5)
		if is_equal_approx(position.y, -offset):
			going_up = !going_up
			do_move = !do_move
	else:
		position.y = lerp(position.y, 0.0, delta * 5)
		if is_equal_approx(position.y, 0.0):
			going_up = !going_up
			do_move = !do_move
	pass

func _input(_event):
	if Input.is_action_just_released("ui_down") && !do_move:
		do_move = true

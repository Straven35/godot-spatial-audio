extends Node3D

@export var active : bool = true

var timer : int = 0
var interval : int = 5000
var next : int = 0

func _physics_process(_delta):
    if !active:
        return
    var cur_time : int = Time.get_ticks_msec()
    if cur_time > timer:
        timer = cur_time + interval
        get_child(next).call_deferred("play")
        next = 1 if next == 0 else 0
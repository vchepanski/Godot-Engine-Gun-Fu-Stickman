extends Area2D

signal missed_shot

var speed: float = 900.0
var _start_pos: Vector2
var _initialized: bool = false
var _hit: bool = false
var _grace_frames: int = 0

func _ready() -> void:
	add_to_group("bullets")
	monitorable = false
	area_entered.connect(_on_area_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)

func _process(delta: float) -> void:
	_grace_frames += 1
	if not _initialized:
		_start_pos = global_position
		_initialized = true
	var direction := Vector2.RIGHT.rotated(rotation)
	global_position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		_hit = true
		area.die()
		queue_free()

func _on_screen_exited() -> void:
	if not _hit and _grace_frames > 5:
		missed_shot.emit()
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 3, Color.YELLOW)
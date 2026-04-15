extends Area2D

signal died
signal shot_fired

const ARM_LENGTH := 22.0
const GUN_SCALE := 0.035
const GRIP_OFFSET_X := 0.73

var _is_dead: bool = false
var _reaction_time: float
var _timer: Timer
var _elapsed: float = 0.0
var _dying: bool = false
var _flash_timer: float = 0.0
var _gun_angle: float = 0.0
var _gun_texture: ImageTexture

func _ready() -> void:
	add_to_group("enemies")
	var img := Image.new()
	img.load("res://assets/weapons/pistol_clean.png")
	_gun_texture = ImageTexture.create_from_image(img)
	_reaction_time = randf_range(3.0, 5.0)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = _reaction_time
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	_timer.start()

func _process(delta: float) -> void:
	if _dying:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		queue_redraw()
		return
	_elapsed += delta
	_flash_timer = maxf(0.0, _flash_timer - delta)
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]):
		_gun_angle = (players[0].global_position - global_position).angle()
	queue_redraw()

func _on_timer_timeout() -> void:
	if not _is_dead:
		shot_fired.emit()
		_is_dead = true
		queue_free()

func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	_dying = true
	_flash_timer = 0.08
	_timer.stop()
	died.emit()
	_play_death_animation()

func _play_death_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2.0, 2.0), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)

func _draw() -> void:
	if _is_dead and _flash_timer <= 0.0:
		return
	var urgency := 1.0 - (_timer.time_left / _reaction_time) if _reaction_time > 0 else 0.0
	var base_color := Color.CRIMSON.lerp(Color.YELLOW, urgency)
	var c := Color.WHITE if _flash_timer > 0.0 else base_color
	draw_circle(Vector2(0, -24), 10, c)
	draw_line(Vector2(-5, -26), Vector2(-2, -24), Color.BLACK if _flash_timer <= 0.0 else Color.WHITE, 1.5)
	draw_line(Vector2(-2, -26), Vector2(-5, -24), Color.BLACK if _flash_timer <= 0.0 else Color.WHITE, 1.5)
	draw_line(Vector2(2, -26), Vector2(5, -24), Color.BLACK if _flash_timer <= 0.0 else Color.WHITE, 1.5)
	draw_line(Vector2(5, -26), Vector2(2, -24), Color.BLACK if _flash_timer <= 0.0 else Color.WHITE, 1.5)
	draw_line(Vector2(0, -14), Vector2(0, -12), c, 2)
	draw_line(Vector2(-10, -12), Vector2(10, -12), c, 2)
	draw_line(Vector2(0, -12), Vector2(0, 12), c, 3)
	draw_line(Vector2(-10, -12), Vector2(-18, 2), c, 2)
	draw_line(Vector2(0, 12), Vector2(12, 36), c, 2)
	draw_line(Vector2(0, 12), Vector2(-12, 36), c, 2)
	var shoulder := Vector2(10, -12)
	var arm_end := shoulder + Vector2(ARM_LENGTH, 0).rotated(_gun_angle)
	draw_line(shoulder, arm_end, c, 2)
	var flip_x := -1.0
	var flip_y := -1.0 if (_gun_angle > PI / 2.0 or _gun_angle < -PI / 2.0) else 1.0
	var tex := _gun_texture
	var tex_w := tex.get_size().x
	var tex_h := tex.get_size().y
	draw_set_transform(arm_end, _gun_angle, Vector2(GUN_SCALE * flip_x, GUN_SCALE * flip_y))
	draw_texture(tex, Vector2(-tex_w * (1.0 - GRIP_OFFSET_X), -tex_h * 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if urgency > 0.5:
		var glow_alpha := (urgency - 0.5) / 0.5
		var barrel_length := tex_w * (1.0 - GRIP_OFFSET_X) * GUN_SCALE
		var gun_end := arm_end + Vector2(barrel_length, 0).rotated(_gun_angle)
		draw_circle(gun_end, 5, Color(1, 0.3, 0.0, glow_alpha * 0.5))
		var target_end := gun_end + Vector2(40, 0).rotated(_gun_angle)
		draw_line(gun_end, target_end, Color(1, 0.2, 0.2, glow_alpha * 0.3), 1)
extends Area2D

signal lives_changed(lives: int)
signal lives_depleted

const MAX_LIVES := 3
const DIRECT_HIT_RADIUS := 50.0
const ARM_LENGTH := 28.0
const FLASH_DURATION := 0.08
const RECOIL_DISTANCE := 8.0
const GUN_SCALE := 0.1

var lives: int = MAX_LIVES
var _is_alive: bool = true
var _left_touch_index: int = -1
var _right_touch_index: int = -1
var _left_touch_pos: Vector2 = Vector2.ZERO
var _right_touch_pos: Vector2 = Vector2.ZERO
var _left_arm_angle: float = 2.36
var _right_arm_angle: float = 0.79
var _left_shoulder := Vector2(-12, -14)
var _right_shoulder := Vector2(12, -14)
var _left_flash_timer: float = 0.0
var _right_flash_timer: float = 0.0
var _left_flash_color: Color = Color.YELLOW
var _right_flash_color: Color = Color.YELLOW
var _hit_player: AudioStreamPlayer
var _miss_player: AudioStreamPlayer
var _gun_texture: ImageTexture

func _ready() -> void:
	add_to_group("player")
	_gun_texture = WeaponTex.get_clean_texture()
	_hit_player = AudioStreamPlayer.new()
	_hit_player.stream = _generate_hit_sound()
	add_child(_hit_player)
	_miss_player = AudioStreamPlayer.new()
	_miss_player.stream = _generate_miss_sound()
	add_child(_miss_player)

func _generate_hit_sound() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.08
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var env := maxf(0.0, 1.0 - (t / duration))
		var sample := env * 0.7 * sin(2.0 * PI * 880.0 * t) + env * 0.3 * sin(2.0 * PI * 1320.0 * t)
		var val := int(sample * 32767.0)
		val = mini(maxi(val, -32768), 32767)
		data.append(val & 0xFF)
		data.append((val >> 8) & 0xFF)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

func _generate_miss_sound() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.2
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var freq := 220.0 - 110.0 * (t / duration)
		var env := maxf(0.0, 1.0 - (t / duration)) * 0.5
		var sample := env * sin(2.0 * PI * freq * t) + env * 0.3 * sin(2.0 * PI * freq * 0.5 * t)
		var val := int(sample * 32767.0)
		val = mini(maxi(val, -32768), 32767)
		data.append(val & 0xFF)
		data.append((val >> 8) & 0xFF)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

func _unhandled_input(event: InputEvent) -> void:
	if not _is_alive:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_assign_touch(event.index, event.position)
			_resolve_touch_for(event.index)
		else:
			_release_touch(event.index)
	elif event is InputEventScreenDrag:
		_update_drag(event.index, event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_assign_touch(0, event.position)
				_resolve_touch_for(0)
			else:
				_release_touch(0)
	elif event is InputEventMouseMotion:
		if _right_touch_index == 0:
			_right_touch_pos = event.position
			_update_arm_angle_right()
		elif _left_touch_index == 0:
			_left_touch_pos = event.position
			_update_arm_angle_left()

func _assign_touch(index: int, pos: Vector2) -> void:
	var world_pos := _screen_to_world(pos)
	var is_left := world_pos.x < global_position.x
	if is_left:
		if _left_touch_index == -1:
			_left_touch_index = index
			_left_touch_pos = pos
			_update_arm_angle_left()
		else:
			_right_touch_index = index
			_right_touch_pos = pos
			_update_arm_angle_right()
	else:
		if _right_touch_index == -1:
			_right_touch_index = index
			_right_touch_pos = pos
			_update_arm_angle_right()
		else:
			_left_touch_index = index
			_left_touch_pos = pos
			_update_arm_angle_left()

func _release_touch(index: int) -> void:
	if _left_touch_index == index:
		_left_touch_index = -1
	if _right_touch_index == index:
		_right_touch_index = -1

func _update_drag(index: int, pos: Vector2) -> void:
	if _left_touch_index == index:
		_left_touch_pos = pos
		_update_arm_angle_left()
	elif _right_touch_index == index:
		_right_touch_pos = pos
		_update_arm_angle_right()

func _update_arm_angle_left() -> void:
	var world_pos := _screen_to_world(_left_touch_pos)
	_left_arm_angle = (world_pos - (global_position + _left_shoulder)).angle()

func _update_arm_angle_right() -> void:
	var world_pos := _screen_to_world(_right_touch_pos)
	_right_arm_angle = (world_pos - (global_position + _right_shoulder)).angle()

func _resolve_touch_for(index: int) -> void:
	var is_left := _left_touch_index == index
	var world_pos: Vector2
	if is_left:
		world_pos = _screen_to_world(_left_touch_pos)
	else:
		world_pos = _screen_to_world(_right_touch_pos)
	var hit_enemy := _try_hit(world_pos)
	if hit_enemy:
		_hit_player.play()
		if is_left:
			_left_flash_timer = FLASH_DURATION
			_left_flash_color = Color.YELLOW
		else:
			_right_flash_timer = FLASH_DURATION
			_right_flash_color = Color.YELLOW
	else:
		_miss_player.play()
		if is_left:
			_left_flash_timer = FLASH_DURATION
			_left_flash_color = Color(1, 0.3, 0.3)
		else:
			_right_flash_timer = FLASH_DURATION
			_right_flash_color = Color(1, 0.3, 0.3)
		lives -= 1
		lives_changed.emit(lives)
		if lives <= 0:
			_is_alive = false
			lives_depleted.emit()

func _process(delta: float) -> void:
	_left_flash_timer = maxf(0.0, _left_flash_timer - delta)
	_right_flash_timer = maxf(0.0, _right_flash_timer - delta)
	queue_redraw()

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().canvas_transform.affine_inverse() * screen_pos

func _try_hit(world_pos: Vector2) -> bool:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var closest_enemy: Area2D = null
	var closest_dist: float = DIRECT_HIT_RADIUS
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy._is_dead:
			continue
		var dist := world_pos.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_enemy = enemy
	if closest_enemy != null:
		closest_enemy.die()
		return true
	return false

func _draw() -> void:
	var body_color := Color.WHITE
	draw_circle(Vector2(0, -30), 13, body_color)
	draw_line(Vector2(0, -17), Vector2(0, -14), body_color, 3)
	draw_line(Vector2(-12, -14), Vector2(12, -14), body_color, 3)
	draw_line(Vector2(0, -14), Vector2(0, 16), body_color, 4)
	draw_line(Vector2(0, 16), Vector2(16, 44), body_color, 3)
	draw_line(Vector2(0, 16), Vector2(-16, 44), body_color, 3)
	_draw_arm(_left_shoulder, _left_arm_angle, _left_flash_timer, _left_flash_color)
	_draw_arm(_right_shoulder, _right_arm_angle, _right_flash_timer, _right_flash_color)

func _draw_arm(shoulder: Vector2, angle: float, flash_timer: float, flash_color: Color) -> void:
	var is_flashing := flash_timer > 0.0
	var progress := flash_timer / FLASH_DURATION if is_flashing else 0.0
	var recoil_offset := Vector2(progress * RECOIL_DISTANCE * -1.0, 0).rotated(angle) if is_flashing else Vector2.ZERO
	var origin := shoulder + recoil_offset
	var arm_end := origin + Vector2(ARM_LENGTH, 0).rotated(angle)
	var arm_color := Color.WHITE if not is_flashing else flash_color
	draw_line(origin, arm_end, arm_color, 3)
	var tex := _gun_texture
	var tex_size := tex.get_size() * GUN_SCALE
	var offset := Vector2(-tex_size.x * 0.3, -tex_size.y * 0.5)
	var draw_pos := arm_end + offset.rotated(angle)
	draw_set_transform(draw_pos, angle, Vector2(GUN_SCALE, GUN_SCALE))
	draw_texture(tex, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if is_flashing:
		var flash_radius := lerpf(16.0, 4.0, 1.0 - progress)
		var flash_alpha := progress
		var muzzle_pos := arm_end + Vector2(18.0, 0).rotated(angle)
		draw_circle(muzzle_pos, flash_radius, Color(1, 1, 0.5, flash_alpha * 0.4))
		draw_circle(muzzle_pos, flash_radius * 0.5, Color(1, 1, 1, flash_alpha * 0.8))
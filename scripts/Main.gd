extends Node2D

const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")

const INITIAL_SPAWN_INTERVAL := 1.5
const MIN_SPAWN_INTERVAL := 0.25
const DIFFICULTY_RAMP := 0.02
const VIEWPORT_CENTER := Vector2(360, 640)
const EDGE_INSET := 60.0

var player: Area2D
var enemies_container: Node2D
var spawn_timer: Timer
var score_label: Label
var lives_label: Label
var game_over_label: Label
var score: int = 0
var elapsed: float = 0.0
var game_active: bool = false

func _ready() -> void:
	_setup_game()

func _setup_game() -> void:
	enemies_container = Node2D.new()
	enemies_container.name = "Enemies"
	add_child(enemies_container)

	player = PlayerScene.instantiate()
	player.position = VIEWPORT_CENTER
	add_child(player)

	player.lives_depleted.connect(_on_lives_depleted)
	player.lives_changed.connect(_on_lives_changed)

	spawn_timer = Timer.new()
	spawn_timer.wait_time = INITIAL_SPAWN_INTERVAL
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

	_create_hud()
	_start_game()

func _create_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	score_label = Label.new()
	score_label.position = Vector2(0, 30)
	score_label.size = Vector2(720, 50)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	score_label.add_theme_constant_override("shadow_offset_x", 2)
	score_label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(score_label)

	lives_label = Label.new()
	lives_label.position = Vector2(0, 80)
	lives_label.size = Vector2(720, 40)
	lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lives_label.add_theme_font_size_override("font_size", 28)
	lives_label.add_theme_color_override("font_color", Color.RED)
	lives_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	lives_label.add_theme_constant_override("shadow_offset_x", 2)
	lives_label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(lives_label)

	game_over_label = Label.new()
	game_over_label.position = Vector2(0, 480)
	game_over_label.size = Vector2(720, 300)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 42)
	game_over_label.add_theme_color_override("font_color", Color.RED)
	game_over_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	game_over_label.add_theme_constant_override("shadow_offset_x", 3)
	game_over_label.add_theme_constant_override("shadow_offset_y", 3)
	game_over_label.visible = false
	canvas.add_child(game_over_label)

func _start_game() -> void:
	game_active = true
	score = 0
	elapsed = 0.0
	_update_score()
	_update_lives(player.lives)
	spawn_timer.start()

func _game_over() -> void:
	if not game_active:
		return
	game_active = false
	spawn_timer.stop()
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	for enemy in enemies_container.get_children():
		enemy.set_process(false)
		if enemy.has_node("Timer"):
			enemy.get_node("Timer").stop()
	game_over_label.text = "GAME OVER\nScore: %d\nTap to restart" % score
	game_over_label.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not game_active:
		if (event is InputEventScreenTouch and event.pressed) or \
		   (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
			get_tree().reload_current_scene()

func _process(delta: float) -> void:
	if not game_active:
		return
	elapsed += delta
	var new_interval := maxf(MIN_SPAWN_INTERVAL, INITIAL_SPAWN_INTERVAL - elapsed * DIFFICULTY_RAMP)
	spawn_timer.wait_time = new_interval

func _on_spawn_timer_timeout() -> void:
	_spawn_enemy()

func _spawn_enemy() -> void:
	var enemy := EnemyScene.instantiate()
	enemies_container.add_child(enemy)
	enemy.global_position = _random_spawn_position()
	enemy.died.connect(_on_enemy_died)
	enemy.shot_fired.connect(_on_enemy_shot_fired)

func _random_spawn_position() -> Vector2:
	var vp_size := get_viewport().get_visible_rect().size
	var side := randi() % 6
	var pos := Vector2.ZERO
	match side:
		0:
			pos = Vector2(vp_size.x * 0.25, EDGE_INSET)
		1:
			pos = Vector2(vp_size.x * 0.75, EDGE_INSET)
		2:
			pos = Vector2(EDGE_INSET, vp_size.y * 0.5)
		3:
			pos = Vector2(vp_size.x - EDGE_INSET, vp_size.y * 0.5)
		4:
			pos = Vector2(vp_size.x * 0.25, vp_size.y - EDGE_INSET)
		5:
			pos = Vector2(vp_size.x * 0.75, vp_size.y - EDGE_INSET)
	return pos

func _on_lives_changed(new_lives: int) -> void:
	_update_lives(new_lives)

func _on_lives_depleted() -> void:
	_game_over()

func _on_enemy_shot_fired() -> void:
	_game_over()

func _on_enemy_died() -> void:
	score += 1
	_update_score()

func _update_score() -> void:
	score_label.text = str(score)

func _update_lives(lives_count: int) -> void:
	var hearts := ""
	for i in range(lives_count):
		hearts += "♥ "
	for i in range(3 - lives_count):
		hearts += "♡ "
	lives_label.text = hearts.strip_edges()
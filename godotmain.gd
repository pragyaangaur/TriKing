extends Node2D

const COLS = 8
const ROWS = 18
const CELL_SIZE = 40
const BOARD_OFFSET = Vector2(140, 40) 

const SHAPES = [
	[Vector2(0, -1), Vector2(0, 0), Vector2(0, 1)],    # I-King
	[Vector2(0, -1), Vector2(0, 0), Vector2(1, 0)],    # L-King
	[Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],   # D-King
	[Vector2(-1, -1), Vector2(0, 0), Vector2(1, -1)],  # V-King
	[Vector2(0, -1), Vector2(0, 0), Vector2(-1, 1)],   # J-Hook
	[Vector2(0, -1), Vector2(0, 0), Vector2(1, 1)]     # L-Hook
]

const COLORS = [
	Color("#00FFFF"), Color("#FFA500"), Color("#FF00FF"), 
	Color("#00FF00"), Color("#0000FF"), Color("#FF0000")
]

var board = []
var active_piece = []
var piece_color: Color
var piece_pos = Vector2(COLS / 2, 1)

# Game State & Scoring
var game_state = "MENU" # MENU, PLAYING, GAMEOVER, or PAUSED
var next_queue = []
var bag = []
var score = 0
var lines_cleared = 0
var level = 1
var combo = -1
var last_action = ""

var score_label: Label
var level_label: Label
var lines_label: Label
var combo_label: Label
var shake_strength = 0.0

@onready var game_over_ui = $GameOverUI
@onready var camera = $Camera2D

var start_ui_layer: CanvasLayer
var pause_ui_layer: CanvasLayer # NEW

var touch_start_pos = Vector2()
const SWIPE_THRESHOLD = 30
var drag_accum_x = 0.0 
const DRAG_SENSITIVITY = 35 # Adjust this: Lower = more sensitive sliding

func _ready():
	setup_ui()
	build_start_screen() 
	build_pause_screen() # NEW
	
	if game_over_ui:
		game_over_ui.hide()
		if game_over_ui.has_node("ColorRect"):
			game_over_ui.get_node("ColorRect").size = Vector2(600, 800)
			game_over_ui.get_node("ColorRect").position = Vector2.ZERO
	
	$FallTimer.stop() 
			
	randomize()
	for y in range(ROWS):
		var row = []
		for x in range(COLS): row.append(null)
		board.append(row)
		
	for i in range(3):
		next_queue.append(get_next_from_bag())
		
	spawn_piece()

func _process(delta):
	queue_redraw()
	
	if shake_strength > 0:
		camera.offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		shake_strength = lerp(shake_strength, 0.0, 10 * delta)
	else:
		camera.offset = Vector2.ZERO

# --- UI BUILDERS ---
func build_start_screen():
	start_ui_layer = CanvasLayer.new()
	add_child(start_ui_layer)
	
	var bg = ColorRect.new()
	bg.size = Vector2(600, 800)
	bg.color = Color(0, 0, 0, 0.85)
	start_ui_layer.add_child(bg)
	
	var title = Label.new()
	title.text = "TRIKING"
	title.size = Vector2(600, 100)
	title.position = Vector2(0, 200)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls = LabelSettings.new()
	ls.font_size = 56
	ls.font_color = Color.WHITE
	title.label_settings = ls
	start_ui_layer.add_child(title)
	
	var btn = Button.new()
	btn.text = "START GAME"
	btn.size = Vector2(240, 60)
	btn.position = Vector2(180, 400)
	btn.pressed.connect(_on_start_button_pressed)
	start_ui_layer.add_child(btn)

func build_pause_screen():
	pause_ui_layer = CanvasLayer.new()
	add_child(pause_ui_layer)
	
	var bg = ColorRect.new()
	bg.size = Vector2(600, 800)
	bg.color = Color(0, 0, 0, 0.7)
	pause_ui_layer.add_child(bg)
	
	var title = Label.new()
	title.text = "PAUSED"
	title.size = Vector2(600, 100)
	title.position = Vector2(0, 300)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls = LabelSettings.new()
	ls.font_size = 48
	ls.font_color = Color.WHITE
	title.label_settings = ls
	pause_ui_layer.add_child(title)
	
	var btn = Button.new()
	btn.text = "RESUME"
	btn.size = Vector2(200, 60)
	btn.position = Vector2(200, 420)
	btn.pressed.connect(toggle_pause)
	pause_ui_layer.add_child(btn)
	
	pause_ui_layer.hide()

# --- MENU BUTTON LOGIC ---
func _on_start_button_pressed():
	if start_ui_layer: start_ui_layer.hide()
	game_state = "PLAYING"
	$FallTimer.wait_time = 1.0 
	$FallTimer.start()

func toggle_pause():
	if game_state == "PLAYING":
		game_state = "PAUSED"
		$FallTimer.stop()
		pause_ui_layer.show()
	elif game_state == "PAUSED":
		game_state = "PLAYING"
		$FallTimer.start()
		pause_ui_layer.hide()

func _on_button_pressed():
	if game_over_ui: game_over_ui.hide()
	
	game_state = "PLAYING"
	score = 0
	lines_cleared = 0
	level = 1
	combo = -1
	update_ui()
	
	for y in range(ROWS):
		for x in range(COLS): board[y][x] = null
			
	bag.clear()
	next_queue.clear()
	for i in range(3): next_queue.append(get_next_from_bag())
		
	$FallTimer.wait_time = 1.0
	spawn_piece()
	$FallTimer.start()

# --- CORE GAME LOGIC ---
func get_next_from_bag() -> int:
	if bag.is_empty():
		bag = [0, 0, 1, 1, 2, 3, 4, 5]
		bag.shuffle()
	return bag.pop_back()

func spawn_piece():
	var shape_idx = next_queue.pop_front()
	next_queue.append(get_next_from_bag())
	
	active_piece = SHAPES[shape_idx].duplicate(true)
	piece_color = COLORS[shape_idx]
	piece_pos = Vector2(COLS / 2, 1)
	last_action = "spawn"

func valid_move(dx: int, dy: int) -> bool:
	for block in active_piece:
		var px = int(piece_pos.x + block.x + dx)
		var py = int(piece_pos.y + block.y + dy)
		if px < 0 or px >= COLS or py >= ROWS or (py >= 0 and board[py][px] != null):
			return false
	return true

func lock_piece():
	var is_spin = false
	if last_action == "rotate":
		if not valid_move(0, -1) and not valid_move(-1, 0) and not valid_move(1, 0):
			is_spin = true

	for block in active_piece:
		var px = int(piece_pos.x + block.x)
		var py = int(piece_pos.y + block.y)
		if py < 0:
			trigger_game_over()
			return
		else:
			board[py][px] = piece_color
			
	check_lines(is_spin)
	
	if game_state == "PLAYING":
		spawn_piece()
		if not valid_move(0, 0): trigger_game_over()

func trigger_game_over():
	if game_state == "GAMEOVER": return 
	
	game_state = "GAMEOVER"
	if game_over_ui: game_over_ui.show()
	$FallTimer.stop()
	
	if has_node("SfxGameOver"): $SfxGameOver.play()

func trigger_explosion(y_pos, color):
	if has_node("Explosion"):
		var p = $Explosion.duplicate()
		add_child(p)
		p.position = Vector2(BOARD_OFFSET.x + ((COLS * CELL_SIZE) / 2.0), BOARD_OFFSET.y + (y_pos * CELL_SIZE))
		p.color = color
		p.emitting = true
		get_tree().create_timer(1.0).timeout.connect(p.queue_free)

func check_lines(is_spin: bool):
	var lines_to_clear = []
	for y in range(ROWS):
		var is_full = true
		for x in range(COLS):
			if board[y][x] == null:
				is_full = false; break
		if is_full: lines_to_clear.append(y)
			
	var cleared = lines_to_clear.size()
	if cleared > 0:
		shake_strength = 15.0 
		if has_node("SfxClear"): $SfxClear.play()
		combo += 1
		
		for clear_y in lines_to_clear:
			var row_color = board[clear_y][0] if board[clear_y][0] != null else Color.WHITE
			trigger_explosion(clear_y, row_color)
			
			for y in range(clear_y, 0, -1):
				board[y] = board[y-1].duplicate()
			var new_top = []
			for x in range(COLS): new_top.append(null)
			board[0] = new_top
			
		var base_points = {1: 100, 2: 300, 3: 500}
		var points_earned = base_points.get(cleared, 0) * level
		if is_spin: 
			points_earned *= 4
			combo_label.text = "TRI-SPIN!\n" + str(cleared) + " LINES!"
			combo_label.modulate = Color.YELLOW
		elif combo > 0:
			combo_label.text = str(combo) + " COMBO!"
			combo_label.modulate = Color.AQUA
		else:
			combo_label.text = ""
			
		score += points_earned + (50 * combo * level)
		lines_cleared += cleared
		level = (lines_cleared / 10) + 1
		
		$FallTimer.wait_time = max(0.1, 1.0 - ((level - 1) * 0.1))
		
		update_ui()
	else:
		combo = -1
		combo_label.text = ""

func hard_drop():
	if game_state != "PLAYING": return
	shake_strength = 8.0 
	if has_node("SfxDrop"): $SfxDrop.play()
	var drop_dist = 0
	while valid_move(0, 1):
		piece_pos.y += 1
		drop_dist += 2
	score += drop_dist
	update_ui()
	lock_piece()
	
	if game_state == "PLAYING":
		$FallTimer.start() 

func _on_fall_timer_timeout():
	if game_state != "PLAYING": return
	if valid_move(0, 1):
		piece_pos.y += 1
	else:
		lock_piece()

func _input(event):
	if game_state != "PLAYING": return
	
	# --- UPGRADED MOBILE DRAG CONTROLS ---
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start_pos = event.position
			drag_accum_x = 0.0 # Reset sliding accumulator
		else:
			var swipe_vector = event.position - touch_start_pos
			# If they barely moved their finger, it's a Tap (Rotate)
			if swipe_vector.length() < 15:
				var old_shape = active_piece.duplicate(true)
				var new_shape = []
				for block in active_piece: new_shape.append(Vector2(-block.y, block.x))
				active_piece = new_shape
				if not valid_move(0, 0):
					if valid_move(1, 0): piece_pos.x += 1
					elif valid_move(-1, 0): piece_pos.x -= 1
					else: 
						active_piece = old_shape
						return
				last_action = "rotate"
				if has_node("SfxMove"): $SfxMove.play()
			
			# If they swiped DOWN fast/far, Hard Drop
			elif swipe_vector.y > 50 and abs(swipe_vector.y) > abs(swipe_vector.x):
				hard_drop()

	elif event is InputEventScreenDrag:
		# Buttery smooth left/right dragging!
		drag_accum_x += event.relative.x
		if drag_accum_x > DRAG_SENSITIVITY and valid_move(1, 0):
			piece_pos.x += 1
			drag_accum_x -= DRAG_SENSITIVITY
			last_action = "move"
			if has_node("SfxMove"): $SfxMove.play()
		elif drag_accum_x < -DRAG_SENSITIVITY and valid_move(-1, 0):
			piece_pos.x -= 1
			drag_accum_x += DRAG_SENSITIVITY
			last_action = "move"
			if has_node("SfxMove"): $SfxMove.play()
			
	# --- DESKTOP CONTROLS ---
	elif event.is_action_pressed("ui_left", true) and valid_move(-1, 0):
		piece_pos.x -= 1
		last_action = "move"
		if has_node("SfxMove"): $SfxMove.play()
	elif event.is_action_pressed("ui_right", true) and valid_move(1, 0):
		piece_pos.x += 1
		last_action = "move"
		if has_node("SfxMove"): $SfxMove.play()
	elif event.is_action_pressed("ui_down", true) and valid_move(0, 1):
		piece_pos.y += 1
		score += 1 
		update_ui()
		$FallTimer.start()
		last_action = "move"
		if has_node("SfxMove"): $SfxMove.play()
	elif event.is_action_pressed("ui_accept"): 
		hard_drop()
		last_action = "drop"
	elif event.is_action_pressed("ui_up"):
		var old_shape = active_piece.duplicate(true)
		var new_shape = []
		for block in active_piece: new_shape.append(Vector2(-block.y, block.x))
		active_piece = new_shape
		if not valid_move(0, 0):
			if valid_move(1, 0): piece_pos.x += 1
			elif valid_move(-1, 0): piece_pos.x -= 1
			else: 
				active_piece = old_shape
				return 
		last_action = "rotate"
		if has_node("SfxMove"): $SfxMove.play()

	elif event.is_action_pressed("ui_left", true) and valid_move(-1, 0):
		piece_pos.x -= 1
		last_action = "move"
		if has_node("SfxMove"): $SfxMove.play()
	elif event.is_action_pressed("ui_right", true) and valid_move(1, 0):
		piece_pos.x += 1
		last_action = "move"
		if has_node("SfxMove"): $SfxMove.play()
	elif event.is_action_pressed("ui_down", true) and valid_move(0, 1):
		piece_pos.y += 1
		score += 1 
		update_ui()
		$FallTimer.start()
		last_action = "move"
		if has_node("SfxMove"): $SfxMove.play()
	elif event.is_action_pressed("ui_accept"): 
		hard_drop()
		last_action = "drop"
	elif event.is_action_pressed("ui_up"):
		var old_shape = active_piece.duplicate(true)
		var new_shape = []
		for block in active_piece: new_shape.append(Vector2(-block.y, block.x))
		active_piece = new_shape
		if not valid_move(0, 0):
			if valid_move(1, 0): piece_pos.x += 1
			elif valid_move(-1, 0): piece_pos.x -= 1
			else: 
				active_piece = old_shape
				return 
		last_action = "rotate"
		if has_node("SfxMove"): $SfxMove.play()

# --- DRAWING & UI ---
func setup_ui():
	var ls_title = LabelSettings.new()
	ls_title.font_size = 20
	ls_title.font_color = Color.DARK_GRAY
	
	var ls_val = LabelSettings.new()
	ls_val.font_size = 28
	ls_val.font_color = Color.WHITE

	score_label = Label.new()
	score_label.position = Vector2(10, 200)
	score_label.label_settings = ls_val
	add_child(score_label)
	
	level_label = Label.new()
	level_label.position = Vector2(10, 350)
	level_label.label_settings = ls_val
	add_child(level_label)

	lines_label = Label.new()
	lines_label.position = Vector2(10, 500)
	lines_label.label_settings = ls_val
	add_child(lines_label)
	
	combo_label = Label.new()
	combo_label.position = Vector2(140, 10)
	combo_label.label_settings = ls_val
	add_child(combo_label)

	var next_title = Label.new()
	next_title.text = "NEXT"
	next_title.position = Vector2(490, 160)
	next_title.label_settings = ls_title
	add_child(next_title)
	
	# THE PAUSE BUTTON
	var btn_pause = Button.new()
	btn_pause.text = "PAUSE"
	btn_pause.position = Vector2(490, 30)
	btn_pause.size = Vector2(80, 40)
	btn_pause.pressed.connect(toggle_pause)
	add_child(btn_pause)
	
	update_ui()

func update_ui():
	score_label.text = "SCORE\n" + str(score)
	level_label.text = "LEVEL\n" + str(level)
	lines_label.text = "LINES\n" + str(lines_cleared)

func get_ghost_y() -> int:
	var ghost_y = int(piece_pos.y)
	while true:
		var valid = true
		for block in active_piece:
			var px = int(piece_pos.x + block.x)
			var py = int(ghost_y + block.y + 1)
			if py >= ROWS or (py >= 0 and board[py][px] != null):
				valid = false; break
		if valid: ghost_y += 1
		else: break
	return ghost_y

func _draw():
	var grid_color = Color("#202020")
	var board_bg = Color("#0a0a0a")
	
	draw_rect(Rect2(BOARD_OFFSET.x, BOARD_OFFSET.y, COLS * CELL_SIZE, ROWS * CELL_SIZE), board_bg, true)
	
	for y in range(ROWS):
		for x in range(COLS):
			var rect = Rect2(BOARD_OFFSET.x + (x * CELL_SIZE), BOARD_OFFSET.y + (y * CELL_SIZE), CELL_SIZE, CELL_SIZE)
			draw_rect(rect, grid_color, false, 1.0)
			if board[y][x] != null:
				draw_glossy_block(rect, board[y][x])

	var ghost_y = get_ghost_y()
	for block in active_piece:
		var px = piece_pos.x + block.x
		var py = ghost_y + block.y
		if py >= 0:
			var rect = Rect2(BOARD_OFFSET.x + (px * CELL_SIZE), BOARD_OFFSET.y + (py * CELL_SIZE), CELL_SIZE, CELL_SIZE)
			draw_rect(rect, piece_color, false, 2.0)

	for block in active_piece:
		var px = piece_pos.x + block.x
		var py = piece_pos.y + block.y
		if py >= 0:
			var rect = Rect2(BOARD_OFFSET.x + (px * CELL_SIZE), BOARD_OFFSET.y + (py * CELL_SIZE), CELL_SIZE, CELL_SIZE)
			draw_glossy_block(rect, piece_color)

	var next_start = Vector2(490, 240)
	var mini_size = 20
	for i in range(next_queue.size()):
		var shape_idx = next_queue[i]
		var shape = SHAPES[shape_idx]
		var c = COLORS[shape_idx]
		for block in shape:
			var px = next_start.x + (block.x * mini_size)
			var py = next_start.y + (i * 90) + (block.y * mini_size)
			var rect = Rect2(px, py, mini_size, mini_size)
			draw_glossy_block(rect, c)

func draw_glossy_block(rect: Rect2, color: Color):
	draw_rect(rect, color, true)
	
	var highlight = Color(1, 1, 1, 0.4)
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), highlight, 4.0)
	draw_line(rect.position, rect.position + Vector2(0, rect.size.y), highlight, 4.0)
	
	var shadow = Color(0, 0, 0, 0.4)
	draw_line(rect.position + Vector2(0, rect.size.y), rect.position + Vector2(rect.size.x, rect.size.y), shadow, 4.0)
	draw_line(rect.position + Vector2(rect.size.x, 0), rect.position + Vector2(rect.size.x, rect.size.y), shadow, 4.0)
	
	draw_rect(rect, Color.BLACK, false, 1.0)

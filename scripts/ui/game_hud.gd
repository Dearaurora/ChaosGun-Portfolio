extends CanvasLayer
const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")
## NEON KINETIC 风格游戏 HUD —— 复刻 Stitch 设计稿
## 配色：深紫黑底 #0c0c1f / 霓虹绿 #cafd00 / 橙 #ff7441 / 粉红 #ff6e81

# ============================================================
#  颜色常量 —— 从 Stitch 设计稿提取
# ============================================================
const COL_SURFACE := Color("#0c0c1f")             # 深色背景
const COL_PANEL := Color("#1d1d37")                # 面板底色
const COL_PANEL_DARK := Color("#000000")           # 深色子面板
const COL_PRIMARY := Color("#cafd00")              # 霓虹绿（玩家主色）
const COL_SECONDARY := Color("#ff7441")            # 橙色（AI 主色）
const COL_HEART := Color("#ff6e81")                # 粉红（生命心）
const COL_HEART_DIM := Color(1.0, 0.431, 0.506, 0.25)  # 心形暗淡（已损失生命）
const COL_TEXT := Color("#e5e3ff")                  # 标准文字
const COL_WHITE := Color.WHITE
const CAMERA_OCCLUDER_GROUP := &"party_shooter_camera_occluder"
const COL_GLOW_GREEN := Color(0.792, 0.992, 0.0, 0.15)   # 绿色辉光
const COL_GLOW_ORANGE := Color(1.0, 0.455, 0.255, 0.15)   # 橙色辉光

# ============================================================
#  引用
# ============================================================
var _player: BaseCharacter = null
var _ai: BaseCharacter = null

# UI 节点 —— 玩家
var _p_name_label: Label
var _p_weapon_label: Label
var _p_ammo_label: Label
var _p_hearts: Array[ColorRect] = []

# UI 节点 —— AI
var _a_name_label: Label
var _a_weapon_label: Label
var _a_ammo_label: Label
var _a_hearts: Array[ColorRect] = []

# UI 节点 —— 中央计分板
var _score_label: Label
var _p_kill_label: Label
var _a_kill_label: Label
var _profile_badge_label: Label
var _player_panel: Control = null
var _ai_panel: Control = null
var _scoreboard_panel: Control = null
var _profile_badge_panel: Control = null

# Game Over
var _game_over_container: PanelContainer
var _game_over_label: Label
var _restart_label: Label

var _p_kills: int = 0
var _a_kills: int = 0
var _p_last_lives: int = -1
var _a_last_lives: int = -1

# ============================================================
#  初始化
# ============================================================
func _ready() -> void:
	# _ready intentionally waits one frame to discover opponents. Keep per-frame
	# updates disabled until every label exists so rendered benchmark launches do
	# not race _process against the asynchronous UI build.
	set_process(false)
	if not get_viewport().size_changed.is_connected(_layout_viewport_ui):
		get_viewport().size_changed.connect(_layout_viewport_ui)
	_player = get_parent() as BaseCharacter
	# 延迟一帧查找 AI
	await get_tree().process_frame
	var scene = get_tree().current_scene
	if scene == null:
		_build_ui()
		set_process(true)
		return
	for n in scene.get_children():
		if n is BaseCharacter and n != _player:
			_ai = n
			break
	_build_ui()
	set_process(true)

func _build_ui() -> void:
	# --- 玩家面板（左上） ---
	_player_panel = _create_player_panel("PLAYER", COL_PRIMARY, COL_GLOW_GREEN, false)
	_player_panel.name = "PlayerStatusPanel"
	add_child(_player_panel)
	_player_panel.add_to_group(CAMERA_OCCLUDER_GROUP)

	# --- AI 面板（右上） ---
	_ai_panel = _create_player_panel("AI BOT", COL_SECONDARY, COL_GLOW_ORANGE, true)
	_ai_panel.name = "AIStatusPanel"
	# 右对齐：视口宽度 - 面板宽度 - 边距
	add_child(_ai_panel)
	_ai_panel.add_to_group(CAMERA_OCCLUDER_GROUP)

	# --- 中央计分板 ---
	_build_scoreboard()
	_build_profile_badge()
	_layout_viewport_ui()

	# --- Game Over ---
	_build_game_over()

	# 初始化生命追踪
	if _player:
		_p_last_lives = _player.lives
	if _ai:
		_a_last_lives = _ai.lives

# ============================================================
#  玩家面板构建
# ============================================================
func _create_player_panel(title: String, accent: Color, glow: Color, is_right: bool) -> Control:
	var root = Control.new()
	root.custom_minimum_size = Vector2(280, 130)
	root.size = Vector2(280, 130)

	# 背景面板
	var bg = Panel.new()
	bg.size = Vector2(280, 130)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(COL_PANEL.r, COL_PANEL.g, COL_PANEL.b, 0.75)
	bg_style.corner_radius_top_left = 16
	bg_style.corner_radius_top_right = 16
	bg_style.corner_radius_bottom_left = 16
	bg_style.corner_radius_bottom_right = 16
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(accent.r, accent.g, accent.b, 0.3)
	bg_style.shadow_color = glow
	bg_style.shadow_size = 12
	bg.add_theme_stylebox_override("panel", bg_style)
	root.add_child(bg)

	# 头像圆圈
	var avatar_size := 48.0
	var avatar_x := 20.0 if not is_right else 280.0 - 20.0 - avatar_size
	var avatar = Panel.new()
	avatar.position = Vector2(avatar_x, 16)
	avatar.size = Vector2(avatar_size, avatar_size)
	var avatar_style = StyleBoxFlat.new()
	avatar_style.bg_color = accent
	avatar_style.corner_radius_top_left = 24
	avatar_style.corner_radius_top_right = 24
	avatar_style.corner_radius_bottom_left = 24
	avatar_style.corner_radius_bottom_right = 24
	avatar.add_theme_stylebox_override("panel", avatar_style)
	root.add_child(avatar)

	# 头像图标文字
	var icon_label = Label.new()
	icon_label.text = "P1" if not is_right else "AI"
	icon_label.position = Vector2(avatar_x, 16)
	icon_label.size = Vector2(avatar_size, avatar_size)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 16)
	icon_label.add_theme_color_override("font_color", COL_SURFACE)
	root.add_child(icon_label)

	# 名字
	var name_label = Label.new()
	name_label.text = title
	var name_x := avatar_x + avatar_size + 12.0 if not is_right else 16.0
	var name_w := 280.0 - name_x - 16.0 if not is_right else avatar_x - 16.0
	name_label.position = Vector2(name_x, 14)
	name_label.size = Vector2(name_w, 28)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", accent)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if not is_right else HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(name_label)
	if is_right:
		_a_name_label = name_label
	else:
		_p_name_label = name_label

	# 心形生命条
	var hearts_y := 44.0
	var heart_size := 16.0
	var heart_gap := 2.0
	var game_config = RuntimeGlobals.game_config()
	var max_lives = game_config.get("default_lives") if game_config and game_config.get("default_lives") is int else 10
	var hearts_total_w = max_lives * (heart_size + heart_gap) - heart_gap
	var hearts_x: float
	if not is_right:
		hearts_x = name_x
	else:
		hearts_x = name_x  # 镜像左侧，心形从名字下方左端开始

	var hearts_arr: Array[ColorRect] = []
	for i in range(max_lives):
		var heart = ColorRect.new()
		var hx = hearts_x + i * (heart_size + heart_gap)
		heart.position = Vector2(hx, hearts_y)
		heart.size = Vector2(heart_size, heart_size)
		heart.color = COL_HEART
		root.add_child(heart)
		hearts_arr.append(heart)

	if is_right:
		_a_hearts = hearts_arr
	else:
		_p_hearts = hearts_arr

	# 武器信息条（底部深色条）
	var weapon_bar = Panel.new()
	weapon_bar.position = Vector2(12, 80)
	weapon_bar.size = Vector2(256, 38)
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0, 0, 0, 0.5)
	bar_style.corner_radius_top_left = 8
	bar_style.corner_radius_top_right = 8
	bar_style.corner_radius_bottom_left = 8
	bar_style.corner_radius_bottom_right = 8
	weapon_bar.add_theme_stylebox_override("panel", bar_style)
	root.add_child(weapon_bar)

	# 武器名
	var w_label = Label.new()
	w_label.text = "PISTOL"
	w_label.add_theme_font_size_override("font_size", 14)
	w_label.add_theme_color_override("font_color", COL_TEXT)
	if not is_right:
		w_label.position = Vector2(22, 87)
		w_label.size = Vector2(160, 24)
		w_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		w_label.position = Vector2(100, 87)
		w_label.size = Vector2(160, 24)
		w_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(w_label)

	# 弹药数
	var ammo_lbl = Label.new()
	ammo_lbl.text = "∞"
	ammo_lbl.add_theme_font_size_override("font_size", 16)
	ammo_lbl.add_theme_color_override("font_color", COL_WHITE)
	if not is_right:
		ammo_lbl.position = Vector2(200, 85)
		ammo_lbl.size = Vector2(60, 28)
		ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		ammo_lbl.position = Vector2(22, 85)
		ammo_lbl.size = Vector2(60, 28)
		ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(ammo_lbl)

	if is_right:
		_a_weapon_label = w_label
		_a_ammo_label = ammo_lbl
	else:
		_p_weapon_label = w_label
		_p_ammo_label = ammo_lbl

	return root

# ============================================================
#  中央计分板
# ============================================================
func _build_scoreboard() -> void:
	var board_w := 240.0
	var board_h := 56.0

	var board = Panel.new()
	board.name = "ScoreboardPanel"
	board.size = Vector2(board_w, board_h)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(COL_PANEL.r, COL_PANEL.g, COL_PANEL.b, 0.8)
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(COL_PRIMARY.r, COL_PRIMARY.g, COL_PRIMARY.b, 0.3)
	style.shadow_color = COL_GLOW_GREEN
	style.shadow_size = 16
	board.add_theme_stylebox_override("panel", style)
	add_child(board)
	board.add_to_group(CAMERA_OCCLUDER_GROUP)
	_scoreboard_panel = board

	# 玩家击杀数
	_p_kill_label = Label.new()
	_p_kill_label.text = "0"
	_p_kill_label.position = Vector2(30, 6)
	_p_kill_label.size = Vector2(40, 44)
	_p_kill_label.add_theme_font_size_override("font_size", 28)
	_p_kill_label.add_theme_color_override("font_color", COL_PRIMARY)
	_p_kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_p_kill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	board.add_child(_p_kill_label)

	# "SCORE" 标题
	_score_label = Label.new()
	_score_label.text = "SCORE"
	_score_label.position = Vector2(70, 6)
	_score_label.size = Vector2(100, 20)
	_score_label.add_theme_font_size_override("font_size", 10)
	_score_label.add_theme_color_override("font_color", COL_PRIMARY)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(_score_label)

	# 分隔线
	var dash = Label.new()
	dash.text = "—"
	dash.position = Vector2(70, 20)
	dash.size = Vector2(100, 30)
	dash.add_theme_font_size_override("font_size", 24)
	dash.add_theme_color_override("font_color", Color(COL_TEXT.r, COL_TEXT.g, COL_TEXT.b, 0.3))
	dash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	board.add_child(dash)

	# AI 击杀数
	_a_kill_label = Label.new()
	_a_kill_label.text = "0"
	_a_kill_label.position = Vector2(170, 6)
	_a_kill_label.size = Vector2(40, 44)
	_a_kill_label.add_theme_font_size_override("font_size", 28)
	_a_kill_label.add_theme_color_override("font_color", COL_SECONDARY)
	_a_kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_a_kill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	board.add_child(_a_kill_label)

func _build_profile_badge() -> void:
	var profile_id = _get_active_profile_id()
	if profile_id.is_empty():
		return
	var badge = Panel.new()
	badge.name = "ProfileBadgePanel"
	badge.size = Vector2(260, 28)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.45)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(COL_PRIMARY.r, COL_PRIMARY.g, COL_PRIMARY.b, 0.35)
	badge.add_theme_stylebox_override("panel", style)
	add_child(badge)
	badge.add_to_group(CAMERA_OCCLUDER_GROUP)
	_profile_badge_panel = badge

	_profile_badge_label = Label.new()
	_profile_badge_label.text = "FEEL: %s" % profile_id.to_upper()
	_profile_badge_label.position = Vector2(10, 3)
	_profile_badge_label.size = Vector2(240, 22)
	_profile_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_profile_badge_label.add_theme_font_size_override("font_size", 12)
	_profile_badge_label.add_theme_color_override("font_color", COL_TEXT)
	badge.add_child(_profile_badge_label)


func _layout_viewport_ui() -> void:
	var viewport_width := get_viewport().get_visible_rect().size.x
	if _player_panel and is_instance_valid(_player_panel):
		_player_panel.position = Vector2(24.0, 24.0)
	if _ai_panel and is_instance_valid(_ai_panel):
		_ai_panel.position = Vector2(viewport_width - 304.0, 24.0)
	if _scoreboard_panel and is_instance_valid(_scoreboard_panel):
		_scoreboard_panel.position = Vector2((viewport_width - 240.0) * 0.5, 24.0)
	if _profile_badge_panel and is_instance_valid(_profile_badge_panel):
		_profile_badge_panel.position = Vector2((viewport_width - 260.0) * 0.5, 86.0)

func _get_active_profile_id() -> String:
	var game_config = RuntimeGlobals.game_config()
	if game_config == null:
		return ""
	return String(game_config.get_meta("feel_profile_id", ""))

# ============================================================
#  Game Over 屏幕
# ============================================================
func _build_game_over() -> void:
	_game_over_container = PanelContainer.new()
	_game_over_container.anchors_preset = Control.PRESET_FULL_RECT
	_game_over_container.visible = false
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	_game_over_container.add_theme_stylebox_override("panel", style)
	add_child(_game_over_container)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.anchors_preset = Control.PRESET_CENTER
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	_game_over_container.add_child(vbox)

	_game_over_label = Label.new()
	_game_over_label.text = "GAME OVER"
	_game_over_label.add_theme_font_size_override("font_size", 64)
	_game_over_label.add_theme_color_override("font_color", COL_PRIMARY)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_game_over_label)

	# 间距
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	# Restart 按钮
	var restart_btn = Button.new()
	restart_btn.text = "↻  RESTART  (R)"
	restart_btn.custom_minimum_size = Vector2(260, 48)
	_style_go_button(restart_btn, COL_PRIMARY)
	restart_btn.pressed.connect(func(): MatchConfig.restart_current_match(get_tree()))
	vbox.add_child(restart_btn)

	# 间距
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer2)

	# Main Menu 按钮
	var menu_btn = Button.new()
	menu_btn.text = "⌂  MAIN MENU"
	menu_btn.custom_minimum_size = Vector2(260, 48)
	_style_go_button(menu_btn, COL_SECONDARY)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	vbox.add_child(menu_btn)

func _style_go_button(btn: Button, color: Color) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.11, 0.22, 0.9)
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(color.r, color.g, color.b, 0.4)
	btn.add_theme_stylebox_override("normal", normal)
	var hover = normal.duplicate()
	hover.bg_color = Color(color.r, color.g, color.b, 0.2)
	hover.border_color = color
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

# ============================================================
#  每帧更新
# ============================================================
func _process(_delta: float) -> void:
	_update_player_panel()
	_update_ai_panel()
	_update_kills()
	_check_game_over()

func _update_player_panel() -> void:
	if not _player:
		return
	if _player.weapon_manager:
		var wm = _player.weapon_manager
		var wname = wm.get_current_weapon_name().to_upper()
		if wname == "":
			wname = "PISTOL"
		_p_weapon_label.text = wname
		var ammo = wm.get_current_ammo()
		_p_ammo_label.text = "∞" if ammo == -1 else str(ammo)
	_update_hearts(_p_hearts, _player.lives)

func _update_ai_panel() -> void:
	if not _ai:
		return
	if _ai.weapon_manager:
		var wm = _ai.weapon_manager
		var wname = wm.get_current_weapon_name().to_upper()
		if wname == "":
			wname = "PISTOL"
		_a_weapon_label.text = wname
		var ammo = wm.get_current_ammo()
		_a_ammo_label.text = "∞" if ammo == -1 else str(ammo)
	_update_hearts(_a_hearts, _ai.lives)

func _update_hearts(hearts: Array[ColorRect], current_lives: int) -> void:
	for i in range(hearts.size()):
		if i < current_lives:
			hearts[i].color = COL_HEART
		else:
			hearts[i].color = COL_HEART_DIM

func _update_kills() -> void:
	if _player and _p_last_lives > 0:
		if _player.lives < _p_last_lives:
			_a_kills += _p_last_lives - _player.lives
			_a_kill_label.text = str(_a_kills)
		_p_last_lives = _player.lives
	if _ai and _a_last_lives > 0:
		if _ai.lives < _a_last_lives:
			_p_kills += _a_last_lives - _ai.lives
			_p_kill_label.text = str(_p_kills)
		_a_last_lives = _ai.lives

func _check_game_over() -> void:
	if not _player:
		return
	var game_over = false
	var winner_text = ""
	if _player.is_game_over:
		game_over = true
		winner_text = "AI WINS!"
	elif _ai and _ai.is_game_over:
		game_over = true
		winner_text = "YOU WIN!"
	if game_over and not _game_over_container.visible:
		_game_over_label.text = winner_text
		_game_over_container.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if _game_over_container and _game_over_container.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			MatchConfig.restart_current_match(get_tree())

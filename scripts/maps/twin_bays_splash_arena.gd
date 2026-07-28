extends "res://scripts/maps/twin_bays_arena_base.gd"

const FOREGROUND_SCENE_PATH := "res://assets/models/generated/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4_foreground.glb"
const ART_PROFILE_PATH := "res://resources/maps/twin_bays_art_v4.json"
const TIDE_PROFILE_PATH := "res://resources/maps/twin_bays_tide_v1.json"
const SplashBackdropScript = preload("res://scripts/maps/twin_bays_splash_backdrop.gd")
const PortalVFXScript = preload("res://scripts/maps/twin_bays_portal_vfx.gd")
const MatchPresentationScript = preload("res://scripts/maps/party_shooter_match_presentation.gd")
const ShallowWaterScript = preload("res://scripts/maps/twin_bays_shallow_water.gd")
const TideControllerScript = preload("res://scripts/maps/twin_bays_tide_controller.gd")

const MATCH_PRESENTATION_PROFILE := {
	"profile_id": "twin_bays_splash_arena",
	"intro_reveal_duration": 1.35,
	"winner_focus_delay": 0.78,
	"winner_camera_duration": 0.72,
	"hud_focus_alpha": 0.22,
	"hud_root_names": ["GameHUD"],
	"ready_color": Color("#FFF4DC"),
	"go_color": Color("#FFD447"),
	"ink_color": Color("#073E57"),
}

var _match_presentation: PartyShooterMatchPresentation = null
var _splash_backdrop: TwinBaysSplashBackdrop = null
var _shallow_water: TwinBaysShallowWater = null
var _tide_controller: TwinBaysTideController = null


func _ready() -> void:
	set_meta("ringout_burst_mode", "water_splash")
	super._ready()
	_setup_tide_system()
	_setup_match_presentation()
	if _match_presentation and not _match_presentation.intro_completed.is_connected(_on_intro_completed):
		_match_presentation.intro_completed.connect(_on_intro_completed)
	call_deferred("_start_match_presentation")


func _setup_tide_system() -> void:
	var profile := _load_tide_profile()
	if profile.is_empty() or _splash_backdrop == null:
		push_error("Twin Bays tide system could not be configured")
		return
	_shallow_water = ShallowWaterScript.new() as TwinBaysShallowWater
	_shallow_water.name = "TwinBaysShallowWater"
	add_child(_shallow_water)
	_shallow_water.configure(self, profile, _characters)
	_tide_controller = TideControllerScript.new() as TwinBaysTideController
	_tide_controller.name = "TwinBaysTideController"
	add_child(_tide_controller)
	_tide_controller.configure(self, get_twin_bays_layout(), profile, _characters, _splash_backdrop, _shallow_water)
	var art_profile := _load_art_profile()
	if not art_profile.is_empty():
		_tide_controller.apply_art_profile(art_profile)


func _load_tide_profile() -> Dictionary:
	if not FileAccess.file_exists(TIDE_PROFILE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TIDE_PROFILE_PATH))
	return parsed as Dictionary if parsed is Dictionary else {}


func _load_art_profile() -> Dictionary:
	if not FileAccess.file_exists(ART_PROFILE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ART_PROFILE_PATH))
	return parsed as Dictionary if parsed is Dictionary else {}


func _on_intro_completed() -> void:
	if _tide_controller:
		_tide_controller.start_cycle()


func get_tide_debug_state() -> Dictionary:
	return _tide_controller.get_debug_state() if _tide_controller else {}


func get_shallow_water_debug() -> Dictionary:
	return _shallow_water.get_debug_state() if _shallow_water else {}


func _setup_match_presentation() -> void:
	if _match_presentation and is_instance_valid(_match_presentation):
		return
	_match_presentation = MatchPresentationScript.new() as PartyShooterMatchPresentation
	_match_presentation.name = "PartyShooterMatchPresentation"
	add_child(_match_presentation)
	_match_presentation.configure(self, _camera_director, _characters, MATCH_PRESENTATION_PROFILE)


func _start_match_presentation() -> void:
	if _match_presentation and is_instance_valid(_match_presentation):
		_match_presentation.configure(self, _camera_director, _characters, MATCH_PRESENTATION_PROFILE)
		_match_presentation.start_intro()


func get_match_presentation_debug() -> Dictionary:
	if _match_presentation and is_instance_valid(_match_presentation):
		return _match_presentation.get_debug_state()
	return {}


func _present_match_result(winner: BaseCharacter, winner_name: String, winner_color: Color) -> void:
	if _tide_controller:
		_tide_controller.stop_cycle()
	if _match_presentation and is_instance_valid(_match_presentation):
		await _match_presentation.present_result(winner, winner_color)
	if not is_inside_tree():
		return
	super._present_match_result(winner, winner_name, winner_color)

func _build_twin_bays_foreground(parent: Node3D) -> void:
	var packed := load(FOREGROUND_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Twin Bays production foreground is missing: %s" % FOREGROUND_SCENE_PATH)
		return
	var foreground := packed.instantiate() as Node3D
	if foreground == null:
		push_error("Twin Bays production foreground could not be instantiated")
		return
	foreground.name = "TwinBaysSplashForeground"
	foreground.set_meta("visual_only", true)
	foreground.set_meta("layout_source", TwinBaysLayoutScript.DEFAULT_PATH)
	parent.add_child(foreground)

func _build_twin_bays_backdrop(parent: Node3D) -> void:
	var backdrop := SplashBackdropScript.new() as TwinBaysSplashBackdrop
	backdrop.name = "SplashBackdropVisuals"
	parent.add_child(backdrop)
	backdrop.rebuild()
	var art_profile := _load_art_profile()
	if not art_profile.is_empty():
		backdrop.apply_art_profile(art_profile)
	_splash_backdrop = backdrop

func _build_twin_bays_portal_visuals(
	portal: TwinBaysPortal,
	portal_data: Dictionary,
	_portal_normal: Vector3,
	_portal_mat: Material,
	_portal_core_mat: Material
) -> void:
	var vfx := PortalVFXScript.new() as TwinBaysPortalVFX
	portal.add_child(vfx)
	vfx.configure(portal, portal_data)
	var art_profile := _load_art_profile()
	if not art_profile.is_empty():
		vfx.apply_art_profile(art_profile)

func _twin_bays_camera_profile() -> Dictionary:
	var look_at := Vector3(0.25, 1.0, 0.0)
	var view_offset := twin_bays_gameplay_view_offset()
	return {
		"position": look_at + view_offset,
		"look_at": look_at,
		# The production water pipes extend beyond the playable platform.  This
		# overview keeps both submerged entries in frame; live combat still zooms
		# toward the party through the shared camera director.
		"size": 98.0,
	}


func _twin_bays_runtime_camera_profile() -> Dictionary:
	var profile := super._twin_bays_runtime_camera_profile()
	profile["reveal_focus"] = Vector3(0.25, 1.0, 0.0)
	profile["reveal_size"] = 98.0
	profile["reveal_duration"] = 1.35
	profile["winner_focus_size"] = 38.5
	profile["winner_focus_duration"] = 0.72
	return profile


func _on_twin_bays_character_teleported(
	character: BaseCharacter,
	from_portal: TwinBaysPortal,
	to_portal: TwinBaysPortal
) -> void:
	# An immediate opening portal use is gameplay-critical. End only the arena
	# reveal camera override so the shared discontinuity guard can frame both
	# ends of the jump; READY/GO remains independent and finishes normally.
	if _camera_director and is_instance_valid(_camera_director):
		var camera_state := _camera_director.call("get_debug_state") as Dictionary
		if String(camera_state.get("presentation_mode", "")) == "reveal":
			_camera_director.call("release_presentation_override")
	super._on_twin_bays_character_teleported(character, from_portal, to_portal)

func _apply_twin_bays_environment_overrides() -> void:
	var lighting := _load_art_profile().get("lighting", {}) as Dictionary
	var key := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if key:
		var key_rotation := lighting.get("key_rotation_degrees", [-52.0, -31.0, 0.0]) as Array
		if key_rotation.size() >= 3:
			key.rotation_degrees = Vector3(
				float(key_rotation[0]),
				float(key_rotation[1]),
				float(key_rotation[2])
			)
		key.light_color = Color(String(lighting.get("key_color", "#FFF0D5")))
		key.light_energy = float(lighting.get("key_energy", 0.74))
		key.shadow_enabled = true
		key.shadow_blur = float(lighting.get("shadow_blur", 2.15))
		key.shadow_opacity = float(lighting.get("shadow_opacity", 0.67))

	_configure_fill_light()
	var fill := get_node_or_null("SplashCoolFill") as OmniLight3D
	if fill:
		fill.light_color = Color(String(lighting.get("fill_color", "#86E8FF")))
		fill.light_energy = float(lighting.get("fill_energy", 0.12))
	var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node == null:
		env_node = WorldEnvironment.new()
		env_node.name = "WorldEnvironment"
		add_child(env_node)

	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(String(lighting.get("sky_top_color", "#68C9F1")))
	sky_material.sky_horizon_color = Color(String(lighting.get("sky_horizon_color", "#BFEFFD")))
	sky_material.ground_bottom_color = Color(String(lighting.get("ground_bottom_color", "#157CA7")))
	sky_material.ground_horizon_color = Color(String(lighting.get("ground_horizon_color", "#69D3E6")))
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.08
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = float(lighting.get("exposure", 0.64))
	environment.adjustment_enabled = true
	environment.adjustment_brightness = float(lighting.get("brightness", 0.98))
	environment.adjustment_contrast = float(lighting.get("contrast", 1.06))
	environment.adjustment_saturation = float(lighting.get("saturation", 1.10))
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(String(lighting.get("ambient_color", "#B5EAF1")))
	environment.ambient_light_energy = float(lighting.get("ambient_energy", 0.24))
	environment.ssao_enabled = true
	environment.ssao_radius = float(lighting.get("ssao_radius", 1.15))
	environment.ssao_intensity = float(lighting.get("ssao_intensity", 0.92))
	environment.ssao_power = float(lighting.get("ssao_power", 1.30))
	environment.glow_enabled = true
	environment.glow_intensity = float(lighting.get("glow_intensity", 0.18))
	environment.glow_strength = float(lighting.get("glow_strength", 0.58))
	environment.glow_bloom = float(lighting.get("glow_bloom", 0.02))
	environment.fog_enabled = false
	env_node.environment = environment

func _configure_fill_light() -> void:
	var fill := get_node_or_null("SplashCoolFill") as OmniLight3D
	if fill == null:
		fill = OmniLight3D.new()
		fill.name = "SplashCoolFill"
		add_child(fill)
	fill.position = Vector3(-18.0, 36.0, 24.0)
	fill.light_color = Color("#86E8FF")
	fill.light_energy = 0.12
	fill.omni_range = 128.0
	fill.shadow_enabled = false

func spawn_water_fall_effect(fall_position: Vector3) -> void:
	var splash := GPUParticles3D.new()
	splash.name = "WaterFallSplash"
	splash.amount = 28
	splash.lifetime = 0.72
	splash.one_shot = true
	splash.explosiveness = 1.0
	splash.randomness = 0.35
	splash.visibility_aabb = AABB(Vector3(-4.0, -2.0, -4.0), Vector3(8.0, 8.0, 8.0))
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3.UP
	process_material.spread = 48.0
	process_material.initial_velocity_min = 2.8
	process_material.initial_velocity_max = 5.2
	process_material.gravity = Vector3(0.0, -14.0, 0.0)
	process_material.scale_min = 0.06
	process_material.scale_max = 0.13
	splash.process_material = process_material
	var droplet := SphereMesh.new()
	droplet.radius = 0.075
	droplet.height = 0.15
	droplet.radial_segments = 8
	droplet.rings = 4
	var droplet_material := StandardMaterial3D.new()
	droplet_material.albedo_color = Color("#C8F8FA")
	droplet_material.roughness = 0.18
	droplet.material = droplet_material
	splash.draw_pass_1 = droplet
	splash.position = Vector3(fall_position.x, 1.16, fall_position.z)
	add_child(splash)
	splash.finished.connect(splash.queue_free)
	splash.emitting = true

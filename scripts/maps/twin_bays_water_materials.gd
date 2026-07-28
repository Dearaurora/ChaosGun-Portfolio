extends RefCounted
class_name TwinBaysWaterMaterials

## Single material authority for every Twin Bays shallow-water layer. The map
## controllers may choose colors and phase parameters, but they may not create
## their own replacement water shaders.

const MASTER_SHADER_PATH := "res://assets/shaders/twin_bays_water_master.gdshader"
const MASTER_SHADER: Shader = preload(MASTER_SHADER_PATH)
const MASTER_SHADER_V4_PATH := "res://assets/shaders/twin_bays_water_master_v4.gdshader"
const MASTER_SHADER_V4: Shader = preload(MASTER_SHADER_V4_PATH)
const MASTER_SHADER_V5_PATH := "res://assets/shaders/twin_bays_water_master_v5.gdshader"
const MASTER_SHADER_V5: Shader = preload(MASTER_SHADER_V5_PATH)

const LAYER_WET_BED := 0
const LAYER_SURFACE := 1
const LAYER_MENISCUS := 2


static func wet_bed_from_config(config: Dictionary) -> ShaderMaterial:
	return create_material(
		LAYER_WET_BED,
		_color_with_alpha(config, "wet_bed_color", "wet_bed_alpha", "#58B9C9", 0.24),
		float(config.get("wet_bed_roughness", 0.42)),
		float(config.get("wet_bed_specular", 0.24)),
		float(config.get("wet_bed_normal_strength", 0.12)),
		0.0,
		config)


static func surface_from_config(config: Dictionary) -> ShaderMaterial:
	return create_material(
		LAYER_SURFACE,
		_color_with_alpha(config, "water_color", "water_alpha", "#7BE5EC", 0.46),
		float(config.get("water_roughness", 0.20)),
		float(config.get("specular", 0.42)),
		float(config.get("normal_strength", 0.72)),
		float(config.get("highlight_strength", 0.28)),
		config)


static func meniscus_from_config(config: Dictionary) -> ShaderMaterial:
	return create_material(
		LAYER_MENISCUS,
		_color_with_alpha(config, "meniscus_color", "meniscus_alpha", "#D2FBFC", 0.38),
		float(config.get("meniscus_roughness", 0.14)),
		float(config.get("meniscus_specular", 0.52)),
		float(config.get("meniscus_normal_strength", 0.18)),
		float(config.get("meniscus_highlight_strength", 0.16)),
		config)


static func create_surface(
	color: Color,
	alpha: float,
	roughness: float,
	highlight: float,
	normal: float = 0.72,
	specular: float = 0.42,
	flow_config: Dictionary = {}
) -> ShaderMaterial:
	color.a = alpha
	return create_material(LAYER_SURFACE, color, roughness, specular, normal, highlight, flow_config)


static func create_wet_bed(color: Color, alpha: float, roughness: float, config: Dictionary = {}) -> ShaderMaterial:
	color.a = alpha
	return create_material(
		LAYER_WET_BED, color, roughness,
		float(config.get("wet_bed_specular", 0.24)),
		float(config.get("wet_bed_normal_strength", 0.12)), 0.0, config)


static func create_meniscus(color: Color, alpha: float, roughness: float, config: Dictionary = {}) -> ShaderMaterial:
	color.a = alpha
	return create_material(
		LAYER_MENISCUS, color, roughness,
		float(config.get("meniscus_specular", 0.52)),
		float(config.get("meniscus_normal_strength", 0.18)),
		float(config.get("meniscus_highlight_strength", 0.16)), config)


static func create_material(
	layer: int,
	color: Color,
	roughness: float,
	specular: float,
	normal: float,
	highlight: float,
	flow_config: Dictionary = {}
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = "TBSA_WaterMaster_%s" % _layer_name(layer)
	apply_shader_variant(material, flow_config)
	material.set_shader_parameter("layer_mode", layer)
	material.set_shader_parameter("water_color", color)
	material.set_shader_parameter("alpha_scale", 1.0)
	material.set_shader_parameter("water_roughness", roughness)
	material.set_shader_parameter("water_specular", specular)
	material.set_shader_parameter("normal_strength", normal)
	material.set_shader_parameter("highlight_strength", highlight)
	material.set_shader_parameter("flow_a", _vector2(flow_config.get("flow_speed_a", [0.032, -0.019]) as Array))
	material.set_shader_parameter("flow_b", _vector2(flow_config.get("flow_speed_b", [-0.016, 0.028]) as Array))
	material.set_shader_parameter("scale_a", float(flow_config.get("flow_scale_a", 0.22)))
	material.set_shader_parameter("scale_b", float(flow_config.get("flow_scale_b", 0.37)))
	material.set_meta("twin_bays_water_master", true)
	material.set_meta("layer", _layer_name(layer))
	material.set_meta("lit", true)
	material.set_meta("depth_prepass", true)
	return material


static func is_master_material(material: Material) -> bool:
	return material is ShaderMaterial \
		and (material as ShaderMaterial).shader in [MASTER_SHADER, MASTER_SHADER_V4, MASTER_SHADER_V5] \
		and bool(material.get_meta("twin_bays_water_master", false))


static func apply_shader_variant(material: ShaderMaterial, config: Dictionary) -> void:
	var shader_path := shader_path_for_config(config)
	if shader_path == MASTER_SHADER_V5_PATH:
		material.shader = MASTER_SHADER_V5
	elif shader_path == MASTER_SHADER_V4_PATH:
		material.shader = MASTER_SHADER_V4
	else:
		material.shader = MASTER_SHADER
	material.set_meta("twin_bays_water_master", true)
	material.set_meta("master_shader_path", shader_path)


static func shader_path_for_config(config: Dictionary) -> String:
	var variant := String(config.get("water_shader_variant", ""))
	if variant == "v5_broad_caustics":
		return MASTER_SHADER_V5_PATH
	if variant == "v4_clear":
		return MASTER_SHADER_V4_PATH
	return MASTER_SHADER_PATH


static func shader_path_for_material(material: Material) -> String:
	if material and material.has_meta("master_shader_path"):
		return String(material.get_meta("master_shader_path"))
	return MASTER_SHADER_PATH


static func _color_with_alpha(
	config: Dictionary,
	color_key: String,
	alpha_key: String,
	fallback_color: String,
	fallback_alpha: float
) -> Color:
	var color := Color(String(config.get(color_key, fallback_color)))
	color.a = float(config.get(alpha_key, fallback_alpha))
	return color


static func _vector2(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1])) if values.size() >= 2 else Vector2.ZERO


static func _layer_name(layer: int) -> String:
	match layer:
		LAYER_WET_BED: return "wet_bed"
		LAYER_MENISCUS: return "meniscus"
	return "surface"

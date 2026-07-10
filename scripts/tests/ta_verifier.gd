extends SceneTree

func _initialize():
	print("==================================================")
	print("🛡️ [QA Reviewer] 启动自动化技术美术 (TA) 管线验证...")
	print("==================================================")
	
	var main_node = Node.new()
	root.add_child(main_node)
	
	var arena_scene = load("res://scenes/maps/battle_arena.tscn")
	if not arena_scene:
		print("[CRITICAL] 无法加载 battle_arena.tscn! 路径错误。")
		quit()
		return
		
	var arena = arena_scene.instantiate()
	main_node.add_child(arena)
	
	# 手动触发物理帧或等待，让生成的 Kaykit 块和所有的 _ready() 跑完。
	# 注意：在 --headless 下，SceneTree 默认不走正常的 process，需要主动 pump，或只是静态检测即可。
	# 由于 ta_pipeline 是在 _ready 里同步运行的，挂载到树上后 _ready 已经执行完毕了。
	
	print("\n--- 1. 检测环境与光影系统 (WorldEnvironment) ---")
	var env_node = arena.get_node_or_null("WorldEnvironment")
	if env_node and env_node.environment:
		var e = env_node.environment
		var tm_mode = "ACES" if e.tonemap_mode == Environment.TONE_MAPPER_ACES else "Linear或其他"
		print("✅ 找到 WorldEnvironment 节点！")
		print("   👉 Tone Mapping 模式: ", tm_mode)
		print("   👉 开启 SSAO: ", "是" if e.ssao_enabled else "否", " | 强度: ", e.ssao_intensity)
		print("   👉 环境光模式被覆盖: ", "是" if e.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR else "否")
	else:
		print("❌ 缺失 WorldEnvironment 节点或环境数据！")
		
	print("\n--- 2. 检测摄像机透视学 (Camera3D) ---")
	var camera = arena.get_node_or_null("GlobalCamera")
	if camera:
		var mode = "Ortho (等距)" if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else "Perspective (透视)"
		print("✅ 找到主相机！")
		print("   👉 强制透视模式: ", mode)
		print("   👉 视窗大小(正交Size): ", camera.size)
	else:
		print("⚠️ GlobalCamera 不存在。（请确保场景树里是叫这个名字，或需要修复名字映射）")
		
	print("\n--- 3. 检测全场景材质碾压效应 (PBR Flatten) ---")
	var stats = {"total_meshes": 0, "flattened": 0, "failed": 0}
	_verify_mesh_materials(arena, stats)
	
	print("✅ 共检测到 3D 网格模型数量: ", stats["total_meshes"])
	print("✅ 成功剥夺金属度与高光: ", stats["flattened"])
	if stats["failed"] > 0:
		print("❌ 漏网之鱼未处理材质: ", stats["failed"])
		
	print("\n==================================================")
	print("🏁 [QA Reviewer] 验证评估完毕。准备退出。")
	print("==================================================")
	
	quit()

func _verify_mesh_materials(node: Node, stats: Dictionary) -> void:
	if node is MeshInstance3D:
		stats["total_meshes"] += 1
		# 提取表面覆写材质
		var all_ok = true
		for i in range(node.mesh.get_surface_count() if node.mesh else 0):
			var mat = node.get_surface_override_material(i)
			if mat and (mat is StandardMaterial3D or mat is ORMMaterial3D):
				if mat.metallic > 0.01 or mat.specular_mode != BaseMaterial3D.SPECULAR_DISABLED:
					all_ok = false
		if all_ok:
			stats["flattened"] += 1
		else:
			stats["failed"] += 1
			
	for child in node.get_children():
		_verify_mesh_materials(child, stats)

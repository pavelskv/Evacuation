extends Node3D

## Дым для тренажёра эвакуации.
## ТРЕБУЕТСЯ: назначить текстуру дыма в инспекторе (Smoke Texture)

@export var smoke_texture: Texture2D  # ОБЯЗАТЕЛЬНО назначить в инспекторе!
@export_range(0.0, 1.0, 0.05) var intensity: float = 0.5:
	set(value):
		intensity = clamp(value, 0.0, 1.0)
		_update_intensity()

var particles: GPUParticles3D
var process_material: ParticleProcessMaterial


func _ready() -> void:
	# Проверяем, что текстура назначена
	if not smoke_texture:
		push_error("Smoke: НЕ НАЗНАЧЕНА текстура дыма! Перетащите текстуру в поле 'Smoke Texture' в инспекторе.")
		return
	
	_create_smoke()


func _create_smoke() -> void:
	particles = GPUParticles3D.new()
	particles.name = "SmokeParticles"
	
	# Плотный дым
	particles.amount = 80
	particles.lifetime = 4.0
	particles.explosiveness = 0.0
	particles.randomness = 0.5
	particles.visibility_aabb = AABB(Vector3(-5, 0, -5), Vector3(10, 12, 10))
	
	process_material = ParticleProcessMaterial.new()
	process_material.direction = Vector3(0, 1, 0)
	process_material.spread = 35.0
	process_material.initial_velocity_min = 1.0
	process_material.initial_velocity_max = 1.8
	process_material.gravity = Vector3(0, 1.2, 0)
	process_material.damping_min = 0.5
	process_material.damping_max = 1.0
	process_material.angular_velocity_min = -45.0
	process_material.angular_velocity_max = 45.0
	
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.3))
	scale_curve.add_point(Vector2(0.5, 1.2))
	scale_curve.add_point(Vector2(1.0, 2.0))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	process_material.scale_curve = scale_tex
	
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.3, 0.3, 0.3, 0.0))
	gradient.add_point(0.15, Color(0.3, 0.3, 0.3, 0.8))
	gradient.add_point(0.6, Color(0.3, 0.3, 0.3, 0.6))
	gradient.set_color(3, Color(0.3, 0.3, 0.3, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_material.color_ramp = gradient_tex
	
	particles.process_material = process_material
	
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = smoke_texture  # Используем внешнюю текстуру
	
	quad.material = mat
	particles.draw_pass_1 = quad
	
	add_child(particles)
	_update_intensity()


func _update_intensity() -> void:
	if process_material == null:
		return
	
	particles.amount = int(lerp(30.0, 100.0, intensity))
	process_material.initial_velocity_min = lerp(0.6, 1.5, intensity)
	process_material.initial_velocity_max = lerp(1.2, 2.2, intensity)
	
	var gray: float = lerp(0.5, 0.15, intensity)
	var gradient: Gradient = (process_material.color_ramp as GradientTexture1D).gradient
	if gradient:
		gradient.set_color(0, Color(gray, gray, gray, 0.0))
		gradient.set_color(1, Color(gray, gray, gray, lerp(0.5, 0.9, intensity)))
		gradient.set_color(2, Color(gray, gray, gray, lerp(0.4, 0.7, intensity)))
		gradient.set_color(3, Color(gray, gray, gray, 0.0))


func set_intensity(value: float) -> void:
	intensity = value


func set_active(active: bool) -> void:
	particles.emitting = active

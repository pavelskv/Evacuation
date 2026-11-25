extends RefCounted
class_name ShaderWarmup

## Прогревает шейдеры в основном viewport:
## на короткое время поворачивает реальную камеру игрока, ждёт завершения
## каждого кадра и возвращает исходный поворот.
##
## Это помогает с материалами, которые попадают в кадр при осмотре вокруг,
## но не гарантирует компиляцию всех возможных shader-вариантов.

static func run(camera: Camera3D, loading_screen: LoadingScreen, steps: int = 12) -> void:
	if not is_instance_valid(camera):
		push_warning("ShaderWarmup: камера игрока не найдена")
		return

	steps = maxi(steps, 4)
	var original_rotation: Vector3 = camera.rotation
	camera.make_current()

	for i in range(steps):
		var angle := TAU * float(i + 1) / float(steps)
		camera.rotation = original_rotation + Vector3(0.0, angle, 0.0)

		# Ждём именно отрисовку кадра, а не только обновление дерева сцены.
		await RenderingServer.frame_post_draw

		var progress := 65.0 + 30.0 * float(i + 1) / float(steps)
		loading_screen.set_progress(progress)

	camera.rotation = original_rotation
	await RenderingServer.frame_post_draw

class_name RBCM_TaskTimer extends Timer

@onready var loader = get_parent() 

var update_speed_in_sec := 0.5
var exec := RBCM_Exec.new()

var data: Variant

func _init(_data: Variant) -> void:
	data = _data
	
	RBCM_GameClient.send(RBCM.Request.ChangeTaskState, [data.id, RBCM_TaskNode.State.ACTIVE])
	
	if not data.code.on_active.is_empty():
		exec.run(data.code.on_active)
	
	timeout.connect(_condition_check)
	
	wait_time = update_speed_in_sec
	one_shot = false
	autostart = true


func _ready() -> void:
	loader.tasks_active.append(data.id)
		

func stop_and_destroy() -> void:
	stop()
	loader.tasks_active.erase(data.id)
	queue_free()

func _condition_check():
	if exec.check(data.code.condition):
		stop()
		
		# Оперативное отключение нод-конкурентов, если нода вида "Задача" и она "Приоритетная"
		if int(data.type) == RBCM_GraphNode.NodeType.TASK and int(data.priority) == 1:
			var current_timers_running = loader.get_children()
			for timer in current_timers_running: 
				
				if int(timer.data.type) == RBCM_GraphNode.NodeType.TASK and int(timer.data.priority) == 1:
					# Исключить себя из обработки
					if data.id != timer.data.id:
						
						# Если хоть один наш родитель есть среди списка родителей конкурентного
						# таймера, то у нас с ним общий предок и такого конкурента надо удалять
						for parent in data.parent_ids:
							if parent in timer.data.parent_ids:
								# Удалить конкурентные таймеры с выставленным приоритетом
								RBCM_GameClient.send(RBCM.Request.ChangeTaskState, 
													[timer.data.id, RBCM_TaskNode.State.DISABLED])
								timer.stop_and_destroy()


		RBCM_GameClient.send(RBCM.Request.ChangeTaskState, [data.id, RBCM_TaskNode.State.COMPLETED])
		
		if not data.code.on_completed.is_empty():
			exec.run(data.code.on_completed)
		
		if not data.out_connection_ids.is_empty():
			for out_connection_id in data.out_connection_ids: 
				var out_node_data = loader.nodes[loader.find_node_index_by_id(out_connection_id)]
				
				# На случай увеличения кол-ва возможных нод
				if int(data.type) == RBCM_GraphNode.NodeType.TASK:
					var task_timer = RBCM_TaskTimer.new(out_node_data)
					loader.add_child(task_timer)
		
		loader.tasks_active.erase(data.id)
		queue_free()
		
		

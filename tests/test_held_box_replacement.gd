extends SceneTree

## Regression test: a pickup after COPYTO must replace the old carried visual,
## rather than leaving it parented underneath the new box.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var level := Level.new()
	level.inbox = [1, 2] as Array[int]
	level.memory_size = 1

	var room := RoomView.new()
	root.add_child(room)
	room.setup(level)
	await process_frame

	await room._do_inbox()
	var first_box := room.worker.held_box

	var copy_action := StepAction.new()
	copy_action.address = 0
	copy_action.memory_value = 1
	await room._do_copyto(copy_action)
	await room._do_inbox()
	await process_frame

	var held_number_boxes := 0
	for child in room.worker.get_children():
		if child is NumberBox:
			held_number_boxes += 1

	var passed := (
		room.worker.held_box != first_box
		and room.worker.held_box.value == 2
		and held_number_boxes == 1
		and not is_instance_valid(first_box)
	)
	print("held boxes = ", held_number_boxes)
	print("RESULT: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)

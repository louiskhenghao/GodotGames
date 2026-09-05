class_name CoreVirtualStick
extends Control
## Floating stick; owns a single touch and accepts mouse dragging for desktop QA.
var vector := Vector2.ZERO
var origin := Vector2.ZERO
var tip := Vector2.ZERO
var finger := -1
var radius := 62.0
var enabled := false
var blocked_rects: Array[Rect2] = []

func _can_begin(point: Vector2) -> bool:
	if point.y < 160: return false
	for rect in blocked_rects:
		if rect.has_point(point): return false
	return true

func _local(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func reset() -> void:
	vector = Vector2.ZERO
	finger = -1
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not enabled:
		reset()
		return
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1 and _can_begin(event.position):
			finger = event.index
			origin = _local(event.position)
			tip = origin
		elif not event.pressed and event.index == finger:
			reset()
	elif event is InputEventScreenDrag and event.index == finger:
		_move(_local(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and finger == -1 and _can_begin(event.position):
			finger = 999
			origin = _local(event.position)
			tip = origin
		elif not event.pressed and finger == 999:
			reset()
	elif event is InputEventMouseMotion and finger == 999:
		_move(_local(event.position))
	queue_redraw()

func _move(point: Vector2) -> void:
	vector = ((point - origin) / radius).limit_length()
	tip = origin + vector * radius

func _draw() -> void:
	if finger == -1:
		return
	draw_circle(origin, radius, Color(0.04, 0.10, 0.16, 0.45))
	draw_arc(origin, radius, 0, TAU, 48, Color(0.5, 1, 0.9, 0.6), 2, true)
	draw_circle(tip, 24, Color(0.3, 0.94, 0.82, 0.8))

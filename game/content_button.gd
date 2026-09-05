class_name RushContentButton
extends Button
## Button semantics with a content-driven height, including wrapped text.
var content: MarginContainer
func _ready() -> void:
	if content == null:return
	resized.connect(_fit)
	content.minimum_size_changed.connect(_fit)
	_fit()
func _fit() -> void:
	if content == null:return
	custom_minimum_size.y = content.get_combined_minimum_size().y

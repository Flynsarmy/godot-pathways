@tool
extends MarginContainer

# Public properties
var pathway_piece : PathwayPiece: set = set_pathway_piece

# Private properties
var _camera_factor : Vector2 = Vector2(1.0, 1.0)

# Node references
@onready var viewport_root : SubViewport = $SubViewport
@onready var viewport_camera : Camera3D = $SubViewport/Camera3D
@onready var viewport_mesh : Node3D = $SubViewport/MeshInstance3D

@onready var preview_texture : TextureRect = $PreviewTexture
@onready var handle_reference : Control = $HandleLayer/RefCounted
@onready var orientation_arrow : TextureRect = $OrientationArrow
@onready var zoom_bar : ScrollBar = $ZoomBar
@onready var zoom_label : Label = $ZoomBar/Label

func _ready() -> void:
	_update_preview()

	zoom_bar.value = viewport_camera.size
	zoom_label.text = "%.1f" % zoom_bar.value
	zoom_bar.value_changed.connect(_update_zoom)

	orientation_arrow.texture = EditorInterface.get_editor_theme().get_icon("piece_arrow", "PathwaysPlugin")

	handle_reference.draw.connect(_draw_handles)
	resized.connect(_update_overlays)
	item_rect_changed.connect(_update_overlays)
	visibility_changed.connect(_update_overlays)

func _draw_handles() -> void:
	if (!pathway_piece || pathway_piece.piece_type != PathwayPiece.PieceType.INTERSECTION):
		return

	var origin_handle = pathway_piece.intersection_origin_point
	var bone_handles = pathway_piece.get_intersection_branches()
	var bone_radius = pathway_piece.intersection_branch_radius
	var editor_theme: Theme = EditorInterface.get_editor_theme()

	for bone_handle in bone_handles:
		_draw_handles_line(bone_handle, origin_handle, editor_theme.get_color("intersection_lines", "PathwaysPlugin"), 2.0)
		_draw_handles_area(bone_handle, bone_radius, editor_theme.get_color("intersection_areas", "PathwaysPlugin"))
		_draw_handle(editor_theme.get_icon("node_handle", "PathwaysPlugin"), bone_handle)

	_draw_handle(editor_theme.get_icon("node_handle", "PathwaysPlugin"), origin_handle)

func _draw_handles_line(from_position: Vector2, to_position: Vector2, color: Color, width: float = 1.0) -> void:
	var from_spatial = Vector2(from_position.x * _camera_factor.x, from_position.y * _camera_factor.y)
	var to_spatial = Vector2(to_position.x * _camera_factor.x, to_position.y * _camera_factor.y)

	handle_reference.draw_line(from_spatial + Vector2.DOWN, to_spatial + Vector2.DOWN, Color.BLACK, width)
	handle_reference.draw_line(from_spatial, to_spatial, color, width)

func _draw_handles_area(at_position: Vector2, radius: float, color: Color) -> void:
	var spatial_position = Vector2(at_position.x * _camera_factor.x, at_position.y * _camera_factor.y)
	var spatial_radius = radius * _camera_factor.x

	handle_reference.draw_circle(spatial_position, spatial_radius, color)

func _draw_handle(icon: Texture2D, at_position: Vector2) -> void:
	var spatial_position = Vector2(at_position.x * _camera_factor.x, at_position.y * _camera_factor.y)
	var draw_position = spatial_position - icon.get_size() / 2
	handle_reference.draw_texture(icon, draw_position)

# Properties
func set_pathway_piece(value: PathwayPiece) -> void:
	if (pathway_piece == value):
		return

	if (pathway_piece):
		pathway_piece.mesh_changed.disconnect(_update_preview)
	pathway_piece = value

	if (pathway_piece):
		pathway_piece.mesh_changed.connect(_update_preview)
	_update_preview()

# Helpers
func _update_preview() -> void:
	if (!is_inside_tree()):
		return

	if (!pathway_piece):
		viewport_mesh.mesh = null
		return

	# TODO: Auto-adjust camera to fit the entire model.
	# TODO: Remove the zoom bar then, it's a temporary ad-hoc solution.
	viewport_mesh.mesh = pathway_piece.get_mesh()
	# Make sure things settle before updating the overlays, otherwise it breaks.
	call_deferred("_update_overlays")

func _update_overlays() -> void:
	if (!is_inside_tree()):
		return

	# Convert unit distance from camera/viewport coordinates to the UI coordinates.
	var viewport_unit = viewport_camera.unproject_position(Vector3(1, 0, 1)) - (viewport_root.size as Vector2) / 2
	var viewport_scale = min(preview_texture.size.x, preview_texture.size.y) / viewport_root.size.x
	_camera_factor = viewport_unit * viewport_scale

	handle_reference.queue_redraw()

func _update_zoom(value: float) -> void:
	zoom_label.text = "%.1f" % value

	viewport_camera.size = value
	_update_overlays()

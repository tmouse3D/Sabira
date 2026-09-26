# Godot 4.x - Sabira / HOUSE
class_name Doorway
extends Node3D
## Reusable door-in-wall prefab: optional CSG wall segment with boolean hole,
## wood frame (jambs + header), and hinged Door leaf (Open/Close prompts).
##
## Placement (local space):
## - Origin = hinge at floor, wall centered on X=0 (wall normal = X)
## - Door leaf swings around Y and extends along +Z (same as Door.tscn)
## - Rotate the Doorway root so +Z runs along the wall face
##
## New wall: leave include_wall_segment=true (default) - prefab supplies
## a short wall strip with a boolean doorway hole + frame + door.
## Existing cut gap: set include_wall_segment=false - frame + door only.

@export var include_wall_segment: bool = true
@export var wall_width: float = 1.4
@export var wall_height: float = 2.8
@export var wall_thickness: float = 0.2
@export var opening_width: float = 0.95
@export var opening_height: float = 2.15
@export var open_angle_deg: float = 90.0
@export var starts_open: bool = false
@export var locked: bool = false
@export var required_key: String = ""
@export var use_dark_wall: bool = true

@onready var _wall_segment: CSGCombiner3D = $WallSegment
@onready var _wall_box: CSGBox3D = $WallSegment/Wall
@onready var _hole: CSGBox3D = $WallSegment/Hole
@onready var _door: Door = $Door


func _ready() -> void:
	_apply_wall_segment()
	_apply_door_props()


func _apply_wall_segment() -> void:
	if _wall_segment == null:
		return
	_wall_segment.visible = include_wall_segment
	_wall_segment.use_collision = include_wall_segment
	if not include_wall_segment:
		return
	# Wall strip centered on the opening (hinge at z=0, opening along +Z).
	var mid_z := opening_width * 0.5
	_wall_box.size = Vector3(wall_thickness, wall_height, wall_width)
	_wall_box.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, wall_height * 0.5, mid_z))
	# Slightly oversized hole so CSG clears the opening cleanly.
	_hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	_hole.size = Vector3(wall_thickness + 0.15, opening_height, opening_width)
	_hole.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, opening_height * 0.5, mid_z))
	var wall_mat: Material = null
	if use_dark_wall:
		wall_mat = load("res://materials/mat_wall_dark.tres") as Material
	else:
		wall_mat = load("res://materials/mat_wall.tres") as Material
	if wall_mat:
		_wall_box.material = wall_mat


func _apply_door_props() -> void:
	if _door == null:
		return
	_door.configure_from_parent(open_angle_deg, starts_open, locked, required_key)

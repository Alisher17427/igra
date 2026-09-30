extends Node
## Wraps the level in the PSX low-res/dither screen. Material conversion (PSX.convert) is
## skipped: the Free addon only ships the "lit" shader, which can't handle the vegetation
## pack's alpha-cutout foliage cards and renders them as solid black blocks instead.

const PSXScreenScript := preload("res://addons/psx_look/psx_screen.gd")
const HudScript := preload("res://scripts/hud.gd")
const ForestScene := preload("res://scenes/forest_scene.tscn")


func _ready() -> void:
	var psx: SubViewportContainer = PSXScreenScript.new()
	add_child(psx)

	var level := ForestScene.instantiate()
	psx.viewport.add_child(level)

	var hud: CanvasLayer = HudScript.new()
	add_child(hud)
	hud.call("bind_player", level.get_node("Player"))

class_name PauseScreen
extends UIScreen
## Pause card. Works while the tree is paused.

signal resume_pressed
signal quit_pressed

@export var resume_button_path: NodePath = ^"Center/Card/Margin/Column/ResumeButton"
@export var quit_button_path: NodePath = ^"Center/Card/Margin/Column/QuitButton"


func _ready() -> void:
	super._ready()
	var resume := get_node_or_null(resume_button_path) as Button
	var quit := get_node_or_null(quit_button_path) as Button
	if resume:
		resume.pressed.connect(func() -> void: resume_pressed.emit())
	if quit:
		quit.pressed.connect(func() -> void: quit_pressed.emit())


func show_screen() -> void:
	super.show_screen()
	var resume := get_node_or_null(resume_button_path) as Button
	if resume:
		resume.grab_focus.call_deferred()

@tool
extends EditorPlugin

## Button for starting export process.
var button: Button

## Whether the export process has started.
var start: bool = false

## The project name retrieved from project settings.
var project_name = ProjectSettings.get_setting("application/config/name")

## Path variables.
var base_path: String
var export_path = project_name + ".exe"
var console_exe = project_name + ".console.exe"

## Arguments for remote debugging.
var run_args = [
	"--debug-server", "tcp://127.0.0.1:6007",
	"--remote-debug", "tcp://127.0.0.1:6007",
	"--verbose", "-1",
]

func _enter_tree() -> void:
	base_path = ProjectSettings.globalize_path("res://") + "Export/"
	set_physics_process(false)

	button = Button.new()
	button.text = ">"
	button.tooltip_text = "Remote Debug (F7)"
	button.pressed.connect(_on_button_pressed)
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, button)


func _exit_tree() -> void:
	if !DirAccess.dir_exists_absolute(base_path):
		var dir = DirAccess.open(base_path)
		dir.make_dir("new_directory")
	set_physics_process(false)
	remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, button)
	button.queue_free()


# Function to clean up previous exports (called when plugin loads)
func _cleanup_previous_exports() -> void:
	var cleanup_path = base_path + "*.*"
	var command = "powershell"
	var args = ["-Command", "Remove-Item", cleanup_path, "-Force"]
	var output = []
	OS.execute(command, args)
	set_physics_process(true)
	start = true


# Function to start the export process
func _start_export_process() -> void:
	var godot_path = OS.get_executable_path()
	var export_args = ["--headless", "--export-debug", "debug", base_path + export_path]
	var res = OS.execute(godot_path, export_args)
	if res:
		set_physics_process(false)


# Define the _on_button_pressed function (for button press event)
func _on_button_pressed() -> void:
	get_editor_interface().stop_playing_scene()
	_kill_exported_process()
	_cleanup_previous_exports()


func _input(event: InputEvent) -> void:
	if Input.is_physical_key_pressed(KEY_F7):
		_on_button_pressed()


# The _physics_process function to check for .pck file
func _physics_process(delta: float) -> void:
	if !start:
		return
	# Ensure that cleanup is done before starting the export.
	if DirAccess.get_files_at(base_path).is_empty():
		_start_export_process()
		return
	start = false
	OS.create_process(base_path + console_exe, run_args)
	set_physics_process(false)  # Disable physics process after running the exported game


func _kill_exported_process() -> void:
	var command = "powershell"
	var args = ["-Command", "Stop-Process", "-Name", project_name, "-Force"]
	OS.execute(command, args)
	OS.execute(command, args)
	await(get_tree().create_timer(2).timeout)

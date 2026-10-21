@tool
extends EditorPlugin
## 编辑器工具栏的 Git 按钮：首次启用引导配置，之后负责提交、推送、拉取。
## 详细流程见同目录 README.md。

var _project_dir := ""
var _runner: MiniGitRunner
var _config: Dictionary = {}
var _configured := false

var _menu_button: MenuButton
var _commit_dialog: ConfirmationDialog
var _message_edit: LineEdit
var _output_dialog: AcceptDialog
var _setup_dialog: MiniGitSetup


func _enter_tree() -> void:
	_project_dir = ProjectSettings.globalize_path("res://")
	_runner = MiniGitRunner.new(_project_dir)
	_config = MiniGitConfig.load_config(_project_dir)
	_configured = not _config.is_empty() and bool(_config.get("initialized", false))

	_build_toolbar()
	_build_dialogs()
	_refresh_menu()

	print("[MiniGit] is ready,Project:", _project_dir, ",Configured:", _configured, ",Language:", MiniGitI18n.current_locale())

	if not _configured and DisplayServer.get_name() != "headless":
		call_deferred("_open_setup")


func _exit_tree() -> void:
	if is_instance_valid(_menu_button):
		remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, _menu_button)
		_menu_button.queue_free()
	for node in [_commit_dialog, _output_dialog, _setup_dialog]:
		if is_instance_valid(node):
			node.queue_free()


func _build_toolbar() -> void:
	_menu_button = MenuButton.new()
	_menu_button.tooltip_text = MiniGitI18n.t("TOOLBAR_TIP")
	var popup := _menu_button.get_popup()
	popup.id_pressed.connect(_on_menu_id_pressed)
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, _menu_button)


func _refresh_menu() -> void:
	if not is_instance_valid(_menu_button):
		return
	var button_key := "BTN_GIT" if _configured else "BTN_GIT_UNCONFIGURED"
	_menu_button.text = MiniGitI18n.t(button_key)
	var popup := _menu_button.get_popup()
	popup.clear()
	if _configured:
		popup.add_item(MiniGitI18n.t("MENU_COMMIT_PUSH"), 0)
		popup.add_item(MiniGitI18n.t("MENU_PUSH_ONLY"), 1)
		popup.add_item(MiniGitI18n.t("MENU_PULL"), 2)
		popup.add_item(MiniGitI18n.t("MENU_STATUS"), 3)
		popup.add_separator()
	var configure_key := "MENU_CONFIGURE" if not _configured else "MENU_RECONFIGURE"
	popup.add_item(MiniGitI18n.t(configure_key), 9)


func _build_dialogs() -> void:
	_commit_dialog = ConfirmationDialog.new()
	_commit_dialog.title = MiniGitI18n.t("COMMIT_DIALOG_TITLE")
	_commit_dialog.ok_button_text = MiniGitI18n.t("COMMIT_OK")
	_commit_dialog.cancel_button_text = MiniGitI18n.t("CANCEL")
	_message_edit = LineEdit.new()
	_message_edit.placeholder_text = MiniGitI18n.t("COMMIT_PLACEHOLDER")
	_message_edit.custom_minimum_size = Vector2(560, 0)
	_commit_dialog.add_child(_message_edit)
	_commit_dialog.register_text_enter(_message_edit)
	_commit_dialog.confirmed.connect(_on_commit_confirmed)
	add_child(_commit_dialog)

	_output_dialog = AcceptDialog.new()
	_output_dialog.title = MiniGitI18n.t("OUTPUT_TITLE")
	_output_dialog.ok_button_text = MiniGitI18n.t("CLOSE")
	_output_dialog.min_size = Vector2i(820, 340)
	add_child(_output_dialog)


func _open_setup() -> void:
	if not is_instance_valid(_setup_dialog):
		_setup_dialog = MiniGitSetup.new()
		_setup_dialog.configured.connect(_on_setup_configured)
		add_child(_setup_dialog)
	_setup_dialog.open_for(_project_dir)


func _on_setup_configured(config: Dictionary) -> void:
	var err := MiniGitConfig.save_config(_project_dir, config)
	if err != OK:
		_show_output(MiniGitI18n.t("SAVE_CONFIG_FAILED_TITLE"), {
			"code": err,
			"text": MiniGitI18n.t("SAVE_CONFIG_FAILED_TEXT", [err]),
		})
		return
	_config = config
	_configured = true
	_refresh_menu()
	print("[MiniGit] Settings saved, features enabled.")


func _on_menu_id_pressed(id: int) -> void:
	if not _configured and id != 9:
		_open_setup()
		return
	match id:
		0:
			_message_edit.text = ""
			_commit_dialog.popup_centered(Vector2i(620, 120))
			_message_edit.grab_focus()
		1:
			_push()
		2:
			_pull()
		3:
			_show_output("git status", _runner.git(PackedStringArray(["status", "--short"])))
		9:
			_open_setup()


func _on_commit_confirmed() -> void:
	var message := _message_edit.text.strip_edges()
	if message.is_empty():
		_show_output(MiniGitI18n.t("COMMIT_MESSAGE_TITLE"), {
			"code": 1,
			"text": MiniGitI18n.t("COMMIT_MESSAGE_EMPTY"),
		})
		return
	_commit_and_push(message)


func _commit_and_push(message: String) -> void:
	var lines: Array[String] = []

	var added := _runner.git(PackedStringArray(["add", "-A"]))
	lines.append("$ git add -A\n" + String(added["text"]))
	if added["code"] != 0:
		_show_output(MiniGitI18n.t("GIT_ADD_FAILED"), {"code": added["code"], "text": "\n".join(lines)})
		return

	var staged := _runner.git(PackedStringArray(["diff", "--cached", "--quiet"]))
	if staged["code"] == 0:
		lines.append(MiniGitI18n.t("NOTHING_TO_COMMIT"))
		_show_output(MiniGitI18n.t("COMMIT_DIALOG_TITLE"), {"code": 0, "text": "\n".join(lines)})
		return

	var committed := _runner.git(PackedStringArray(["commit", "-m", message]))
	lines.append("$ git commit -m \"%s\"\n%s" % [message, String(committed["text"])])
	if committed["code"] != 0:
		_show_output(MiniGitI18n.t("GIT_COMMIT_FAILED"), {"code": committed["code"], "text": "\n".join(lines)})
		return

	var pushed := _runner.git(PackedStringArray(["push", "-u", "origin", "HEAD"]))
	lines.append("$ git push -u origin HEAD\n" + String(pushed["text"]))
	if pushed["code"] != 0:
		_show_output(MiniGitI18n.t("GIT_PUSH_FAILED"), {"code": pushed["code"], "text": "\n".join(lines)})
		return

	lines.append(MiniGitI18n.t("DONE"))
	_show_output(MiniGitI18n.t("COMMIT_DIALOG_TITLE"), {"code": 0, "text": "\n".join(lines)})


func _push() -> void:
	var result := _runner.git(PackedStringArray(["push", "-u", "origin", "HEAD"]))
	var prefix := "$ git push -u origin HEAD\n"
	var suffix := "" if result["code"] == 0 else "\n\n" + String(result["hint"])
	_show_output(MiniGitI18n.t("PUSH_TITLE") if result["code"] == 0 else MiniGitI18n.t("GIT_PUSH_FAILED"), {
		"code": result["code"],
		"text": prefix + String(result["text"]) + suffix,
	})


func _pull() -> void:
	var result := _runner.git(PackedStringArray(["pull", "--ff-only"]))
	var prefix := "$ git pull --ff-only\n"
	var suffix := "" if result["code"] == 0 else "\n\n" + String(result["hint"])
	_show_output(MiniGitI18n.t("PULL_TITLE") if result["code"] == 0 else MiniGitI18n.t("GIT_PULL_FAILED"), {
		"code": result["code"],
		"text": prefix + String(result["text"]) + suffix,
	})


func _show_output(title: String, result: Dictionary) -> void:
	var text: String = result["text"]
	print("[MiniGit] ", text)
	_output_dialog.title = title
	_output_dialog.dialog_text = text
	_output_dialog.popup_centered(Vector2i(820, 340))

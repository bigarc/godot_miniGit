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
var _output_text: TextEdit
var _setup_dialog: MiniGitSetup
var _job_thread: Thread
var _busy := false


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
	if _job_thread != null:
		_job_thread.wait_to_finish()
		_job_thread = null
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
	_output_dialog.min_size = Vector2i(760, 460)
	var output_margin := MarginContainer.new()
	output_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	output_margin.offset_left = 8
	output_margin.offset_top = 8
	output_margin.offset_right = -8
	output_margin.offset_bottom = -52
	_output_dialog.add_child(output_margin)
	_output_text = TextEdit.new()
	_output_text.editable = false
	_output_text.context_menu_enabled = true
	_output_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_output_text.scroll_smooth = true
	_output_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_margin.add_child(_output_text)
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
			_start_job("push")
		2:
			_start_job("pull")
		3:
			_start_job("status")
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
	_start_job("commit", message)


# --- 后台任务 -------------------------------------------------------------
# OS.execute 是同步阻塞的，直接在主线程跑会让整个编辑器卡住。这里把整条
# 命令序列放进 Thread，主线程只负责开始时禁用菜单、结束时显示结果。
# 一次只允许一个任务，避免两个 git 进程同时改同一个仓库。

func _start_job(kind: String, message := "") -> bool:
	if _busy:
		return false
	_job_thread = Thread.new()
	var err := _job_thread.start(_job_worker.bind(kind, message))
	if err != OK:
		_job_thread = null
		_show_output(MiniGitI18n.t("THREAD_FAILED_TITLE"), {
			"code": err,
			"text": MiniGitI18n.t("THREAD_FAILED_TEXT", [err]),
		})
		return false
	_set_busy(true, kind)
	return true


func _job_worker(kind: String, message: String) -> void:
	var result: Dictionary
	match kind:
		"commit":
			result = _worker_commit(message)
		"push", "pull", "status":
			result = _worker_simple(kind)
		_:
			result = {"action": kind, "code": 1, "text": "", "hint": ""}
	call_deferred("_on_job_finished", result)


func _worker_commit(message: String) -> Dictionary:
	var steps: Array[Dictionary] = []

	var added := _worker_git(PackedStringArray(["add", "-A"]), "git add -A")
	steps.append(added)
	if added["code"] != 0:
		return {"action": "commit", "steps": steps, "failed": "add"}

	var staged := _runner.git(PackedStringArray(["diff", "--cached", "--quiet"]))
	if staged["code"] == 0:
		return {"action": "commit", "steps": steps, "nothing": true}

	var committed := _worker_git(
		PackedStringArray(["commit", "-m", message]),
		"git commit -m \"%s\"" % message
	)
	steps.append(committed)
	if committed["code"] != 0:
		return {"action": "commit", "steps": steps, "failed": "commit"}

	var pushed := _worker_git(
		PackedStringArray(["push", "-u", "origin", "HEAD"]),
		"git push -u origin HEAD"
	)
	steps.append(pushed)
	if pushed["code"] != 0:
		return {"action": "commit", "steps": steps, "failed": "push"}

	return {"action": "commit", "steps": steps, "failed": ""}


func _worker_simple(kind: String) -> Dictionary:
	var args: PackedStringArray
	var echo := ""
	match kind:
		"push":
			args = PackedStringArray(["push", "-u", "origin", "HEAD"])
			echo = "git push -u origin HEAD"
		"pull":
			args = PackedStringArray(["pull", "--ff-only"])
			echo = "git pull --ff-only"
		_:
			args = PackedStringArray(["status", "--short"])
			echo = "git status --short"
	var result := _runner.git(args)
	return {
		"action": kind,
		"echo": echo,
		"code": result["code"],
		"text": String(result["text"]),
		"hint": String(result["hint"]),
	}


func _worker_git(args: PackedStringArray, echo: String) -> Dictionary:
	var result := _runner.git(args)
	return {
		"echo": echo,
		"code": result["code"],
		"text": String(result["text"]),
		"hint": String(result["hint"]),
	}


func _on_job_finished(result: Dictionary) -> void:
	if _job_thread != null:
		_job_thread.wait_to_finish()
		_job_thread = null
	_set_busy(false)

	match String(result.get("action", "")):
		"commit":
			_show_commit_result(result)
		"push":
			_show_push_pull_result(result, true)
		"pull":
			_show_push_pull_result(result, false)
		"status":
			_show_output("git status", result)


func _show_commit_result(result: Dictionary) -> void:
	var steps: Array = result["steps"]
	var lines: Array[String] = []
	for step in steps:
		lines.append("$ " + String(step["echo"]) + "\n" + String(step["text"]))

	var title_key := "COMMIT_DIALOG_TITLE"
	var failed := String(result.get("failed", ""))
	if bool(result.get("nothing", false)):
		lines.append(MiniGitI18n.t("NOTHING_TO_COMMIT"))
	elif not failed.is_empty():
		match failed:
			"add":
				title_key = "GIT_ADD_FAILED"
			"commit":
				title_key = "GIT_COMMIT_FAILED"
			_:
				title_key = "GIT_PUSH_FAILED"
	else:
		lines.append(MiniGitI18n.t("DONE"))

	var text := "\n".join(lines)
	if not failed.is_empty() and not steps.is_empty():
		var hint := String(steps[steps.size() - 1]["hint"])
		if not hint.is_empty():
			text += "\n\n" + hint

	var code := int(steps[steps.size() - 1]["code"]) if not steps.is_empty() else 1
	_show_output(MiniGitI18n.t(title_key), {"code": code, "text": text})


func _show_push_pull_result(result: Dictionary, is_push: bool) -> void:
	var text := "$ " + String(result["echo"]) + "\n" + String(result["text"])
	if result["code"] != 0:
		text += "\n\n" + String(result["hint"])

	var title_key := ""
	if is_push:
		title_key = "PUSH_TITLE" if result["code"] == 0 else "GIT_PUSH_FAILED"
	else:
		title_key = "PULL_TITLE" if result["code"] == 0 else "GIT_PULL_FAILED"
	_show_output(MiniGitI18n.t(title_key), {"code": result["code"], "text": text})


func _set_busy(busy: bool, kind := "") -> void:
	_busy = busy
	if not is_instance_valid(_menu_button):
		return
	_menu_button.disabled = busy
	if busy:
		_menu_button.text = _busy_text(kind)
	else:
		_refresh_menu()


func _busy_text(kind: String) -> String:
	match kind:
		"commit":
			return MiniGitI18n.t("BUSY_COMMIT")
		"push":
			return MiniGitI18n.t("BUSY_PUSH")
		"pull":
			return MiniGitI18n.t("BUSY_PULL")
		_:
			return MiniGitI18n.t("BUSY_STATUS")


func _show_output(title: String, result: Dictionary) -> void:
	var text := String(result.get("text", ""))
	print("[MiniGit] ", text)
	_output_dialog.title = title
	_output_text.text = text
	_output_text.set_caret_line(0)
	_output_text.set_caret_column(0)
	_output_text.scroll_vertical = 0
	_output_text.scroll_horizontal = 0
	_output_dialog.popup_centered_clamped(Vector2i(860, 560), 0.9)

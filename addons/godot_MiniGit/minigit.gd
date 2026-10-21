@tool
extends EditorPlugin
## 编辑器工具栏的 Git 按钮：首次启用引导配置，之后负责提交、推送、拉取。
##
## 为什么不走引擎内置的 VCS 接口：那是给 GDExtension 插件用的空壳，
## 标准版编辑器不带实现；官方 git 插件基于 libgit2，不走 git 的 clean/smudge
## 过滤器，对 Git LFS 仓库有风险，SSH 认证也常出问题。
## 这里直接调用系统 git，行为和你手敲命令行完全一致。
##
## 详细流程见同目录 DESIGN.md。

const PLUGIN_NAME := "MiniGit"

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

	print("[MiniGit] 插件已加载，仓库：", _project_dir, "，已配置：", _configured)

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
	_menu_button.tooltip_text = "提交、推送、拉取（调用系统 git，Git LFS 正常）"
	var popup := _menu_button.get_popup()
	popup.id_pressed.connect(_on_menu_id_pressed)
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, _menu_button)


func _refresh_menu() -> void:
	if not is_instance_valid(_menu_button):
		return
	_menu_button.text = "Git" if _configured else "Git（未配置）"
	var popup := _menu_button.get_popup()
	popup.clear()
	if _configured:
		popup.add_item("提交并推送…", 0)
		popup.add_item("仅推送", 1)
		popup.add_item("拉取（--ff-only）", 2)
		popup.add_item("查看状态", 3)
		popup.add_separator()
	popup.add_item("配置…" if not _configured else "重新配置…", 9)


func _build_dialogs() -> void:
	_commit_dialog = ConfirmationDialog.new()
	_commit_dialog.title = "提交并推送"
	_commit_dialog.ok_button_text = "提交并推送"
	_commit_dialog.cancel_button_text = "取消"
	_message_edit = LineEdit.new()
	_message_edit.placeholder_text = "提交说明，例如 feat(chess): 棋子移动"
	_message_edit.custom_minimum_size = Vector2(560, 0)
	_commit_dialog.add_child(_message_edit)
	_commit_dialog.register_text_enter(_message_edit)
	_commit_dialog.confirmed.connect(_on_commit_confirmed)
	add_child(_commit_dialog)

	_output_dialog = AcceptDialog.new()
	_output_dialog.title = "Git 输出"
	_output_dialog.ok_button_text = "关闭"
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
		_show_output("保存配置失败", {"code": err, "text": "无法写入 .git/minigit.cfg（错误码 %d）" % err})
		return
	_config = config
	_configured = true
	_refresh_menu()
	print("[MiniGit] 配置已保存，功能已启用。")


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
		_show_output("提交说明", {"code": 1, "text": "提交说明不能为空，已取消。"})
		return
	_commit_and_push(message)


func _commit_and_push(message: String) -> void:
	var lines: Array[String] = []

	var added := _runner.git(PackedStringArray(["add", "-A"]))
	lines.append("$ git add -A\n" + String(added["text"]))
	if added["code"] != 0:
		_show_output("失败：git add", {"code": added["code"], "text": "\n".join(lines)})
		return

	var staged := _runner.git(PackedStringArray(["diff", "--cached", "--quiet"]))
	if staged["code"] == 0:
		lines.append("没有需要提交的改动。")
		_show_output("提交并推送", {"code": 0, "text": "\n".join(lines)})
		return

	var committed := _runner.git(PackedStringArray(["commit", "-m", message]))
	lines.append("$ git commit -m \"%s\"\n%s" % [message, String(committed["text"])])
	if committed["code"] != 0:
		_show_output("失败：git commit", {"code": committed["code"], "text": "\n".join(lines)})
		return

	var pushed := _runner.git(PackedStringArray(["push", "-u", "origin", "HEAD"]))
	lines.append("$ git push -u origin HEAD\n" + String(pushed["text"]))
	if pushed["code"] != 0:
		_show_output("失败：git push", {"code": pushed["code"], "text": "\n".join(lines)})
		return

	lines.append("完成。")
	_show_output("提交并推送", {"code": 0, "text": "\n".join(lines)})


func _push() -> void:
	var result := _runner.git(PackedStringArray(["push", "-u", "origin", "HEAD"]))
	var prefix := "$ git push -u origin HEAD\n"
	var suffix := "" if result["code"] == 0 else "\n\n" + String(result["hint"])
	_show_output("推送" if result["code"] == 0 else "失败：git push", {
		"code": result["code"],
		"text": prefix + String(result["text"]) + suffix,
	})


func _pull() -> void:
	var result := _runner.git(PackedStringArray(["pull", "--ff-only"]))
	var prefix := "$ git pull --ff-only\n"
	var suffix := "" if result["code"] == 0 else "\n\n" + String(result["hint"])
	_show_output("拉取" if result["code"] == 0 else "失败：git pull", {
		"code": result["code"],
		"text": prefix + String(result["text"]) + suffix,
	})


func _show_output(title: String, result: Dictionary) -> void:
	var text: String = result["text"]
	print("[MiniGit] ", text)
	_output_dialog.title = title
	_output_dialog.dialog_text = text
	_output_dialog.popup_centered(Vector2i(820, 340))

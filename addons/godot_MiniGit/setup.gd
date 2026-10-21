@tool
class_name MiniGitSetup
extends AcceptDialog
## 首次启用的配置窗口：环境检测 → 纳入 git → 远端与传输方式 → 忽略文件与 LFS → 连通性。
## 只有点“保存并启用”并通过连通性测试，才写出 .git/minigit.cfg。

signal configured(config: Dictionary)

const REMOTE_NAME := "origin"
const GITHUB_KEYS_URL := "https://github.com/settings/keys"

var project_dir := ""
var runner: MiniGitRunner

var _root: VBoxContainer
var _env_status: RichTextLabel
var _repo_status: Label
var _init_button: Button
var _url_edit: LineEdit
var _transport: OptionButton
var _key_status: Label
var _gen_key_button: Button
var _pubkey: TextEdit
var _copy_button: Button
var _ignore_check: CheckBox
var _attr_check: CheckBox
var _lfs_check: CheckBox
var _conn_status: RichTextLabel
var _test_button: Button
var _save_button: Button
var _probe_thread: Thread
var _probe_ok := false


func _init() -> void:
	title = "Git 配置"
	ok_button_text = "关闭"
	min_size = Vector2i(760, 620)
	_build_ui()
	custom_action.connect(_on_custom_action)


func open_for(dir: String) -> void:
	project_dir = dir
	runner = MiniGitRunner.new(dir)
	_probe_ok = false
	refresh()
	popup_centered(Vector2i(780, 640))


func refresh() -> void:
	if runner == null:
		return
	var git := MiniGitEnv.git_version(runner)
	var lfs := MiniGitEnv.lfs_version(runner)
	var repo := MiniGitEnv.is_repo(runner)
	var url := MiniGitEnv.remote_url(runner)
	var keys := MiniGitEnv.find_ssh_keys()

	var lines: Array[String] = []
	if git["code"] == 0:
		lines.append("[color=green]✓ git[/color] " + String(git["text"]).strip_edges())
	else:
		lines.append("[color=red]✗ 没有找到 git[/color] 先安装 Git for Windows，并确认在 PATH 里")
	if lfs["code"] == 0:
		lines.append("[color=green]✓ git-lfs[/color] " + String(lfs["text"]).strip_edges())
	else:
		lines.append("[color=orange]! 没有找到 git-lfs[/color] 大文件先无法用 LFS，仍可继续")
	_env_status.text = "\n".join(lines)

	if repo:
		_repo_status.text = "已经是 git 仓库 ✓"
		_repo_status.modulate = Color(0.6, 0.9, 0.6)
	else:
		_repo_status.text = "还没有被 git 管理"
		_repo_status.modulate = Color(1.0, 0.8, 0.4)
	_init_button.disabled = repo

	if not url.is_empty() and _url_edit.text.strip_edges().is_empty():
		_url_edit.text = url
		if url.begins_with("git@"):
			_transport.select(0)
		else:
			_transport.select(1)

	if keys.is_empty():
		_key_status.text = "本机没有找到 SSH 密钥"
		_key_status.modulate = Color(1.0, 0.8, 0.4)
		_gen_key_button.disabled = false
	else:
		_key_status.text = "找到密钥：" + "\n".join(keys)
		_key_status.modulate = Color(0.6, 0.9, 0.6)
		_gen_key_button.disabled = true

	_ignore_check.text = ".gitignore（缺失时写入 Godot 推荐项）"
	_attr_check.text = ".gitattributes（缺失时写入换行规则 + LFS 规则）"
	_lfs_check.disabled = lfs["code"] != 0
	_save_button.disabled = not repo


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(730, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_root = VBoxContainer.new()
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_theme_constant_override("separation", 10)
	scroll.add_child(_root)

	# 1. 环境
	var sec := _section("1. 环境检测")
	_env_status = RichTextLabel.new()
	_env_status.bbcode_enabled = true
	_env_status.fit_content = true
	_env_status.custom_minimum_size = Vector2(0, 48)
	sec.add_child(_env_status)
	var recheck := Button.new()
	recheck.text = "重新检测"
	recheck.pressed.connect(refresh)
	sec.add_child(recheck)

	# 2. 仓库
	sec = _section("2. git 仓库")
	_repo_status = Label.new()
	sec.add_child(_repo_status)
	_init_button = Button.new()
	_init_button.text = "初始化 git 仓库（git init -b main）"
	_init_button.pressed.connect(_confirm_init)
	sec.add_child(_init_button)

	# 3. 远端
	sec = _section("3. 远端与传输方式")
	_url_edit = LineEdit.new()
	_url_edit.placeholder_text = "git@github.com:用户/仓库.git 或 https://github.com/用户/仓库.git"
	sec.add_child(_url_edit)
	_transport = OptionButton.new()
	_transport.add_item("SSH（使用本机密钥）", 0)
	_transport.add_item("HTTPS（交给 Git Credential Manager）", 1)
	_transport.item_selected.connect(_on_transport_changed)
	sec.add_child(_transport)
	_key_status = Label.new()
	_key_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sec.add_child(_key_status)
	var key_buttons := HBoxContainer.new()
	_gen_key_button = Button.new()
	_gen_key_button.text = "生成新的 ED25519 密钥"
	_gen_key_button.pressed.connect(_generate_key)
	key_buttons.add_child(_gen_key_button)
	_copy_button = Button.new()
	_copy_button.text = "复制公钥"
	_copy_button.disabled = true
	_copy_button.pressed.connect(_copy_public_key)
	key_buttons.add_child(_copy_button)
	sec.add_child(key_buttons)
	var github_link := LinkButton.new()
	github_link.text = "打开 GitHub → Settings → SSH and GPG keys"
	github_link.uri = GITHUB_KEYS_URL
	sec.add_child(github_link)
	_pubkey = TextEdit.new()
	_pubkey.editable = false
	_pubkey.custom_minimum_size = Vector2(0, 64)
	_pubkey.visible = false
	sec.add_child(_pubkey)

	# 4. 忽略与 LFS
	sec = _section("4. 忽略文件与 LFS")
	_ignore_check = CheckBox.new()
	_ignore_check.button_pressed = true
	sec.add_child(_ignore_check)
	_attr_check = CheckBox.new()
	_attr_check.button_pressed = true
	sec.add_child(_attr_check)
	_lfs_check = CheckBox.new()
	_lfs_check.text = "启用 Git LFS（git lfs install --local）"
	_lfs_check.button_pressed = true
	sec.add_child(_lfs_check)

	# 5. 连通性
	sec = _section("5. 与 GitHub 的连通性")
	_conn_status = RichTextLabel.new()
	_conn_status.bbcode_enabled = true
	_conn_status.fit_content = true
	_conn_status.custom_minimum_size = Vector2(0, 48)
	sec.add_child(_conn_status)
	_test_button = Button.new()
	_test_button.text = "测试连接"
	_test_button.pressed.connect(_test_connection)
	sec.add_child(_test_button)

	_save_button = add_button("保存并启用", true, "save")


func _section(title_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = title_text
	label.add_theme_font_size_override("font_size", 15)
	box.add_child(label)
	_root.add_child(box)
	return box


func _on_transport_changed(index: int) -> void:
	_probe_ok = false
	_conn_status.text = "传输方式改了，需要重新测试连接。"


func _on_custom_action(action: StringName) -> void:
	if action == &"save":
		_save()


func _confirm_init() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "初始化仓库"
	dlg.dialog_text = "当前项目还没有被 git 管理。\n\n将执行：git init -b main\n（只建本地仓库，不连远端）"
	dlg.ok_button_text = "确定"
	dlg.cancel_button_text = "取消"
	dlg.confirmed.connect(_do_init)
	add_child(dlg)
	dlg.popup_centered()
	dlg.visibility_changed.connect(func() -> void:
		if not dlg.visible:
			dlg.queue_free()
	)


func _do_init() -> void:
	var result := runner.git(PackedStringArray(["init", "-b", "main"]))
	print("[MiniGit] git init: ", result["text"])
	refresh()
	if result["code"] != 0:
		_conn_status.text = "[color=red]初始化失败[/color]\n" + String(result["text"])


func _generate_key() -> void:
	var dir := MiniGitEnv.ssh_dir()
	if dir.is_empty():
		_key_status.text = "找不到用户主目录，无法生成密钥"
		return
	var key_path := dir.path_join("id_ed25519")
	var email := "git-push@localhost"
	var email_result := runner.git(PackedStringArray(["config", "user.email"]))
	if email_result["code"] == 0 and not String(email_result["text"]).strip_edges().is_empty():
		email = String(email_result["text"]).strip_edges()

	var args := PackedStringArray([
		"-t", "ed25519", "-C", email, "-f", key_path, "-N", "",
	])
	var output: Array = []
	var code := OS.execute("ssh-keygen", args, output, true)
	var text := "".join(output)
	print("[MiniGit] ssh-keygen: ", text)
	if code != 0:
		_key_status.text = "生成失败，检查 OpenSSH 是否在 PATH 里。\n" + text
		return
	refresh()
	_show_public_key(key_path)


func _show_public_key(key_path: String) -> void:
	var pub_path := key_path + ".pub"
	var pub := FileAccess.get_file_as_string(pub_path)
	_pubkey.text = pub.strip_edges()
	_pubkey.visible = true
	_copy_button.disabled = pub.is_empty()
	_key_status.text = "已生成密钥，把下面的公钥加到 GitHub 后再测试连接。"


func _copy_public_key() -> void:
	DisplayServer.clipboard_set(_pubkey.text)
	_conn_status.text = "公钥已复制到剪贴板。"


func _test_connection() -> void:
	var url := _url_edit.text.strip_edges()
	if url.is_empty():
		_conn_status.text = "[color=orange]先填仓库地址[/color]"
		return
	if _probe_thread != null and _probe_thread.is_started():
		return
	var transport := "ssh" if _transport.selected == 0 else "https"
	_conn_status.text = "正在连接，最多等 8 秒…"
	_test_button.disabled = true
	_save_button.disabled = true
	_probe_thread = Thread.new()
	_probe_thread.start(_probe_worker.bind(url, transport))


func _probe_worker(url: String, transport: String) -> void:
	var result := runner.probe_remote(url, transport)
	call_deferred("_on_probe_done", result)


func _on_probe_done(result: Dictionary) -> void:
	if _probe_thread != null:
		_probe_thread.wait_to_finish()
		_probe_thread = null
	_test_button.disabled = false
	if result["code"] == 0:
		var count := 0
		for line in String(result["text"]).split("\n"):
			if not line.strip_edges().is_empty():
				count += 1
		_probe_ok = true
		_save_button.disabled = false
		_conn_status.text = "[color=green]连接成功[/color]，远端有 %d 个分支可读。" % count
	else:
		_probe_ok = false
		_save_button.disabled = false
		var hint := String(result["hint"])
		_conn_status.text = "[color=red]连接失败[/color] " + hint + "\n" + String(result["text"])


func _save() -> void:
	if runner == null:
		return
	if not MiniGitEnv.is_repo(runner):
		_conn_status.text = "[color=red]先初始化 git 仓库[/color]"
		return
	var url := _url_edit.text.strip_edges()
	if url.is_empty():
		_conn_status.text = "[color=red]仓库地址不能为空[/color]"
		return
	if not _probe_ok:
		_conn_status.text = "[color=red]先测试连接，成功了再保存[/color]"
		return

	var transport := "ssh" if _transport.selected == 0 else "https"
	var existing := MiniGitEnv.remote_url(runner, REMOTE_NAME)
	var remote_result: Dictionary
	if existing.is_empty():
		remote_result = runner.git(PackedStringArray(["remote", "add", REMOTE_NAME, url]))
	else:
		remote_result = runner.git(PackedStringArray(["remote", "set-url", REMOTE_NAME, url]))
	if remote_result["code"] != 0:
		_conn_status.text = "[color=red]写远端失败[/color]\n" + String(remote_result["text"])
		return

	var notes: Array[String] = []
	if _ignore_check.button_pressed:
		notes.append(_write_if_missing(".gitignore", MiniGitTemplates.GITIGNORE))
	if _attr_check.button_pressed:
		notes.append(_write_if_missing(".gitattributes", MiniGitTemplates.GITATTRIBUTES))
	if _lfs_check.button_pressed and not _lfs_check.disabled:
		var lfs := runner.git(PackedStringArray(["lfs", "install", "--local"]))
		notes.append("git lfs install：成功" if lfs["code"] == 0 else "git lfs install 失败")

	var config := {
		"remote_name": REMOTE_NAME,
		"url": url,
		"transport": transport,
		"lfs": _lfs_check.button_pressed and not _lfs_check.disabled,
		"initialized": true,
		"last_check": Time.get_datetime_string_from_system(),
	}
	configured.emit(config)
	print("[MiniGit] 配置完成：", " / ".join(notes))
	hide()


func _write_if_missing(file_name: String, content: String) -> String:
	var path := project_dir.path_join(file_name)
	if FileAccess.file_exists(path):
		return file_name + " 已存在，未改动"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return file_name + " 写入失败"
	file.store_string(content)
	file.close()
	return file_name + " 已写入"


func _exit_tree() -> void:
	if _probe_thread != null and _probe_thread.is_started():
		_probe_thread.wait_to_finish()
		_probe_thread = null

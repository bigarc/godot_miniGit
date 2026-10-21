class_name MiniGitRunner
extends RefCounted
## 对系统 git 的一层薄封装：拼参数、跑命令、翻译报错。
## OS.execute 是同步阻塞的，调用方负责把它放到线程里（如果可能卡住）。

const GIT := "git"

## 项目根目录，结尾带斜杠，来自 ProjectSettings.globalize_path("res://")
var project_dir := ""


func _init(dir: String = "") -> void:
	project_dir = dir


## 跑一条原始 git 命令。env 里的变量只在本次调用期间生效，结束后恢复。
func run(args: PackedStringArray, env: Dictionary = {}) -> Dictionary:
	var saved := {}
	for key in env.keys():
		saved[key] = OS.get_environment(key)
		OS.set_environment(key, str(env[key]))

	var output: Array = []
	var code := OS.execute(GIT, args, output, true)

	for key in saved.keys():
		OS.set_environment(key, saved[key])

	var text := "".join(output)
	return {"code": code, "text": text, "hint": _hint(code, text)}


## 在项目目录里跑 git（自动补 -C）。
func git(args: PackedStringArray, env: Dictionary = {}) -> Dictionary:
	var full := PackedStringArray(["-C", project_dir])
	full.append_array(args)
	return run(full, env)


## 只读探测网络，不改变仓库。BatchMode 让它不会停在输入密码上。
func probe_remote(url: String, transport: String) -> Dictionary:
	var env := {"GIT_TERMINAL_PROMPT": "0"}
	if transport == "ssh":
		env["GIT_SSH_COMMAND"] = "ssh -o BatchMode=yes -o ConnectTimeout=8"
	return run(PackedStringArray(["ls-remote", "--heads", url]), env)


func _hint(code: int, text: String) -> String:
	if code == -1:
		return MiniGitI18n.t("HINT_NO_GIT")
	var lower := text.to_lower()
	if lower.contains("permission denied (publickey"):
		return MiniGitI18n.t("HINT_PUBKEY")
	if lower.contains("could not resolve host"):
		return MiniGitI18n.t("HINT_DNS")
	if lower.contains("authentication failed"):
		return MiniGitI18n.t("HINT_AUTH")
	if lower.contains("repository not found"):
		return MiniGitI18n.t("HINT_REPO_NOT_FOUND")
	if lower.contains("not a git repository"):
		return MiniGitI18n.t("HINT_NOT_REPO")
	if lower.contains("nothing to commit"):
		return MiniGitI18n.t("HINT_NOTHING_TO_COMMIT")
	if lower.contains("no upstream"):
		return MiniGitI18n.t("HINT_NO_UPSTREAM")
	if code != 0:
		return MiniGitI18n.t("HINT_GENERIC")
	return ""

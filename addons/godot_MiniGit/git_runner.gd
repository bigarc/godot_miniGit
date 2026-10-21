class_name MiniGitRunner
extends RefCounted
## 对系统 git 的一层薄封装：拼参数、跑命令、把英文报错翻译成下一步动作。
##
## 为什么不是 libgit2：libgit2 不执行 git 的 clean/smudge 过滤器，
## LFS 仓库用它提交会把二进制直接塞进 git 对象。调系统 git 则和命令行完全一致。
##
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
		return "找不到 git 可执行文件：先安装 Git for Windows，确认它在 PATH 里"
	var lower := text.to_lower()
	if lower.contains("permission denied (publickey"):
		return "GitHub 不认这把密钥：把公钥加到 GitHub，或确认 ssh-agent 里已加载"
	if lower.contains("could not resolve host"):
		return "域名解析失败：检查网络或代理设置"
	if lower.contains("authentication failed"):
		return "HTTPS 凭据失效：让 Git Credential Manager 重新登录一次"
	if lower.contains("repository not found"):
		return "仓库不存在或没有权限：核对地址、组织权限、密钥是否属于有权限的账号"
	if lower.contains("not a git repository"):
		return "当前目录还不是 git 仓库：先初始化"
	if lower.contains("nothing to commit"):
		return "没有需要提交的改动"
	if lower.contains("no upstream"):
		return "当前分支还没有上游：第一次推送会自动设置"
	if code != 0:
		return "命令失败，看下面的原始输出"
	return ""

class_name MiniGitEnv
extends RefCounted
## 本机环境检测：git、git-lfs、是否仓库、远端、SSH 密钥、忽略文件。

const KEY_NAMES := ["id_ed25519", "id_rsa", "id_ecdsa"]


static func home_dir() -> String:
	var home := OS.get_environment("USERPROFILE")
	if home.is_empty():
		home = OS.get_environment("HOME")
	return home


static func ssh_dir() -> String:
	var home := home_dir()
	if home.is_empty():
		return ""
	return home.path_join(".ssh")


## 返回找到的私钥绝对路径（不含 .pub），按优先级排列。
static func find_ssh_keys() -> PackedStringArray:
	var found := PackedStringArray()
	var dir := ssh_dir()
	if dir.is_empty():
		return found
	for name in KEY_NAMES:
		var path := dir.path_join(name)
		if FileAccess.file_exists(path):
			found.append(path)
	return found


static func git_version(runner: MiniGitRunner) -> Dictionary:
	return runner.run(PackedStringArray(["--version"]))


static func lfs_version(runner: MiniGitRunner) -> Dictionary:
	return runner.run(PackedStringArray(["lfs", "version"]))


static func is_repo(runner: MiniGitRunner) -> bool:
	var result := runner.git(PackedStringArray(["rev-parse", "--is-inside-work-tree"]))
	return result["code"] == 0 and String(result["text"]).strip_edges() == "true"


static func remote_url(runner: MiniGitRunner, remote_name := "origin") -> String:
	var result := runner.git(PackedStringArray(["remote", "get-url", remote_name]))
	if result["code"] != 0:
		return ""
	return String(result["text"]).strip_edges()

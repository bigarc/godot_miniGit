class_name MiniGitConfig
extends RefCounted
## 读写 `<项目>/.git/minigit.cfg`。
## 放 .git 里：跟着仓库走、天然不被提交、换项目互不影响。
## 不保存任何凭据：SSH 交给 ssh-agent，HTTPS 交给 Git Credential Manager。

const FILE_NAME := "minigit.cfg"


static func path_for(project_dir: String) -> String:
	return project_dir.path_join(".git").path_join(FILE_NAME)


static func exists(project_dir: String) -> bool:
	return FileAccess.file_exists(path_for(project_dir))


static func load_config(project_dir: String) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path_for(project_dir)) != OK:
		return {}
	return {
		"remote_name": cfg.get_value("remote", "name", "origin"),
		"url": cfg.get_value("remote", "url", ""),
		"transport": cfg.get_value("remote", "transport", "ssh"),
		"lfs": cfg.get_value("lfs", "enabled", false),
		"initialized": cfg.get_value("state", "initialized", false),
		"last_check": cfg.get_value("state", "last_check", ""),
	}


static func save_config(project_dir: String, data: Dictionary) -> Error:
	var path := path_for(project_dir)
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		return ERR_FILE_NOT_FOUND
	var cfg := ConfigFile.new()
	cfg.set_value("remote", "name", data.get("remote_name", "origin"))
	cfg.set_value("remote", "url", data.get("url", ""))
	cfg.set_value("remote", "transport", data.get("transport", "ssh"))
	cfg.set_value("lfs", "enabled", bool(data.get("lfs", false)))
	cfg.set_value("state", "initialized", bool(data.get("initialized", true)))
	cfg.set_value("state", "last_check", data.get("last_check", ""))
	return cfg.save(path)

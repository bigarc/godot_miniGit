@tool
class_name MiniGitI18n
extends RefCounted
## 插件界面的轻量多语言表：跟随 Godot 编辑器自己的界面语言自动切换。
##
## 为什么不用 CSV + .translation：那套依赖编辑器的资源导入管线，插件刚被拷进
## 一个工程、还没被扫描导入时，load() 会失败并退回原文；字典跟脚本走，
## 不管工程处于什么状态都能立刻取到文案。
##
## 当前支持英文（默认兜底）和简体中文。新增语言只需要：
## 1. 加一个 const 字典；2. 在 _table_for() 里映射 locale；
## 3. 补齐所有键（缺键会退回英文）。

const FALLBACK := "en"
const ZH_CN := "zh_CN"

## 键名按界面区域分组：工具栏、菜单、窗口、配置窗口、git 报错。
const EN := {
	# 工具栏与菜单
	"TOOLBAR_TIP": "Commit, push and pull with system Git. Git LFS works as usual.",
	"BTN_GIT": "Git",
	"BTN_GIT_UNCONFIGURED": "Git (not configured)",
	"MENU_COMMIT_PUSH": "Commit and Push…",
	"MENU_PUSH_ONLY": "Push Only",
	"MENU_PULL": "Pull (--ff-only)",
	"MENU_STATUS": "Show Status",
	"MENU_CONFIGURE": "Configure…",
	"MENU_RECONFIGURE": "Reconfigure…",
	# 提交窗口与输出窗口
	"COMMIT_DIALOG_TITLE": "Commit and Push",
	"COMMIT_OK": "Commit and Push",
	"COMMIT_PLACEHOLDER": "Commit message, e.g. feat(chess): piece movement",
	"OUTPUT_TITLE": "Git Output",
	"CLOSE": "Close",
	"CANCEL": "Cancel",
	"OK": "OK",
	# 运行结果
	"SAVE_CONFIG_FAILED_TITLE": "Failed to Save Configuration",
	"SAVE_CONFIG_FAILED_TEXT": "Cannot write .git/minigit.cfg (error code %d).",
	"COMMIT_MESSAGE_TITLE": "Commit Message",
	"COMMIT_MESSAGE_EMPTY": "The commit message cannot be empty. Cancelled.",
	"GIT_ADD_FAILED": "Failed: git add",
	"GIT_COMMIT_FAILED": "Failed: git commit",
	"GIT_PUSH_FAILED": "Failed: git push",
	"GIT_PULL_FAILED": "Failed: git pull",
	"NOTHING_TO_COMMIT": "Nothing to commit.",
	"DONE": "Done.",
	"PUSH_TITLE": "Push",
	"PULL_TITLE": "Pull",
	# 后台任务
	"BUSY_COMMIT": "Git (committing…)",
	"BUSY_PUSH": "Git (pushing…)",
	"BUSY_PULL": "Git (pulling…)",
	"BUSY_STATUS": "Git (reading status…)",
	"THREAD_FAILED_TITLE": "Cannot Start Background Task",
	"THREAD_FAILED_TEXT": "Failed to start the background thread (error code %d).",
	# 配置窗口：环境与仓库
	"SETUP_TITLE": "Git Setup",
	"SEC_ENV": "1. Environment",
	"ENV_GIT_OK": "✓ git",
	"ENV_GIT_MISSING": "✗ git not found",
	"ENV_GIT_HINT": "Install Git for Windows and make sure it is on PATH.",
	"ENV_LFS_OK": "✓ git-lfs",
	"ENV_LFS_MISSING": "! git-lfs not found",
	"ENV_LFS_HINT": "Large files cannot use LFS yet. You can still continue.",
	"RECHECK": "Check Again",
	"SEC_REPO": "2. Git Repository",
	"REPO_OK": "Already a Git repository ✓",
	"REPO_NONE": "Not managed by Git yet",
	"INIT_BUTTON": "Initialize Git repository (git init -b main)",
	"INIT_DIALOG_TITLE": "Initialize Repository",
	"INIT_DIALOG_TEXT": "This project is not managed by Git yet.\n\nWill run: git init -b main\n(local repository only, no remote)",
	"INIT_FAILED": "[color=red]Initialization failed[/color]\n",
	# 配置窗口：远端与传输
	"SEC_REMOTE": "3. Remote and Transport",
	"URL_PLACEHOLDER": "git@github.com:user/repo.git or https://github.com/user/repo.git",
	"TRANSPORT_SSH": "SSH (use local keys)",
	"TRANSPORT_HTTPS": "HTTPS (via Git Credential Manager)",
	"KEY_NONE": "No SSH key found on this machine",
	"KEY_FOUND": "Found keys:",
	"GEN_KEY": "Generate New ED25519 Key",
	"COPY_PUBKEY": "Copy Public Key",
	"GITHUB_KEYS": "Open GitHub → Settings → SSH and GPG keys",
	"NO_HOME": "Home directory not found; cannot generate a key.",
	"GEN_KEY_FAILED": "Generation failed. Check that OpenSSH is on PATH.\n",
	"KEY_GENERATED": "Key generated. Add the public key below to GitHub, then test the connection.",
	"PUBKEY_COPIED": "Public key copied to clipboard.",
	# 配置窗口：忽略文件与 LFS
	"SEC_IGNORE": "4. Ignore Files and LFS",
	"CHECK_GITIGNORE": ".gitignore (write Godot defaults if missing)",
	"CHECK_GITATTRIBUTES": ".gitattributes (write line-ending and LFS rules if missing)",
	"CHECK_LFS": "Enable Git LFS (git lfs install --local)",
	"LFS_OK": "git lfs install: succeeded",
	"LFS_FAIL": "git lfs install: failed",
	"FILE_EXISTS": "%s already exists; left unchanged",
	"FILE_WRITTEN": "%s written",
	"FILE_WRITE_FAILED": "Failed to write %s",
	# 配置窗口：连通性
	"SEC_CONN": "5. Connectivity to GitHub",
	"TEST_CONNECTION": "Test Connection",
	"SAVE_AND_ENABLE": "Save and Enable",
	"TRANSPORT_CHANGED": "Transport changed. Test the connection again.",
	"ENTER_URL": "[color=orange]Enter the repository URL first[/color]",
	"CONNECTING": "Connecting, up to 8 seconds…",
	"CONN_OK": "[color=green]Connected[/color]. %d remote branches readable.",
	"CONN_FAILED": "[color=red]Connection failed[/color] ",
	"NEED_REPO": "[color=red]Initialize the Git repository first[/color]",
	"NEED_URL": "[color=red]The repository URL cannot be empty[/color]",
	"NEED_TEST": "[color=red]Test the connection successfully before saving[/color]",
	"REMOTE_WRITE_FAILED": "[color=red]Failed to write remote[/color]\n",
	# git 报错到下一步动作的映射
	"HINT_NO_GIT": "git executable not found. Install Git for Windows and make sure it is on PATH.",
	"HINT_PUBKEY": "GitHub does not accept this key. Add the public key to GitHub, or check that ssh-agent has it loaded.",
	"HINT_DNS": "Cannot resolve the host. Check your network or proxy settings.",
	"HINT_AUTH": "HTTPS credentials expired. Let Git Credential Manager sign in again.",
	"HINT_REPO_NOT_FOUND": "Repository not found or access denied. Check the URL, the organization permissions, and which account the key belongs to.",
	"HINT_NOT_REPO": "This directory is not a Git repository yet. Initialize it first.",
	"HINT_NOTHING_TO_COMMIT": "Nothing to commit.",
	"HINT_NO_UPSTREAM": "The current branch has no upstream. The first push will set it automatically.",
	"HINT_GENERIC": "The command failed. See the raw output below.",
}

const ZH := {
	# 工具栏与菜单
	"TOOLBAR_TIP": "提交、推送、拉取（调用系统 git，Git LFS 正常）",
	"BTN_GIT": "Git",
	"BTN_GIT_UNCONFIGURED": "Git（未配置）",
	"MENU_COMMIT_PUSH": "提交并推送…",
	"MENU_PUSH_ONLY": "仅推送",
	"MENU_PULL": "拉取（--ff-only）",
	"MENU_STATUS": "查看状态",
	"MENU_CONFIGURE": "配置…",
	"MENU_RECONFIGURE": "重新配置…",
	# 提交窗口与输出窗口
	"COMMIT_DIALOG_TITLE": "提交并推送",
	"COMMIT_OK": "提交并推送",
	"COMMIT_PLACEHOLDER": "提交说明，例如 feat(chess): 棋子移动",
	"OUTPUT_TITLE": "Git 输出",
	"CLOSE": "关闭",
	"CANCEL": "取消",
	"OK": "确定",
	# 运行结果
	"SAVE_CONFIG_FAILED_TITLE": "保存配置失败",
	"SAVE_CONFIG_FAILED_TEXT": "无法写入 .git/minigit.cfg（错误码 %d）",
	"COMMIT_MESSAGE_TITLE": "提交说明",
	"COMMIT_MESSAGE_EMPTY": "提交说明不能为空，已取消。",
	"GIT_ADD_FAILED": "失败：git add",
	"GIT_COMMIT_FAILED": "失败：git commit",
	"GIT_PUSH_FAILED": "失败：git push",
	"GIT_PULL_FAILED": "失败：git pull",
	"NOTHING_TO_COMMIT": "没有需要提交的改动。",
	"DONE": "完成。",
	"PUSH_TITLE": "推送",
	"PULL_TITLE": "拉取",
	# 后台任务
	"BUSY_COMMIT": "Git（提交中…）",
	"BUSY_PUSH": "Git（推送中…）",
	"BUSY_PULL": "Git（拉取中…）",
	"BUSY_STATUS": "Git（读取状态…）",
	"THREAD_FAILED_TITLE": "无法启动后台任务",
	"THREAD_FAILED_TEXT": "后台线程启动失败（错误码 %d）。",
	# 配置窗口：环境与仓库
	"SETUP_TITLE": "Git 配置",
	"SEC_ENV": "1. 环境检测",
	"ENV_GIT_OK": "✓ git",
	"ENV_GIT_MISSING": "✗ 没有找到 git",
	"ENV_GIT_HINT": "先安装 Git for Windows，并确认在 PATH 里",
	"ENV_LFS_OK": "✓ git-lfs",
	"ENV_LFS_MISSING": "! 没有找到 git-lfs",
	"ENV_LFS_HINT": "大文件先无法用 LFS，仍可继续",
	"RECHECK": "重新检测",
	"SEC_REPO": "2. git 仓库",
	"REPO_OK": "已经是 git 仓库 ✓",
	"REPO_NONE": "还没有被 git 管理",
	"INIT_BUTTON": "初始化 git 仓库（git init -b main）",
	"INIT_DIALOG_TITLE": "初始化仓库",
	"INIT_DIALOG_TEXT": "当前项目还没有被 git 管理。\n\n将执行：git init -b main\n（只建本地仓库，不连远端）",
	"INIT_FAILED": "[color=red]初始化失败[/color]\n",
	# 配置窗口：远端与传输
	"SEC_REMOTE": "3. 远端与传输方式",
	"URL_PLACEHOLDER": "git@github.com:用户/仓库.git 或 https://github.com/用户/仓库.git",
	"TRANSPORT_SSH": "SSH（使用本机密钥）",
	"TRANSPORT_HTTPS": "HTTPS（交给 Git Credential Manager）",
	"KEY_NONE": "本机没有找到 SSH 密钥",
	"KEY_FOUND": "找到密钥：",
	"GEN_KEY": "生成新的 ED25519 密钥",
	"COPY_PUBKEY": "复制公钥",
	"GITHUB_KEYS": "打开 GitHub → Settings → SSH and GPG keys",
	"NO_HOME": "找不到用户主目录，无法生成密钥",
	"GEN_KEY_FAILED": "生成失败，检查 OpenSSH 是否在 PATH 里。\n",
	"KEY_GENERATED": "已生成密钥，把下面的公钥加到 GitHub 后再测试连接。",
	"PUBKEY_COPIED": "公钥已复制到剪贴板。",
	# 配置窗口：忽略文件与 LFS
	"SEC_IGNORE": "4. 忽略文件与 LFS",
	"CHECK_GITIGNORE": ".gitignore（缺失时写入 Godot 推荐项）",
	"CHECK_GITATTRIBUTES": ".gitattributes（缺失时写入换行规则 + LFS 规则）",
	"CHECK_LFS": "启用 Git LFS（git lfs install --local）",
	"LFS_OK": "git lfs install：成功",
	"LFS_FAIL": "git lfs install 失败",
	"FILE_EXISTS": "%s 已存在，未改动",
	"FILE_WRITTEN": "%s 已写入",
	"FILE_WRITE_FAILED": "%s 写入失败",
	# 配置窗口：连通性
	"SEC_CONN": "5. 与 GitHub 的连通性",
	"TEST_CONNECTION": "测试连接",
	"SAVE_AND_ENABLE": "保存并启用",
	"TRANSPORT_CHANGED": "传输方式改了，需要重新测试连接。",
	"ENTER_URL": "[color=orange]先填仓库地址[/color]",
	"CONNECTING": "正在连接，最多等 8 秒…",
	"CONN_OK": "[color=green]连接成功[/color]，远端有 %d 个分支可读。",
	"CONN_FAILED": "[color=red]连接失败[/color] ",
	"NEED_REPO": "[color=red]先初始化 git 仓库[/color]",
	"NEED_URL": "[color=red]仓库地址不能为空[/color]",
	"NEED_TEST": "[color=red]先测试连接，成功了再保存[/color]",
	"REMOTE_WRITE_FAILED": "[color=red]写远端失败[/color]\n",
	# git 报错到下一步动作的映射
	"HINT_NO_GIT": "找不到 git 可执行文件：先安装 Git for Windows，确认它在 PATH 里",
	"HINT_PUBKEY": "GitHub 不认这把密钥：把公钥加到 GitHub，或确认 ssh-agent 里已加载",
	"HINT_DNS": "域名解析失败：检查网络或代理设置",
	"HINT_AUTH": "HTTPS 凭据失效：让 Git Credential Manager 重新登录一次",
	"HINT_REPO_NOT_FOUND": "仓库不存在或没有权限：核对地址、组织权限、密钥是否属于有权限的账号",
	"HINT_NOT_REPO": "当前目录还不是 git 仓库：先初始化",
	"HINT_NOTHING_TO_COMMIT": "没有需要提交的改动",
	"HINT_NO_UPSTREAM": "当前分支还没有上游：第一次推送会自动设置",
	"HINT_GENERIC": "命令失败，看下面的原始输出",
}


## 当前应使用的语言。编辑器里取编辑器界面语言（不是工程语言）；
## 导出后的游戏里 get_tool_locale() 无效，退回系统语言。
static func current_locale() -> String:
	var locale := ""
	if Engine.is_editor_hint():
		locale = TranslationServer.get_tool_locale()
	if locale.is_empty():
		locale = TranslationServer.get_locale()
	if locale.is_empty():
		locale = OS.get_locale()
	if locale.to_lower().begins_with("zh"):
		return ZH_CN
	return FALLBACK


## 取一条文案；args 用于 %s/%d 占位符。缺键时退回英文，再退回键名本身，
## 这样漏翻不会让界面出现空白。
static func t(key: String, args: Array = []) -> String:
	var table := _table_for(current_locale())
	var text: String = table.get(key, EN.get(key, key))
	if not args.is_empty():
		text = text % args
	return text


## 只检查当前语言有没有这个键，给自检脚本用。
static func has(key: String) -> bool:
	return _table_for(current_locale()).has(key)


static func _table_for(locale: String) -> Dictionary:
	return ZH if locale == ZH_CN else EN

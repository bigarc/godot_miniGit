# MiniGit

A minimal Git toolbar for the Godot 4 editor. It drives **system Git**, so Git
LFS hooks, SSH agents and credential helpers behave exactly as they do in a
terminal.

![MiniGit toolbar](https://raw.githubusercontent.com/bigarc/godot_MiniGit/main/other/show_6.png)

## Install

- **Asset Library:** open the AssetLib tab, search for **MiniGit**, install,
  then enable it in **Project → Project Settings → Plugins**.
- **Manual:** copy `addons/godot_MiniGit/` into your project's `addons/` folder
  (keep the `.uid` files), then enable the plugin.

On first enable the plugin opens a setup window: environment check, `git init`,
remote and SSH key, `.gitignore` / `.gitattributes` / Git LFS, and a
connectivity test. The settings are written to `.git/minigit.cfg`, which is
never committed.

## Use

The toolbar button **Git** offers commit and push, push only, pull
(`--ff-only`), status, and reconfigure.

- No credentials are stored. SSH goes through ssh-agent; HTTPS goes through
  Git Credential Manager.
- Every command that changes the repository asks for confirmation first.
- Every action prints the exact Git command it ran, and the raw output is kept.
- Git runs in a background thread, so the editor stays responsive; the toolbar
  shows which operation is running, and the result window scrolls.

Requires Godot 4.x and Git 2.23 or newer. Git LFS is optional.

The UI language follows the editor language (English and Simplified Chinese).

## License

MIT. See `LICENSE` in this folder.

---

# MiniGit（中文）

Godot 4 编辑器里的一组极简 Git 工具栏按钮。直接调用**系统 git**，Git LFS、
ssh-agent、凭据管理器都按终端里的行为工作。

## 安装

- **资产商店**：在编辑器的 AssetLib 里搜索 **MiniGit**，安装后到
  **项目 → 项目设置 → 插件** 里启用。
- **手动**：把 `addons/godot_MiniGit/` 整个拷进工程的 `addons/` 下
  （`.uid` 文件一起带上），再到插件里启用。

首次启用会打开配置窗口：环境检测、`git init`、远端与 SSH 密钥、
`.gitignore` / `.gitattributes` / Git LFS、连通性测试。配置写到
`.git/minigit.cfg`，不会被提交。

## 使用

工具栏 **Git** 按钮里提供提交并推送、仅推送、拉取（`--ff-only`）、
查看状态、重新配置。

- 不保存任何凭据；SSH 交给 ssh-agent，HTTPS 交给 Git Credential Manager。
- 会改变仓库状态的命令都先弹确认。
- 每条动作都打印实际执行的 git 命令，原始输出保留。
- git 在后台线程里跑，编辑器不会卡住；工具栏会显示当前在做什么，结果窗口可以滚动。

需要 Godot 4.x 和 Git 2.23 以上；Git LFS 可选。

界面语言跟随编辑器语言（英文、简体中文）。

## 许可

MIT，见同目录的 `LICENSE`。

class_name MiniGitTemplates
extends RefCounted
## 向导里“使用 Godot 推荐配置”时写入的默认内容。
## 只在新项目缺文件时写入；已有文件一律不动，避免覆盖用户自己的规则。

const GITIGNORE := """# Godot 4+ 专用忽略
.godot/
/android/
*.translation

# 导出产物
/build/
/export/
/export_*/
*.pck

# 编辑器与系统垃圾
.vscode/
.idea/
Thumbs.db
.DS_Store
*.tmp
*.bak
"""

const GITATTRIBUTES := """# 文本文件统一 LF
* text=auto eol=lf

# 图片
*.png filter=lfs diff=lfs merge=lfs -text
*.jpg filter=lfs diff=lfs merge=lfs -text
*.jpeg filter=lfs diff=lfs merge=lfs -text
*.webp filter=lfs diff=lfs merge=lfs -text
*.tga filter=lfs diff=lfs merge=lfs -text
*.bmp filter=lfs diff=lfs merge=lfs -text
*.exr filter=lfs diff=lfs merge=lfs -text
*.hdr filter=lfs diff=lfs merge=lfs -text
*.dds filter=lfs diff=lfs merge=lfs -text

# 音频
*.wav filter=lfs diff=lfs merge=lfs -text
*.ogg filter=lfs diff=lfs merge=lfs -text
*.mp3 filter=lfs diff=lfs merge=lfs -text

# 3D
*.fbx filter=lfs diff=lfs merge=lfs -text
*.gltf filter=lfs diff=lfs merge=lfs -text
*.glb filter=lfs diff=lfs merge=lfs -text
*.blend filter=lfs diff=lfs merge=lfs -text
*.obj filter=lfs diff=lfs merge=lfs -text

# 字体与视频
*.ttf filter=lfs diff=lfs merge=lfs -text
*.otf filter=lfs diff=lfs merge=lfs -text
*.mp4 filter=lfs diff=lfs merge=lfs -text
*.webm filter=lfs diff=lfs merge=lfs -text
"""

# Monorepo 维护约定

## 依赖方向

`games/<Game>/game.json` 声明使用哪些包，`workspace.json` 定义包的唯一源目录及 Godot 内的挂载位置。当前 `mobile-core` 版本 0.1.0，支持 Godot 4.5.1。仓库使用同一提交里的包版本，不需要独立发布或网络下载。

Godot 的 `res://` 从游戏的 `project.godot` 所在目录开始。共享包通过 Python 标准库同步进去，避免不同系统的符号链接及导出问题。生成副本不提交 Git；`.mobile_core.sync.json` 保存上次同步的文件摘要，发现人工修改会中止并指出维护源。`check` 只检查，不写文件。

`mobile-core` 管通用持久化、交易与奖励去重、provider 生命周期、通知请求、池化 VFX/音效、触控和按钮布局。角色、价格、关卡、升级、Boss、成就及欢迎金币留在游戏里。共享包不能引用 `Rush*` 类型、`res://game/` 或游戏素材。

## 新游戏

1. 从 repo 根目录运行 `python3 tools/workspace.py new SpaceDash`。
2. `python3 tools/workspace.py run SpaceDash` 验证存档、模拟广告与购买示例。
3. 修改该游戏的主场景、名称、图标，配置自己的产品、广告位置与 App ID。
4. 添加游戏测试到 `games/SpaceDash/tests/*tests.gd`，通过 `workspace.py test SpaceDash` 运行。
5. 创建该游戏自己的 `export_presets.cfg` 和 `tools/export_playtest.py`，输出到 `builds/SpaceDash`。RingRush 的导出工具是参考实现，不能直接沿用它的商店标识符。

每个新游戏应设置独立 `config/name` 或自定义 user data directory，防止存档冲突。本次移动保持 RingRush 的应用名称、存档结构及 `res://` 路径，因此已有存档不需要因目录迁移而重置。

## 验证与维护

改包：`sync` → Python 工具测试 → `test-core` → 所有受影响游戏的测试。改游戏只需运行相关游戏测试；原生画面使用 `--native` 验证。`test-core` 在忽略提交的 `builds/core-test` 创建完全独立的小项目，不加载 RingRush。

工作区命令在运行游戏前完成一次 headless import，确保全新 clone 的 Godot global class cache 可用。CI 按相同命令安装固定版本 Godot 后运行即可，不提交 `.godot` 或同步副本。

游戏素材、导出预设、商店标识符和教程按游戏归属维护；跨游戏教程留在根 `docs`。不要为尚未出现的复用场景增加新包。若以后多个游戏确实共用联网、分析或活动逻辑，再独立提取对应包。

## 迁移验证（2026-09-06）

移动后先完成独立核心 18 项、游戏 790 项 headless 检查及 Web/Mac 双导出，再开始 Boss 功能。Python 工作区工具另有 4 个测试，覆盖首次同步、更新/删除文件、拒绝覆盖人工修改、只读检查和目录保护。Godot 原生渲染补充 3 项检查。

旧根目录的 `.godot` 被移除，游戏从新路径重新导入；包通过生成副本导出，未依赖跨项目符号链接。`config/name` 和游戏内 `res://` 路径保持一致。

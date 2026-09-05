# Game Workshop

Godot 4.5.1 游戏 monorepo。每个游戏独立运行、存档和导出，共享核心只有一份维护源。

```text
games/
  RingRush/                 # 游戏代码、场景、素材、测试及游戏设计
packages/
  mobile-core/
    addon/                  # 存档、钱包、广告/IAP、通知、VFX、音效、触控、UI 布局
    tests/                  # 不加载任何游戏的核心测试
templates/core_starter/     # 新游戏的最小示例
tools/workspace.py          # 同步、运行、测试、导出、新游戏
docs/tutorials/             # 环境、广告、平台构建与部署教程
builds/<GameName>/          # 生成产物，不提交 Git
```

## 开始开发

安装 **Godot 4.5.1 标准版**、匹配版本的 export templates 和 Python 3.9+。以下命令都在 repo 根目录运行。如果命令行找不到 `godot`，设置 `GODOT_BIN` 为可执行文件路径，或在命令前加 `--godot /path/to/Godot`。

```sh
python3 tools/workspace.py sync
python3 tools/workspace.py editor RingRush
python3 tools/workspace.py run RingRush
```

macOS 也可以双击根目录 `run.command`。Godot 项目在 `games/RingRush/project.godot`，根目录本身不是 Godot 项目。

## 日常命令

```sh
python3 tools/workspace.py list
python3 tools/workspace.py check
python3 -m unittest discover -s tools/tests
python3 tools/workspace.py test-core
python3 tools/workspace.py test RingRush
python3 tools/workspace.py test RingRush --suite quality_tests --native
python3 tools/workspace.py build RingRush
python3 tools/workspace.py new SpaceDash
```

`new SpaceDash` 创建 `games/SpaceDash`，自带共享核心和独立存档，不复制 RingRush 模型或规则。导出到 repo 外的独立项目可以使用 `python3 tools/create_game.py /path/to/NewGame --name 'New Game'`。

改共享功能时，编辑 **`packages/mobile-core/addon`**，然后执行 `sync`。各游戏的 `addons/mobile_core` 是忽略提交的生成副本。同步会拒绝覆盖副本中的手动修改，避免丢失工作。`run`、`editor`、`test`、`build` 会自动同步并导入；直接打开 Godot 前需先执行 `sync`。无需 npm、符号链接或额外 monorepo 框架。

- [架构与新增游戏约定](docs/monorepo.md)
- [环境、APK/AAB、macOS 与 iOS 构建](docs/tutorials/builds.md)
- [广告、购买与通知接入](docs/tutorials/monetization.md)
- [网页试玩与部署](docs/tutorials/deployment.md)
- [共享核心接口](packages/mobile-core/README.md)
- [RingRush 游戏说明](games/RingRush/README.md)
- [素材与清理规则](docs/assets.md)

Android/iOS 已有导出预设；原生广告、支付及系统通知 adapter 尚未接入。网页和 Mac 试玩使用明确标示的模拟购买，不会收取费用。

# RingRush

面向 Android、iOS、Web 和 macOS 的 Godot 4.5.1 3D 生存拳击游戏。

这是 monorepo 中的独立游戏。**所有 workspace 命令从 repo 根目录运行**：

```sh
python3 tools/workspace.py run RingRush
python3 tools/workspace.py test RingRush
python3 tools/workspace.py build RingRush
```

Godot 直接打开 `project.godot` 前，先在 repo 根目录执行 `python3 tools/workspace.py sync RingRush`。共享 `addons/mobile_core` 是生成副本，改通用逻辑请编辑根目录 `packages/mobile-core/addon`。

## 游戏内容

- 6 位人类拳手和 3 位高级人形机甲；金币解锁、不同属性与招式。
- 8 种技能，各 10 级；GYM 8 项训练，各 30 级；Bronze 至 Master 排名。
- 42 个三阶段成就徽章与小幅永久加成；可选 Hard Contract 增加风险与奖励。
- Quick Fight、Survival 30、Onslaught 50、World Ladder、90-second Rush、Hell、Blitz、Boss Rush，以及另行开启的 Rift 隐藏模式。
- 骷髅模型仅作 Rift 敌人；不同场地、障碍、场景氛围与独立模式音乐。
- 普通模式加入无人机散射、史莱姆酸液、狼冲锋、幽灵追踪弹；机甲自动使用机关枪、飞弹或喷火。
- 免费 Air Jab 与金币解锁 Nova Orb；可升级伤害、范围和颜色。
- 共享核心提供实时碎石、尘浪、发光裂纹、光焰和冲击波，并有低画质档。
- Boss 半血二阶段、金色技能破招窗口、精准闪避后的 2.5 倍反击。
- 暂停、恢复存档、模拟广告复活/额外奖励、模拟金币购买和 Remove Ads。

移动：WASD/方向键或左侧触控摇杆。自动近身拳击，机甲在射程内自动使用专属武器。Space 闪避，Q 技能，E 终极技；触屏使用右侧圆形按钮。

## 文件

`game/` 游戏规则与 UI；`scenes/` 入口；`assets/` 正式素材及许可；`tests/` 自动测试/截图；`tools/` 素材生成与本游戏导出；`docs/` 设计及验证记录。

[共享核心与架构](../../docs/monorepo.md) · [平台构建](../../docs/tutorials/builds.md) · [广告接入](../../docs/tutorials/monetization.md) · [部署](../../docs/tutorials/deployment.md) · [成长设计](docs/growth-design.md) · [模型许可](assets/fighters/CREDITS.md)

旧验证文档记录当时版本和路径，截图已清理，可用 `tests/*capture.gd` 重建。试玩的商店交易是模拟行为；原生 SDK 和正式签名仍需单独配置。

## 0.7.0 — long-term progression

Four CC0 creature enemies, six conditional companions in air/ground equipment slots, five ranged run upgrades, 42 three-stage badges, smaller permanent stat increments and distinct fighter ultimates. Walking attacks use filtered upper-body animation. See [design and balance](docs/longevity.md), [playtest instructions](docs/playtest.md) and [production readiness](../../docs/tutorials/production.md). Settings includes build version, ZX Labs support, local playtest privacy notice and full Credits.

## 0.8.0 — worlds and loadout

Companions and Badges now sit beside the home progression controls. Equipped companions remain visible while browsing. Wildwood, Hollow Graveyard and Orbital Station introduce venue-specific enemy families and matching champion appearances. New World Ladder runs cover eight venues / 40 waves; old saves remain resumable. See [worlds and loadout design](docs/worlds-and-loadout.md).

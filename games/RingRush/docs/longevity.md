# RingRush 0.7.0 — 长线成长、辅助与开放模型

## 战斗与永久成长

GYM 8 项仍各 30 级，已购买等级、角色、金币和已获得徽章保留。速度每级 +基础值 0.5%，总上限 +15%；力量每级 +0.8%，总 +24%；生命每级 +1.2%，总 +36%。蓄能起点 25%→40%，Q 冷却最多减少 10.5%，永久减伤最多 6%，过波回复最多 3.6% HP，金币加成最多 15%。显示数值和战斗取值共用 `RushTraining.value`。

敌人随整体永久成长、技能等级及高阶角色增强：常规成长压力上限为 HP +55%、伤害 +30%、速度 +6%；可选 Hard Contract 另加 HP 30%、伤害 20%。普通敌人第 9 波起增加每波 2.8% 的额外生命系数。Boss 保留各波生命曲线、二阶段和破招反击。该设计不是让永久升级完全抵消敌人，而是让成长保留优势，同时需要持续选择局内构筑。

进行中战斗的属性快照与辅助配置被冻结，不会因为购买升级、换装备或恢复存档而重新计算。通用战斗规则随版本更新。旧存档没有辅助/被动计时/大招状态时，按空配置恢复，不赠送新效果。

42 个徽章，每个 Bronze / Silver / Gold 三阶段，共 126 个目标。Silver 需要五胜与五次 Boss KO；Gold 需要十五胜、三十次 Boss KO、两场高难胜利（Hell、Boss Rush、Onslaught 50），且各自的阶段目标达到。收藏和技能满级目标不设不可达到的数值；之后的阶段由实战门槛控制。旧的 bool 徽章迁移至至少 Bronze。每阶段仅加 0.2 HP / 0.04 力量 / 0.04% 冷却中的一种；全部 Gold 总计 +8.4 HP、+1.68 力量、-1.68% 冷却。

## Q / E 与局内远程构筑

Q 为所装备的战术招式，保留独立冷却。E 使用满能量，清除当前敌方弹幕，独立于 Q：

| 角色 | E | 战术用途 |
| --- | --- | --- |
| Atlas / Titan / Raven | Faultbreaker | 6m 地震、3.5 倍基础伤害、4s 普攻 +35% |
| Zephyr / Volt / Sol | Skyfall | 3 秒内三次自动寻找目标的落雷，每次 1.9 倍伤害、2.5m 范围 |
| Aegis / Ion / Onyx | Siege Mode | 4s 机器人武器间隔 ×0.65、伤害 +20% |

E 不再把 Q 重放一遍，也不刷新 Q。消耗能量后靠 KO 与少量时间回复；大招增益的剩余时间保存。Q 仍是 Boss 金色窗口破招工具，E 不替代精确破招。

新增 Pulse Engine（定时直射）、Arctic Volley（三发减速冰弹）、Pocket Rockets（追踪爆炸）、Rebound Spark（直接命中后向另一目标弹射）、Distance Fighter（远距离伤害）。每项三阶。每次等级选择有可用远程卡时保证一张；距离增伤只在已有远程武器或被动时进入候选。弹射跳过原目标；被动弹、辅助弹、DOT 不递归触发直接命中被动，也不会白拿 Boss 反击窗口奖励。

## 六种辅助

| 辅助 | 槽 | 金币 | 触发 | 效果 / 限制 |
| --- | --- | ---: | --- | --- |
| Sky Scout | 空中 | 650 | 每 6 次直接命中 | 两枚 0.3×伤害弹，6s 冷却 |
| Medic Drone | 空中 | 1100 | HP <40% | 回 4% HP，上限 7；18s 冷却，每局 3 次 |
| Arc Bee | 空中 | 1600 | 施放 Q | 附近目标周围 2m 减速 1.4s；12s 冷却 |
| Trail Wolf | 地面 | 450 | 每 8 次直接命中 | 3m 内咬击，0.65×伤害；8s 冷却 |
| Swift Fox | 地面 | 900 | 闪避 | +8% 移速 2.5s；10s 冷却 |
| Rescue Shiba | 地面 | 1300 | HP <30% | 减伤 20% 持续 3s；20s 冷却，每局 3 次 |

一空中、一地面，不提供无限属性堆叠或辅助升级。买后需点 Equip；恢复中战斗不切换装配。触发条件、剩余次数、冷却、速度/护盾增益随存档恢复。两只辅助使用固定节点；共享池中共 96 发弹、最多 28 发敌弹，不为每发创建节点。

## 模型、动画与复现

四类敌人改用作者 Quaternius 发布的 CC0 模型：炮台无人机、尖刺史莱姆、狼、幽灵。另选飞行医疗机、狐狸、柴犬和甲蜂，合计只保留八个源模型的派生资源。每模型 1,848–4,888 三角形、54 个共享采样姿态，运行时每只一个 MeshInstance，避免给 48 只敌人同时运行骨骼动画。新增运行时资源与缩略图约 22 MiB；没有把整套下载素材放进仓库。

```sh
python3 games/RingRush/tools/fetch_open_models.py
# 原始下载进入 ignored builds/model-source，SHA-256 不符就停止。
godot --path games/RingRush --script res://tools/prepare_open_models.gd -- /ABSOLUTE/REPO/builds/model-source
godot --path games/RingRush --script res://tools/capture_companions.gd
```

模型来源和原始作者许可见 `assets/creatures/sources.json`、`assets/creatures/*-LICENSE.txt` 及 `assets/fighters/CREDITS.md`。游戏设置底部 Credits 提供来源与许可证。GLTF 在 native renderer 中离线烘焙，未改动用户 Downloads 里的模型。

玩家使用 AnimationTree 上下半身过滤：腰、腿、脚保留行走动画，拳击/受击只覆盖上身。移除了地震借用 Jump_Land 的空中落地姿态；Rising Dragon 仍保留其明确设计的短暂跃起。机甲武器和手臂保留机械动作。

## 验证

`longevity_tests.gd` 验证购买原子性、两槽限制、条件触发、治疗次数、存档防重复、被动弹命中、Q/E 区别、三次落雷、徽章迁移与分阶门槛、UI 尺寸，以及行走出拳时腿部动画仍推进且上身姿态发生变化。原有全套回归继续运行。

`longevity_capture.gd` 生成原生画面到 ignored `docs/longevity-preview/`；`longevity-performance.json` 为本机短时压力样本，48 敌人、Boss 二阶段、Onyx、两只辅助、五项远程被动和重叠技能。此项不代表 Android/iOS 真机帧率或长时间发热表现。

生产准备与尚未完成事项见仓库 `docs/tutorials/production.md`。

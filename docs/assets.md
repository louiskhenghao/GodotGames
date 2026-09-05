# 素材和生成文件

本次已删除未用于游戏的 `custom/` FBX 副本、纹理与失败 retarget 实验、未选用的 Ultimate Space Kit 整包、旧版 UI 截图、旧 Mac 解压副本和 Godot 缓存。用户 Downloads 中的模型原件没有改动。详细删除清单及字节数在 `cleanup-2026-09-06.json`。

保留运行所需的模型、纹理、烘焙 crowd pose、音乐、音效及 license。也保留可重新生成正式素材所需的少量源输入和制作脚本：人类模型/动画源、3 个选中机器人和 3 个 skeleton。原始 GLB 不进入发布包；`assets/fighters/source/.gdignore` 阻止源目录导入。

- 加新素材先确认许可，并更新 `games/RingRush/assets/fighters/CREDITS.md`。
- 成套下载先放临时目录，挑选后只把实际使用的源文件和最终资源放进游戏。
- 保留 `.gd.uid` 和需要的 `.import` 设置；不保留 `.godot/` 缓存。
- 截图和性能录制是可重建产物；输出目录被忽略。源码文档保留文字结果与必要数据。
- 构建统一放 `builds/<Game>/`，不要把 `.app`、PCK、ZIP 复制进 assets。
- 不重写 Git 历史；旧的大文件在历史中仍可能占空间。需要历史瘦身时应单独安排协作迁移。

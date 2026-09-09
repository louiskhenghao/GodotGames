# 从试玩到正式发布

当前 RingRush 为 **0.7.0 / build 7 朋友试玩版**，不是已通过商店审核的发行版。Web/Mac 导出不需要商店凭据，因此可先分享测试。Android/iOS 的工程结构保留，但原生支付/广告插件、签名和真机验收仍未完成。

## 发布身份与版本

`games/RingRush/config/release.json` 维护版本、build、ZX Labs 官网 `https://www.zxlabs.dev`、客服 `support@zxlabs.dev`。设置页显示版本，提供邮件入口、官网、复制设备摘要和 Credits。复制摘要只有版本/平台/renderer，不包括存档、设备标识或交易信息，不自动发送。

同步修改 `export_presets.cfg` 中 Android version code/name、iOS 与 Mac version/short_version。官网首页不代替隐私政策；`privacy_url` 当前留空，未验证公开政策页面。

```sh
python3 games/RingRush/tools/production_preflight.py
python3 games/RingRush/tools/production_preflight.py --strict
```

Strict 当前应以非零状态退出并列出未完成项；不要把警告忽略掉再称为 production。此工具检查仓库配置和待办，不能代替商店审核、法律评估、签名验证和真实设备测试。

## 上线前顺序

1. 登记正式包名与 Apple team，替换 `com.example.*`。配置 Android release keystore、Play App Signing、Apple provisioning 和商店构建签名；直接分发 Mac 时补 Developer ID + notarization。密钥/证书不进 Git。
2. 按 [monetization.md](monetization.md) 实现并验证 AdMob / Play Billing / StoreKit adapter。当前 core 有去重、超时和奖励账本；没有真实 SDK。必须从商店取真实本地化价格，完成收据验证、消耗/确认、退款对账、恢复购买；正式版不走 mock。
3. 发布匹配实际 SDK 行为的隐私政策，配置 `privacy_url`。游戏内已有当前试玩说明，不能拿“没有 SDK”说明用于接入 SDK 后的版本。完成 Google Play Data safety、Apple privacy disclosures、适用的广告同意与年龄流程；需要跟踪权限时使用平台规定流程。参考 [Google Play User Data](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en) 和 [Apple Review Guidelines: Privacy](https://developer.apple.com/app-store/review/guidelines/#privacy)。
4. 生成 [构建](builds.md)，用签名后的实际安装包在 Android/iOS 验收：低端和高端设备、长局 30/50 波、背景恢复、旋转/安全区、低内存、离线、无广告、取消支付、pending、重复回调、restore、断电/关闭恢复存档、发热与电量。
5. 打包所有模型/字体/Godot notices，检查设置 Credits 里的许可文本确实能在导出包打开。模型作者声明 CC0 的来源、下载哈希和改动说明已记录；第三方软件仍遵守各自条款。
6. 准备商店图标、真实截图/视频、描述、内容分级、支持链接、政策 URL 和测试账号（如果后续加账号）。先封闭测试，再按反馈调整掉率、敌人压力和辅助触发率。
7. Web 按 [deployment.md](deployment.md) 部署 HTTPS 静态站点，注意站点 origin 改变会使用不同本地存档。检查浏览器 WebGL2、移动 Safari 音频手势解锁和可用存储。当前没有公开部署。

## 平衡版本和存档

0.7 保留金币、购买等级及已获得徽章；徽章迁移为至少 Bronze。进行中战斗保留冻结的属性快照，通用战斗规则随版本更新。生产变更须明确保存兼容性，继续跑 game suite 与独立 core suite，不可用清空玩家存档来隐藏迁移问题。

建议第一轮朋友试玩关注：第一次选到远程卡所需时间、首次 Boss 死亡原因、Q/E 的使用时机是否清晰、辅助是否值得金币、30/50 波的后期压力。此版本没有自动上传遥测；通过 Support 收集玩家自愿反馈即可。

## 共享后端接入进展（2026-09-09）

`apps/backend` 已新增 Express/TypeScript 服务、自建 Auth、Google Play 一次性商品验证/退款/恢复、持久化 worker 和带 revision 的云存档。Supabase 仅作 PostgreSQL。配置及部署见 [backend.md](backend.md)。当前客户端仍是试玩流程；后端完成不等于 Android Billing 插件、登录与云同步 UI、真实商店交易和正式隐私说明已经接通。

0.9.0 已接入游戏登录和云存档，含离线本地存档、分账号缓存和冲突选择，见 [cloud-saves.md](cloud-saves.md)。正式 API/数据库/SMTP 配置、移动设备验收及真实 Billing 接入仍未完成。

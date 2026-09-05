# 广告、购买与通知接入

## 当前状态

共享逻辑在 `packages/mobile-core/addon`，游戏产品/奖励在 `games/RingRush/game/balance.gd`，注入点是 `game/main.gd` 中的 `MobileCore.configure_commerce(...)`。核心已有请求生命周期、超时、原子存档、重复回调去重、恢复与奖励账本。**AdMob、Play Billing、StoreKit 和系统通知原生 SDK 尚未安装。** 试玩用模拟 provider；正式版不配置 provider 时返回 unavailable。

## 广告

1. 在所选广告平台分别登记 Android/iOS app，创建 banner、interstitial、rewarded placements。采用支持 Godot 4.5 的原生插件，并固定插件版本。广告平台账号 ID、ad unit ID 和游戏 placement ID 分开维护。
2. 为各平台实现 `CoreCommerceProvider` adapter，接上插件的初始化、加载、展示、失败、关闭、获得奖励回调。SDK 初始化前完成适用的 consent 流程，开发阶段使用官方测试广告。
3. `show_rewarded(request_id, placement)` 必须保留请求 ID。只有 earned-reward 回调能标记 earned；关闭、取消、no-fill 不能发奖。关闭后发出一次 `ad_finished(request_id, earned, reason)`。不要把试玩的 5/15 秒倒计时覆盖到真实 SDK 上；关闭时机由广告 SDK 控制。[Google Rewarded 回调说明](https://developers.google.com/admob/android/rewarded)。
4. 实现 `show_interstitial`、`set_banner` 和 `cancel`。Remove Ads 抑制 banner/自动插屏，保留玩家主动选择的复活或额外奖励。战斗中不展示自动广告。
5. 在 Android 预设启用插件所需权限（包括网络）；iOS 增加对应插件配置。真机测试完成、取消、无广告、后台恢复和重复回调。

注入示例（`NativeCommerceAdapter` 是你实现的类，不是本仓库已有插件）：

```gdscript
var adapter = NativeCommerceAdapter.new()
MobileCore.configure_commerce(RushBalance.PRODUCTS, RushBalance.REWARDS, adapter)
```

adapter 的方法和信号以 [`provider.gd`](../../packages/mobile-core/addon/monetization/provider.gd) 为准。不要在游戏 HUD 中散布各 SDK 的调用。

## IAP

在 Google Play Console/App Store Connect 建立金币 consumables、remove_ads 和 gold_gloves non-consumables，将商店商品 ID 映射到游戏 catalog。界面要读取商店提供的本地化价格；目前 SHOP 的 TEST/UNAVAILABLE 按钮需要换成原生商品加载、购买、pending、失败与 restore 状态。

`purchase(request_id, product)` 调起原生付款。通过可信后端核验交易后，adapter 才能发出 `purchase_finished(request_id, product, stable_transaction_id, true, reason)`；交易 ID 用于防重复发放。Google 侧在验证后交付并按要求 acknowledge/consume，Apple 侧完成已处理交易；pending/deferred 不当成成功。[Google 购买验证](https://developer.android.com/google/play/billing/security)、[Apple IAP](https://developer.apple.com/documentation/storekit/in-app-purchase)。

上线前补上重启/断网后的交易对账和退款撤销。目前核心 restore 合并已有权益，**不会自动撤销退款权益**；需要原生/后端对账后显式更新。不要通过客户端自报 verified 来替代商店验证。密钥与收据验证凭证不进 repo。

## 通知

游戏内 toast 已可用。系统通知需要实现 `CoreNotificationProvider` 并注入 `MobileCore.notifications.configure(adapter)`，在玩家主动启用提醒后才请求权限；授权成功后使用稳定 ID schedule/cancel。默认 provider 返回不可用，不伪造系统提醒成功。远程 push 还需要服务器和平台投递配置。

## 接入验收

用 sandbox/test ads 验证：重复回调只发一次；存档失败不丢交易；取消不扣币；restore 不重复奖励；remove_ads 保留可选 rewarded；广告期间暂停、结束后恢复；无网络和无 SDK 时能返回游戏。`test-core` 验证共享契约，真实插件必须另行进行 Android/iOS 实机测试。

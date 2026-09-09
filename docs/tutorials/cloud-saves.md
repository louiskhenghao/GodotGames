# RingRush 账号与云存档接入

0.9.0 已在游戏设置中接上登录、注册、邮件验证检查、重发邮件、忘记密码、登出及云存档。主页显示保存状态。真实 Play Billing 购买界面仍是后续独立步骤。

## 配置

编辑 `games/RingRush/config/backend.json`：

- `game_id` 必须对应共享后端 `backend.games.id`，RingRush 是 `ringrush`。
- `api_url` 是部署后的 **HTTPS API origin**，不包含 `/v1`。目前留空，因此正式 release 不会误连本机服务。
- `development_api_url` 仅在 debug / playtest 使用，当前指向 `http://127.0.0.1:13099`。它是电脑上的测试后端，其他手机不能用自己的 localhost 访问这台电脑。
- 原生开发可用 `RINGRUSH_API_URL` 环境变量覆盖测试地址。Web 使用导出时的 JSON 配置。
- API 的 `CORS_ORIGINS` 要逐项列出 Web 页面的 origin，例如 `http://127.0.0.1:8771`。正式网站与 API 都使用 HTTPS。
- 后端游戏必须 `enabled=true`，SMTP worker 必须运行，注册邮件才能送达。配置步骤见 [backend.md](backend.md)。Android 导出预设已开启 INTERNET 权限。

本地 API + PostgreSQL + SMTP Mailpit 测试不等于正式部署。发布前配置 Supabase、真实发信域名、HTTPS API 和网站；将 `api_url` 填好，再导出正式版本。不要把密码、服务账号 JSON、数据库 URL 放进游戏配置。

## 玩家的使用流程

1. 设置 → **ACCOUNT & CLOUD SAVE**。首次注册后，在收到的邮件中验证，再登录；若已登录未验证，可点 **CHECK VERIFICATION**。
2. 第一个云存档会让玩家选择导入游客进度或开始新账号。已有云存档的账号在新设备登录后自动恢复。
3. 离线时仍然正常本地保存：包括每 15 秒战斗检查点、关卡结算、角色与技能升级。回到主页且会话有效时，联网后自动重试同步；也可在账号页点 **SYNC NOW**。
4. 如果关掉游戏，下一次仍直接进入上次账号的本地进度，不会强制联网才能玩；重新登录后才能同步。这一版不持久化登录令牌，之后可接手机系统安全存储。
5. 两台设备都产生新进度时，显示双方金币、战斗数、击倒数及云端更新时间，玩家选择保留整份本机或云端进度。不会自动相加金币或覆盖较新的分支。
6. 登出返回独立游客档。该账号未同步的进度仍在它自己的本地文件中；再次登录同一账号可以继续处理。

只要本机文件还在，即使一直离线，进度也不会因为没有网络而被主动丢弃。但卸载应用、设备损坏或清除浏览器数据会丢失未同步部分；没有完成云同步的进度无法凭空恢复到另一台手机。离线游戏不是防作弊系统，云进度仍是客户端生成的数据。

## 对接下一个游戏

共享流程在 `packages/mobile-core/addon/cloud/`，使用方法见 [Mobile Core](../../packages/mobile-core/README.md#accounts-and-offline-first-cloud-saves)。新增游戏只需：

1. 后端登记 game ID、启用状态及商品资料。
2. 同步 mobile-core 包，配置 `MobileCore.account`。
3. 使用 CoreSaveStore 的 profile envelope 保存该游戏进度。
4. 在该游戏自己的 UI 展示账号状态与冲突选项；收到 `profile_loaded` 后刷新角色、关卡和设置。

## 验证

```sh
python3 tools/workspace.py --godot /path/to/Godot test-core
python3 tools/workspace.py --godot /path/to/Godot test RingRush
```

可选真实 HTTP 测试使用本地、可丢弃的已验证账号（邮箱必须以 `@example.test` 结尾）：

```sh
CLOUD_TEST_URL=http://127.0.0.1:13099 \
CLOUD_TEST_EMAIL=your-local-test@example.test \
CLOUD_TEST_PASSWORD=YOUR_LOCAL_TEST_PASSWORD \
/path/to/Godot --headless --path games/RingRush --script res://tests/cloud_api_smoke.gd
```

该测试会修改测试账号的云进度，覆盖登录、导入、第二设备、断网/重连、冲突和登出；不应指向生产数据库。`tests/account_capture.gd` 用于 540/320 像素宽的页面截图检查。真实 Android/iOS 安装包的软键盘、后台恢复、存储和网络切换仍需设备验收。

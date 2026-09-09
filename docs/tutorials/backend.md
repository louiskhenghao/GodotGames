# 多游戏后端：Auth、Google Play IAP、云存档

后端位于 `apps/backend`。一个账号系统、一套 API/worker 和一个 PostgreSQL 数据库可支持多个游戏；Supabase 只承担数据库，不使用 Supabase Auth、Supabase JWT 或其客户端 service-role key。

## 1. 本地与测试环境

需要 Node 24、npm 和 Docker。开发启动见 [backend README](../../apps/backend/README.md)。开发 Postgres 在 55440，临时测试 DB 示例在 55439；不要把集成测试指向已有开发/生产数据库，测试会清空测试 schema 数据。

```sh
npm ci
docker run --rm -d --name zxlabs-backend-tests \
  -e POSTGRES_USER=iap_test -e POSTGRES_PASSWORD=local-test-only -e POSTGRES_DB=iap_test \
  -p 127.0.0.1:55439:5432 postgres:17-alpine
npm run backend:check
npm run backend:test
npm run backend:build
docker stop zxlabs-backend-tests
```

测试运行完整 PostgreSQL SQL/锁/事务，没有用内存数据库替代。Google API 与邮件投递在集成测试中使用可控的适配器，不会伪造已经通过真实 Play 交易验证的结果。

## 2. Supabase PostgreSQL

在 Dashboard 的 Connect 中取得数据库连接字符串。长驻 Node 服务使用 direct connection，或需要 IPv4 时用 **Session pooler**。为部署环境设置 `DB_TLS=true`，按项目证书配置 `DB_CA_FILE`；代码不会通过 `rejectUnauthorized:false` 绕过证书验证。

迁移使用数据库 owner 的连接，放入本地部署环境的 `MIGRATIONS_DATABASE_URL`。运行：

```sh
npm run migrate -w @zxlabs/backend
```

迁移创建私有 `backend` schema、账号/会话/商品/订单/账本/任务/云存档表和 NOLOGIN 角色 `game_backend`。创建单独的 runtime login role，并授予该角色：

```sql
-- 在受控数据库管理终端执行；替换密码，不要将真实密码写入仓库。
create role game_backend_login login password 'REPLACE_WITH_A_RANDOM_PASSWORD' in role game_backend;
```

API 与 worker 的 `DATABASE_URL` 使用 `game_backend_login`。不要把迁移 owner URL 放入运行容器。设置最小数据库权限、网络访问控制和备份，保持 `backend` 不在 Supabase Data API 的 exposed schemas 内。即使误配置了 exposed schema，RLS 与 schema/table grants 仍不允许匿名客户端写入支付数据。

迁移有事务、锁与校验和。部署顺序是迁移 → API/worker；不要改已应用迁移，新增下一份 SQL。`migrations/002_cloud_saves.sql` 演示新增表时同步授予 runtime 权限和 RLS。

官方数据库连接说明：[Supabase connecting to Postgres](https://supabase.com/docs/guides/database/connecting-to-postgres)。

## 3. 自建账号与 SMTP

生成独立的 `AUTH_JWT_SECRET` 和 AES 加密 keyring。生产将其保存在部署平台的 secret manager 中，不提交 `.env`。邮件使用自己的 SMTP 服务；填 `SMTP_HOST/PORT/SECURE/USER/PASSWORD` 和已验证的 `MAIL_FROM`。

- 注册 → 验证邮件 → 登录；未验证邮箱不能进入购买和云存档 API。
- refresh token 每次刷新后替换；客户端应串行刷新，用手机安全存储保存 refresh token。
- 30 天 refresh 过期后重新登录；access token 15 分钟。
- 可单设备登出、全设备登出、邮件重置密码。
- 开发用 Mailpit；生产使用自己选择的 SMTP 提供商并配置发信域名记录。

没有 Supabase Auth 依赖。数据库、部署及邮件服务仍按各自提供商计费，这不是零基础设施成本的承诺。

上线开放账号前补齐用户数据导出/删除流程、正式隐私政策和保留周期。当前游戏内的“本地试玩、不上传数据”说明接入后不再准确，必须随客户端一起更新。

## 4. Play Console 配置

先确定最终 Android application ID。当前 `com.example.*` 不能作为生产配置；seed 脚本会拒绝。`ringrush` 是后端的稳定游戏 ID，Android package 则必须和签名上传到 Play 的包一致。

为后端启用 Google Play Android Developer API。使用运行服务身份/Workload Identity 的 ADC，或本地使用仓库外的服务账号密钥文件。将服务账号邀请到 Play Console，并给相应应用的购买/订单验证及管理权限。不要把服务账号文件打包到 Godot、APK 或 Web 中。

为 RingRush 创建一次性商品，和 seed 对齐：

| Product ID | 类型 | 后端奖励 |
| --- | --- | --- |
| coins_500 | consumable | 500 coins |
| coins_1500 | consumable | 1,500 coins |
| coins_4000 | consumable | 4,000 coins |
| remove_ads | non_consumable | remove_ads |
| gold_gloves | non_consumable | gold_gloves |

价格、地区、税务及展示信息在 Play 配置。金币数量来自受控的后端 catalog；不能接受客户端提交的价格/奖励数量。首次上线建议使用普通 buy option，暂不开租赁、预购或订阅。

填入 `RINGRUSH_ANDROID_PACKAGE`、`RINGRUSH_ENABLED=true` 后运行 `seed:ringrush`。脚本不会覆盖已有商品奖励，也不会把一个已存在的游戏 ID 换绑到另一个 package。

购买验证遵循 [Google Play fraud prevention](https://developer.android.com/google/play/billing/security) 和 [ProductPurchaseV2](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.productsv2)。发货后由 worker 确认/消耗；Google 的确认期限从购买完成后计算，必须监控并及时修复积压。[一次性商品生命周期](https://developer.android.com/google/play/billing/lifecycle/one-time)。

## 5. RTDN / Pub/Sub

1. 创建 Google Cloud Pub/Sub topic，按 Play 文档授权 Google Play 发布身份向该 topic 发布。
2. 在每个应用的 Play Console 配置 RTDN topic，启用一次性商品事件。
3. 创建 **authenticated push subscription**，endpoint 为 `https://YOUR_API_HOST/webhooks/google-play`。指定专门的推送 service account，配置 Google Pub/Sub service agent 的 token-creation 权限。
4. 设置 audience 与后端 `PUBSUB_AUDIENCE` **完全相同**，`PUBSUB_SERVICE_ACCOUNT_EMAIL` 为刚才指定的推送身份。不要把 publisher 身份误当 push 身份。
5. 每个游戏记录完整 subscription 路径 `projects/.../subscriptions/...`。RingRush 用 `RINGRUSH_PUBSUB_SUBSCRIPTION` 配置后重新 seed。
6. 从 Play Console 发 test notification；确认 API 收到 204，worker 将对应 notification job 完成。再进行 license tester 购买验证。

同一部署可有多个游戏 subscription 共用此 endpoint；每条通知必须同时通过 OIDC、subscription 和 package 检查。subscription 为共享配置时改用一个明确的游戏映射设计，不要关闭校验。

参考：[RTDN schema](https://developer.android.com/google/play/billing/rtdn-reference)、[Pub/Sub push authentication](https://docs.cloud.google.com/pubsub/docs/authenticate-push-subscriptions)。

## 6. 部署 API 与 worker

使用已发布镜像、Supabase 环境变量与 Hostinger VPS 的完整步骤，见 [hostinger-docker.md](hostinger-docker.md)。

同一个镜像运行两个进程类型：

```sh
docker build -f apps/backend/Dockerfile -t zxlabs-backend:VERSION .
# API 默认命令：node apps/backend/dist/server.js
# Worker 命令：node apps/backend/dist/worker-main.js
```

- API：HTTPS ingress，健康检查 `/health/live` 和 `/health/ready`，`PORT` 默认 3000。
- Worker：持续运行，不需要公开端口。不能部署为只有请求时才分配 CPU 的服务；否则购买确认、邮件和对账会停止。适合常驻容器/VPS/worker service，或配置了持续 CPU 的运行环境。
- 两者使用相同数据库、加密 keyring、账号配置和 Google ADC 权限。容器以 non-root 用户运行。
- 生产 `NODE_ENV=production` 会拒绝明文数据库和 HTTP 公网 URL。`TRUST_PROXY_HOPS` 按真实代理层数设置，不能在公网随意信任所有 forwarded headers。
- 每个 API 或 worker 最多 10 条数据库连接；依据 Supabase 连接上限限制实例数。
- 浏览器源明确配置 `CORS_ORIGINS`。移动端使用 Bearer token，不靠 CORS 防护。

部署环境可手动运行：

```sh
npm run ops:status -w @zxlabs/backend
npm run ops:retry -w @zxlabs/backend -- DEAD_JOB_ID
```

`ops:status` 在死信、超过 2 小时未确认、或对账超过一天未成功入队时返回非零。将它或等价 SQL 指标接入部署平台告警，检查 worker 日志中的安全错误码。排除权限、商品或帐号问题后才重放 dead job。

退款补扫每 6 小时覆盖过去 29 天；不要认为系统可以自动弥补超过 Google 查询窗口的长期停机。全额退款撤权、数量部分退款冲正及去重均在后端处理。运营发起退款继续使用 Play Console；没有公开的“玩家主动退款管理”端点。

## 7. 新增第二个游戏

复用同一服务，添加 `backend.games` 一行（新 `id`、package、独立 subscription）与对应 `backend.products` 行。配置该应用的 Play 权限和 RTDN；客户端用新 gameId。Auth 账号可共享，billing ID、商品、权益和云存档独立。无需复制服务器代码或另开 Supabase 项目。

未来 App Store 可实现独立 provider + Apple 通知适配器，并沿用账号/云存档基础；当前数据库与路由明确是 Google Play 交易，不能宣称已兼容 Apple 收据或订阅。

## 8. 正式上线前仍需完成的接入

后端已具备可运行和可测试的 Auth、IAP 和云存档接口。还需要真实 Supabase/SMTP/Google 配置、部署地址，以及持久令牌安全存储、BillingClient 和真实购买发货同步。RingRush 已接入内存会话登录、离线存档与云存档冲突 UX。按照 [客户端合约](../../apps/backend/docs/client-integration.md) 接入。

在 Play license tester 上验证：成功/取消/pending、掉网重试、杀进程后补单、重复回调、换手机登录与 restore、金币退款、永久权益退款、邮件送达、密码重置与会话撤销。测试卡应使用独立 staging 数据库和 `allow_test_purchases=true`；生产默认拒绝测试卡。没有真实交易联调结果时不要将后端单元/集成测试当成商店验收。

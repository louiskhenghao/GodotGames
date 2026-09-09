# ZX Labs shared game backend

Node 24 + Express 5 + TypeScript + PostgreSQL。部署一套 API 和 worker 服务，服务多个游戏。Supabase **只用 PostgreSQL**；注册、密码、邮件验证、JWT 和会话由本后端实现，不调用 Supabase Auth。

```text
Android / Godot / Web
  └─ 自建 Auth → gameId + userId
       ├─ Google Play 购买验证 → 发货/退款账本 → consume / acknowledge 队列
       ├─ 权益、增量账本、恢复购买
       └─ 云存档 → revision 冲突检测 + 购买游标 + 历史版本
Google Play → authenticated Pub/Sub push → 持久化任务 → Google API 再核验
Worker → 确认购买 / 邮件 / 补单 / 退款定期对账
Supabase PostgreSQL → 私有 backend schema；不开放客户端直接写表
```

## 本地启动

在 monorepo 根目录安装 `npm ci`，Godot 游戏开发不需要启动后端。

```sh
docker compose -f apps/backend/compose.yaml up -d
cp apps/backend/.env.example apps/backend/.env
```

编辑 `.env`。分别生成两个不同的随机 32-byte Base64 key，填入 `AUTH_JWT_SECRET` 和 `TOKEN_ENCRYPTION_KEYS`，不要使用示例占位符。`PUBLIC_BASE_URL` 是用户点邮件时能访问的 API 地址。开发环境 Mailpit 的收信页面为 `http://localhost:8025`，邮件不会发到外部。

```sh
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
npm run migrate -w @zxlabs/backend
# 填入最终 Android 包名等 RINGRUSH_* 配置；默认 disabled，不虚构生产包名。
npm run seed:ringrush -w @zxlabs/backend
npm run backend:dev
# 第二个终端：
npm run worker:dev -w @zxlabs/backend
```

真实购买验证还需要 Google Play Developer API 权限与 ADC。没有凭据时注册、登录和云存档仍可测试；Google 验证会失败，不会以 mock 购买代替真实验证。测试中的 FakePlay 只存在于 `tests/`，生产构建不包含它。

## 验证与部署

```sh
npm run backend:check
npm run backend:build
# 必须指向本机独立的 *_test 数据库；测试会清空其 backend 表。
TEST_DATABASE_URL=postgresql://iap_test:local-test-only@127.0.0.1:55439/iap_test npm run backend:test
docker build -f apps/backend/Dockerfile -t zxlabs-backend:local .
```

- [API 合约与客户端顺序](docs/client-integration.md)
- [OpenAPI 3.1](docs/openapi.json)
- [Supabase / Play Console / SMTP / 部署教程](../../docs/tutorials/backend.md)
- [事务、退款与云存档设计](docs/design.md)
- [验证记录](docs/validation.md)

首版实现 Google Play 一次性商品：金币包、去广告及永久装饰。订阅、Apple StoreKit、运营端主动申请退款尚未实现；订阅通知会进入可观测的失败队列，不会误当金币发货。退款入口是 Google Play / Play Console，本后端处理退款后的撤权和冲正，没有暴露玩家可调用的退款管理 API。

**客户端接入状态：** 本次完成后端服务和接口。现有 RingRush 0.8 客户端仍使用本地存档/模拟支付；尚未加入登录页面、Android Billing 插件、安全令牌存储和云同步 UI。必须按客户端合约接入并通过 Play license tester 真机联调后，才能称为跨手机存档和正式 IAP 已在游戏内启用。

# ZX Labs Backend 0.0.0：Docker Hub 与 Hostinger VPS

镜像：**`imlouiskhenghao/zxlabs:0.0.0`**。同一个镜像运行 API、后台 worker，以及一次性数据库管理命令。Supabase **只作 PostgreSQL**，账号由后端自己管理。镜像不包含游戏资源、数据库、生产环境变量或私钥。

部署文件在 [`apps/backend/deploy`](../../apps/backend/deploy/)：`compose.yaml`、`Caddyfile`、`.env.example`、`admin.env.example`。本教程使用 Hostinger **VPS + Docker Compose**；hPanel 的入口为 VPS → Manage → Docker Manager → Compose。也可以通过 SSH 执行下面的命令。[Hostinger 官方 Docker Manager 教程](https://www.hostinger.com/support/12040815-how-to-deploy-your-first-container-with-hostinger-docker-manager/)。

## 1. 准备资料

部署前准备：

- Hostinger VPS 的 SSH 登录，以及 Docker / Docker Compose。
- 一个解析到 VPS 的 API 域名，例如 `api.your-domain.com`。示例不是已经配置的 ZX Labs 域名。
- Supabase PostgreSQL owner 连接字符串、Session pooler 地址和项目根 CA 证书。
- 真实 SMTP：host、端口、TLS 方式、用户名、密码和已经验证的发件邮箱。
- Google Play 服务账号 JSON、Pub/Sub authenticated push 的 service account email、subscription 路径；完整配置见 [backend.md](backend.md#4-play-console-配置)。这些不是 Supabase Auth key。
- RingRush 最终 Android package；它必须和 APK/AAB、Play Console 相同，不能继续用 `com.example.*`。

Google 权限未配好时，账号/云存档接口仍可工作，但购买验证和 worker 对账会失败并重试。正式接受购买前必须完成 Google 配置和商店实测。

## 2. 在 VPS 放置配置文件

从本机上传 `apps/backend/deploy/` 中的四个模板文件到 VPS `/opt/zxlabs-backend/`。不需要上传整个 monorepo、Node 或 `node_modules`。以下命令在 VPS 的这个目录执行：

```sh
cd /opt/zxlabs-backend
cp .env.example .env
cp admin.env.example admin.env
mkdir -p secrets
chmod 600 .env admin.env
```

将 Supabase CA 放为 `secrets/supabase-ca.crt`，Google 凭证放为 `secrets/google-play.json`。应用镜像以 UID/GID **1000** 运行，需要能读取这两个文件：

```sh
chown root:1000 secrets secrets/supabase-ca.crt secrets/google-play.json
chmod 750 secrets
chmod 640 secrets/supabase-ca.crt secrets/google-play.json
```

以上权限命令以 VPS root 用户执行。不要将实际 `.env`、`admin.env`、`secrets/` 提交 Git，也不要通过 Dockerfile COPY 它们。升级镜像时保留它们。

```sh
docker pull imlouiskhenghao/zxlabs:0.0.0
```

如果 Docker Hub 仓库是 private，先在 VPS 执行 `docker login -u imlouiskhenghao`，在提示中输入 Docker Hub access token；hPanel 可使用其 private registry 配置。不要把 Docker Hub token 当作应用环境变量。

## 3. `.env`：API 与 worker 共用

编辑复制出来的 `.env`。下面每个字段都能在模板中找到。

| 环境变量 | 怎么填写 |
| --- | --- |
| `BACKEND_IMAGE` | `imlouiskhenghao/zxlabs:0.0.0`；这是 Compose 拉取的标签 |
| `API_HOST` | API 域名，例如 `api.your-domain.com`，没有 `https://`、路径或尾斜线；Caddy 使用 |
| `NODE_ENV` | `production`，Compose 会强制设置 |
| `PORT` | `3000`，Compose API 固定内部端口 |
| `DATABASE_URL` | **runtime login role** 的 Supabase PostgreSQL URL；不能使用 owner 或 anon/service-role API key |
| `DB_TLS` | `true`；生产不允许关闭证书验证 |
| `DB_CA_FILE` | `/run/secrets/supabase-ca.crt` |
| `PUBLIC_BASE_URL` | `https://你的API域名`，无尾斜线；验证/重置密码邮件使用此地址 |
| `AUTH_ISSUER` | `zxlabs-games`；部署后保持稳定 |
| `AUTH_AUDIENCE` | `zxlabs-games-api`；部署后保持稳定 |
| `AUTH_JWT_SECRET` | 至少 32 随机字节的 Base64；API/worker 使用相同值 |
| `TOKEN_ENCRYPTION_KEYS` | JSON，例如 `'{"v1":"独立随机的32字节Base64"}'`；外层单引号用于 `.env` |
| `TOKEN_ENCRYPTION_KEY_ID` | `v1`，必须在上面的 JSON 中存在 |
| `GOOGLE_APPLICATION_CREDENTIALS` | `/run/secrets/google-play.json`；只读挂载的服务账号文件 |
| `PUBSUB_AUDIENCE` | `https://你的API域名/webhooks/google-play`，必须与 authenticated push audience 完全一致 |
| `PUBSUB_SERVICE_ACCOUNT_EMAIL` | Pub/Sub push 指定的 service account email；不是 Google Play publisher 邮箱 |
| `CORS_ORIGINS` | 允许的网页 origin，逗号分隔，例如 `https://play.your-domain.com`；不包含路径或尾斜线；原生 App 不靠 CORS |
| `TRUST_PROXY_HOPS` | 本文 Caddy 单层代理为 `1`；如果另有 CDN/代理，按真实拓扑重新配置 |
| `SMTP_HOST` | 邮件服务商提供的 SMTP host |
| `SMTP_PORT` | 通常 `587` 或 `465`，以邮件服务商资料为准 |
| `SMTP_SECURE` | 587 + STARTTLS 通常 `false`；465 隐式 TLS 通常 `true`；production 的非隐式模式会要求 STARTTLS |
| `SMTP_USER` | SMTP 登录用户 |
| `SMTP_PASSWORD` | SMTP 密码；含 `$` 等符号时保留模板的外层单引号，避免 Compose 插值 |
| `MAIL_FROM` | 例如 `'ZX Labs <support@zxlabs.dev>'`，需要你的邮件服务允许这个发件人 |
| `WORKER_POLL_MS` | `1000`，后台任务轮询间隔 |

生成随机值可执行下面的命令 **两次**，分别用于 JWT secret 和 AES key。不要两个字段共用一个值：

```sh
docker run --rm --no-healthcheck imlouiskhenghao/zxlabs:0.0.0 \
  node -e "console.log(require('node:crypto').randomBytes(32).toString('base64'))"
```

升级或重启不能重新生成 `TOKEN_ENCRYPTION_KEYS`，否则已有购买 token 和任务将无法解密。轮换时保留旧 key，例如 `'{"v1":"OLD_KEY","v2":"NEW_KEY"}'`，将 key ID 改为 `v2`；直到旧密文全部迁移前不能删除旧 key。JWT secret 改动会使现有登录需要重新认证。

### PostgreSQL 连接

推荐长驻 VPS 使用 direct connection；VPS 无 IPv6 路由时用 Supabase **Session pooler** 的 5432 端口。连接 host 从 Dashboard 的 Connect 复制，不要猜地区地址。Session pooler 自定义用户通常使用 `game_backend_login.PROJECT_REF`，direct connection 使用 `game_backend_login`。密码中的 `@`、`:`、`/`、`#` 等字符必须 URL-encode。

不要在应用 URL 中靠 `sslmode=disable` 绕过配置；后端会使用显式 TLS 设置。连接方式参考 [Supabase 官方连接说明](https://supabase.com/docs/guides/database/connecting-to-postgres)。

## 4. 第一次数据库初始化

先编辑 `admin.env`，这个文件**仅进入一次性 admin 容器**：

| 字段 | 用途 |
| --- | --- |
| `MIGRATIONS_DATABASE_URL` | 数据库 owner URL，用于创建 schema、表、角色和迁移 |
| `DATABASE_URL` | 同一个 owner URL，供 seed 使用；不会传给 API/worker |
| `DB_TLS` / `DB_CA_FILE` | `true` / `/run/secrets/supabase-ca.crt` |
| `RINGRUSH_ANDROID_PACKAGE` | 正式应用 package |
| `RINGRUSH_PUBSUB_SUBSCRIPTION` | `projects/PROJECT/subscriptions/SUBSCRIPTION` |
| `RINGRUSH_ENABLED` | `true` 开启该游戏的账号进度/购买 API |
| `RINGRUSH_ALLOW_TEST_PURCHASES` | 正式环境 `false`；独立 license-test 环境可以 `true` |

运行迁移：

```sh
docker compose --profile admin run --rm admin
```

迁移可以重复运行，会检查已应用 SQL 的校验和，不会清空数据库。完成后在 Supabase SQL Editor 或受控管理终端创建应用登录角色：

```sql
create role game_backend_login login
  password 'REPLACE_WITH_RANDOM_RUNTIME_PASSWORD'
  in role game_backend;
```

将这个角色的 URL 写入 `.env` 的 `DATABASE_URL`。`admin.env` 仍保留 owner URL。保持私有 `backend` schema 不在 Supabase Data API 的 exposed schemas 内。

初始化 RingRush 游戏与商品目录：

```sh
docker compose --profile admin run --rm admin \
  node apps/backend/dist/ops/scripts/seed-ringrush.js
```

该命令不会改变已有商品奖励，但会更新该游戏的 enabled/test/subscription 配置；已有 package 不能换绑。`coins_500`、`coins_1500`、`coins_4000`、`remove_ads`、`gold_gloves` 必须与 Play Console 商品 ID 一致。

## 5. 启动 API、worker 和 HTTPS

### 新 VPS：使用附带 Caddy

先把 API 域名 A/AAAA 记录指向 VPS，在 Hostinger 防火墙和主机防火墙允许入站 80/443，并确认没有其他服务占用它们。不要给 API 的 3000 端口开公网入口。

```sh
docker compose config --quiet
docker compose --profile edge up -d api worker caddy
docker compose ps
curl --fail https://你的API域名/health/ready
```

`/health/ready` 返回 `{"status":"ready"}` 表示 API 能访问数据库。Caddy 会为配置的域名管理 HTTPS；其证书状态保存在 `caddy_data`/`caddy_config` named volumes。不要删除这些卷。默认 Caddy 配置不记录带验证 token 的 URL 访问日志。证书与网络要求见 [Caddy Automatic HTTPS](https://caddyserver.com/docs/automatic-https)。

API 容器已内置健康检查。Worker 没有 HTTP 端口，Compose 禁用了不适用的 API healthcheck；它必须持续运行，负责邮件、购买确认/消耗和退款对账。仅启动 API 会导致注册邮件和购买确认积压。

### VPS 已有 Nginx / Traefik / Hostinger 代理

不要再启动 `edge`，避免抢占 80/443：

```sh
docker compose up -d api worker
```

如果代理运行在主机上，将 HTTPS upstream 指向 `http://127.0.0.1:3000`。如果代理也是容器，`127.0.0.1` 指的是代理容器自己：将 API 加入已有代理的 external Docker network，然后使用网络内服务地址 `api:3000`。域名/路由 label 和 network 名使用你那台 VPS 的实际配置；不要照搬另一个项目的网络名。保持 `TRUST_PROXY_HOPS` 与代理层数匹配，且让 API 只能经过可信代理访问。

### 使用 Hostinger Docker Manager 界面

先用 SSH 上传上述文件和 secrets，完成迁移与 seed。最直接的方法是在 `/opt/zxlabs-backend/` 通过 SSH 运行 Compose，再从 Docker Manager 管理容器。若使用 **Compose manually**，确保所有 `env_file`、`Caddyfile`、secrets 的路径相对于它实际的项目目录；也可以换成 VPS 上的绝对路径。不要只粘贴 YAML 就漏掉这些文件。管理员的一次性命令仍可通过 SSH 执行。

## 6. 检查部署与日志

```sh
docker compose ps
docker compose logs --tail=100 api worker
# 运维状态：死信、确认超时、退款扫描长期未入队时会退出非零。
docker compose exec api node apps/backend/dist/ops/scripts/status.js
```

初次启动要等待 worker 首次扫描。日志 `PLAY_PERMISSION_ERROR` 应检查 Google Play 权限；邮件问题检查 SMTP 和 worker。HTTP readiness 不代表 SMTP 或 Google Play 已完成外部验收。

确认错误原因已修复后，才重试具体死信任务：

```sh
docker compose exec worker node apps/backend/dist/ops/scripts/retry-job.js DEAD_JOB_ID
```

从游戏做一次注册 → 收到真实验证邮件 → 登录 → 保存 → 另一台设备登录恢复，再测离线/重新联网和冲突。最终还要做 Play license tester 的购买、重复回调、退款及恢复验证。

在 `games/RingRush/config/backend.json` 设置部署后的 `api_url`，再导出游戏。公开 Web 网站改用自己的 origin，并同步配置 `CORS_ORIGINS`。本机 `127.0.0.1:13099` 不能供朋友或另一部手机使用。

## 7. 更新、回滚和备份

每次发版使用新标签，不复用已部署的 `0.0.0`。先备份数据库并确认迁移兼容性，然后修改 `.env` 的 `BACKEND_IMAGE`：

```sh
docker compose pull api worker admin
# 新版本可能有数据库迁移，仍由 admin 容器执行。
docker compose --profile admin run --rm admin
docker compose up -d api worker
```

需要回滚时改回旧镜像 tag/digest，再 `pull` 和 `up -d`；只有数据库 schema 兼容时才能直接回滚应用。旧镜像不等于旧数据库，不要通过删库解决迁移问题。可以把 `BACKEND_IMAGE` 固定为 `imlouiskhenghao/zxlabs@sha256:发布的digest` 来锁定内容。

数据库及备份在 Supabase；JWT/AES keys、Google credentials 和 SMTP 配置另行保管。API/worker 自身无持久数据卷，重新建容器不会清空进度，但丢失 AES keys 会影响已有加密交易与任务。日志有大小轮换，避免无限增长。

## 8. 开发者再次构建与推送

在 monorepo 根目录执行，先改 `apps/backend/package.json` 和 lockfile 中的版本，并使用新的 tag：

```sh
npm ci
npm run backend:check
npm run backend:build
docker login -u imlouiskhenghao
docker buildx build --platform linux/amd64,linux/arm64 \
  -f apps/backend/Dockerfile --build-arg RELEASE_VERSION=0.0.0 \
  -t imlouiskhenghao/zxlabs:0.0.0 --push .
docker buildx imagetools inspect imlouiskhenghao/zxlabs:0.0.0
```

首次 0.0.0 发布使用上面的版本；以后同步替换 tag 与 build arg。`buildx --push` 发布一个包含两种 Linux 架构的 manifest，Hostinger 拉取时会选匹配架构；避免仅把 Mac 本机的 ARM 镜像推给 x86 VPS。容器内管理命令路径为 `apps/backend/dist/ops/scripts/*.js`，无需 `npm install` 或 tsx。

## 0.0.0 发布记录

2026-09-10 已推送并从 Docker Hub 拉取验证 `linux/amd64`；镜像同时含 `linux/arm64`。发布 digest：

```text
sha256:e00c7fa7b6f03e82aee866d699e798b75fcb7cadddbf9b8a3344929315757168
```

本地验收已覆盖镜像内迁移/重复迁移/seed、non-root 只读 API、worker 注册邮件和运维命令。Hostinger 实例尚未部署，正式 Supabase、SMTP、DNS、Google Play 仍需按上面配置。

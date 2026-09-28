# DComic Sync Server

DComic Sync Server 是 DComic Reborn 的多用户 SQLite 同步服务，镜像内已包含管理 Dashboard。服务没有公开注册入口；只有管理员能在 Dashboard 中创建用户。

## 使用单个 Docker 镜像部署

镜像同时发布到 Docker Hub：`docker.io/hanerx/dcomic_server`（Docker CLI 中可简写为 `hanerx/dcomic_server`）和 GitHub Container Registry：`ghcr.io/hanerx/dcomic_server`，两者使用相同的标签策略，支持 `linux/amd64` 和 `linux/arm64`。这些是镜像地址，不是网页地址。

将 `TAG` 替换为要部署的标签，然后启动：

```sh
docker run -d --name dcomic-server --restart unless-stopped -p 8080:8080 -v dcomic-data:/data hanerx/dcomic_server:TAG
```

`TAG` 可以填写 `latest`（即镜像参数 `hanerx/dcomic_server:latest`），也可以填写下文所述的版本、分支或完整 SHA 标签。

使用 GHCR 时，将命令中的 `hanerx/dcomic_server:TAG` 替换为 `ghcr.io/hanerx/dcomic_server:TAG`。公开包可匿名拉取；私有包需要先执行 `docker login ghcr.io -u <GitHub 用户名>`，使用具有该包读取权限及 `read:packages` scope 的 personal access token (classic) 登录。

直接 HTTP 部署不需要设置任何环境变量。镜像默认监听 `0.0.0.0:8080`，数据库保存在 `/data/dcomic.db`；容器内服务默认以 root（`0:0`）运行，便于第三方 Docker 面板挂载由 root 创建的专用数据目录。首次启动会自动创建数据库文件，无需手工创建。

图形化部署面板可留空“运行用户”以使用镜像默认值，或显式填写 `0:0`；`/data` 必须以读写方式挂载。更新镜像后应拉取对应标签并重新创建容器，保留原数据挂载；仅重启旧容器不会更新镜像或用户配置。若面板保留了旧的 `10001:10001` 用户覆盖值，需要将其清空或改为 `0:0`。

root 运行会扩大进程被攻破后的影响范围：只挂载专用数据目录，不要开启特权模式或挂载 Docker socket、宿主机根目录。root 也不能修复只读挂载、错误路径或文件系统策略限制。若自行覆盖为非 root 用户，需要自行确保数据目录、数据库及 WAL 文件均可读写。

首次使用空数据库启动时，查看日志取得本次进程生成的一次性初始化码：

```sh
docker logs dcomic-server
```

在浏览器访问 `http://SERVER_IP:8080`，服务会自动跳转到 `http://SERVER_IP:8080/dashboard`。这是服务端自带的独立 Web 管理后台，不需要安装或打开 DComic App。首次访问按页面提示输入初始化码并设置应用管理员 `root` 的密码。`root` 是 Dashboard 账户，不是容器的操作系统用户。初始化完成后不能再次创建管理员；挂载已初始化数据库时会直接进入正常登录流程，不会生成或要求初始化码。重启尚未初始化的服务会生成新的初始化码，旧码随即失效。

密码长度必须为 12–72 个 UTF-8 字节。服务不提供公开注册；初始化后在网页后台查看用户、设备和同步数据统计，创建或禁用用户、重置用户密码及撤销设备会话。DComic App 仅是同步客户端，不参与服务器初始化或管理。

HTTP 不加密初始化码、密码、令牌或同步数据，仅应在可信网络使用；公网访问建议采用下文的 HTTPS 反向代理。

### 标签策略

每次发布都会生成当前引用标签和不可变的完整提交标签 `sha-<完整 Git SHA>`：

- `develop` 分支发布 `develop`，不更新 `latest`。
- `master` 分支发布 `master` 和 `latest`；`latest` 仅跟随 `master` 的最近一次成功发布。
- Git tag（例如 `v2.5.4`）发布同名标签。
- 从其他分支手动运行时发布该分支标签。
- Git tag 或非 `master` 分支的手动发布不会覆盖 `latest`；名为 `latest` 的 Git tag 不生成同名镜像标签，仅生成 SHA 标签。

需要可复现部署时，应固定版本标签或 `sha-<完整 Git SHA>`，不要使用会移动的 `latest`。

公开 Docker Hub 仓库可匿名拉取。若仓库设为私有，部署机器需先使用有该仓库读取权限的 Docker Hub 账户和只读访问令牌登录：

```sh
docker login docker.io -u <Docker Hub 用户名>
```

不要把用于 CI 发布的写入令牌分发到部署机器。

## 数据持久化、备份与升级

命名卷 `dcomic-data` 独立于容器存在；删除或替换容器不会删除数据库。不要执行 `docker volume rm dcomic-data`，也不要在未备份时删除该卷。

SQLite 使用 WAL。服务运行时不能只复制 `/data/dcomic.db`，否则可能遗漏尚在 WAL 中的已提交数据。备份时先停止容器，再复制完整 `/data` 目录（包括可能残留的 WAL），然后启动服务：

```sh
mkdir -p backups
docker stop dcomic-server
docker cp dcomic-server:/data "./backups/dcomic-$(date +%Y%m%d-%H%M%S)"
docker start dcomic-server
```

如需不停机备份，必须使用 SQLite online backup API，而不是直接复制活跃的数据库文件。备份包含用户及同步数据，应限制访问权限。恢复时保持服务停止，先保留当前 `/data` 的回滚副本，再完整恢复同一次备份的目录；若备份包含 WAL，必须一并恢复，不能混入旧数据库的 WAL/SHM 文件。确保目录及数据库文件可由实际运行用户读写后再启动；默认运行用户为 `0:0`。

升级前先备份，然后拉取目标标签并用同一个命名卷重建容器：

```sh
docker pull hanerx/dcomic_server:TAG
docker stop dcomic-server
docker rm dcomic-server
docker run -d --name dcomic-server --restart unless-stopped -p 8080:8080 -v dcomic-data:/data hanerx/dcomic_server:TAG
```

## 可选 HTTPS 反向代理

公网生产环境建议由现有反向代理终止 HTTPS；镜像不捆绑额外代理服务。此时设置精确的外部 HTTPS origin，并只把容器端口发布到代理可访问的宿主机回环地址：

```sh
docker run -d --name dcomic-server --restart unless-stopped \
  -p 127.0.0.1:8080:8080 \
  -e DCOMIC_PUBLIC_URL=https://sync.example.com \
  -v dcomic-data:/data \
  hanerx/dcomic_server:TAG
```

代理必须保留公开 `Host`，原样转发 API 路径，为 `/api/v1/events` 允许长连接并关闭响应缓冲，同时把公开 HTTP 重定向到 HTTPS。服务不会信任 `Forwarded` 或 `X-Forwarded-*`；Host、Origin 和安全 Cookie 策略由 `DCOMIC_PUBLIC_URL` 决定。

## GitHub Actions 发布配置

工作流 [`.github/workflows/server-docker.yml`](../.github/workflows/server-docker.yml) 在以下情况发布镜像：

- `develop` 或 `master` 分支中的 `server/**` 或工作流文件发生变更；
- 推送任意 Git tag；
- 从 GitHub Actions 页面手动运行。

工作流一次构建 `linux/amd64`、`linux/arm64` 双架构镜像，同时推送到 `docker.io/hanerx/dcomic_server` 和 `ghcr.io/hanerx/dcomic_server`。Docker Hub 发布需要配置两个 Actions secrets：

1. 在 Docker Hub 的账户设置中创建 Personal Access Token，授予 **Read & Write**，不要授予删除权限。
2. 在 GitHub 仓库打开 **Settings → Secrets and variables → Actions → New repository secret**。
3. 新建 `DOCKER_HUB_USERNAME`，值填写 `hanerx`。
4. 新建 `DOCKER_HUB_TOKEN`，值填写上一步生成的令牌。

两个 secret 都不要写入仓库、镜像或部署命令。首次发布前应确认 Docker Hub 中已存在 `hanerx/dcomic_server`，并按需要设置为公开或私有。

GHCR 使用 GitHub 自动提供的 `GITHUB_TOKEN`，工作流已声明 `packages: write`，无需额外配置 Secret。镜像的 `org.opencontainers.image.source` 标签指向当前 GitHub 仓库，配合仓库令牌发布以关联仓库的 **Packages**。

首次发布：提交并推送工作流后，在 **Actions → Server Docker Image → Run workflow** 选择 `master` 发布 `latest`，或选择 `develop` 发布开发标签。成功后检查仓库右侧的 **Packages**：

- 新建 GHCR 包默认是 Private；若需公开分发，在包的 **Package settings → Change visibility** 中改为 **Public**。源码仓库公开不代表包自动公开。
- 如果同名包之前已存在但未关联仓库，在包页面使用 **Connect repository** 关联当前仓库，并在 **Package settings → Manage Actions access** 中确认当前仓库具有写入权限，再重新运行工作流。
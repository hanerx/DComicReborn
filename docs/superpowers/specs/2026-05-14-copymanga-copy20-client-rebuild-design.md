# 拷贝漫画 copy20 客户端重建设计

日期：2026-05-14

## 背景

当前 app 的拷贝漫画实现主要集中在 `lib/requests/copymanga/copymanga_request.dart` 和 `lib/providers/models/copymanga/copymanga_source_model.dart`。现有实现仍混合使用旧的官方 app 风格请求头、`network2` 动态域名、`api.mangacopy.com` 以及部分 `/comic2`、`/chapter2` 接口。用户反馈现有接口基本不可用，目标是参照 `D:\AndroidProjects\copymanga-copy20` 的实现恢复拷贝漫画源。

copy20 的核心结构来自 Tachiyomi/Mihon 源扩展：`CopyManga` 持有 `apiUrl`、`apiHeaders`、`preferences` 和 HTTP client；`ConstantsKt` 定义域名池和偏好项；`HeadersKt` 与 `HeadersInterceptor` 统一处理请求头；`VersionUpdaterKt` 更新 app version；`TokenKt` 通过 WebView 读取 `localStorage['user']` 获取 token；DTO 和 mapper 负责将 API 响应转换成漫画、章节、图片和评论模型。

## 目标

重建一个独立的拷贝漫画客户端层，以 copy20 行为为主参照，并有机融入当前 Flutter app：

- 恢复搜索、首页/推荐、最新、排行、分类、详情、章节目录、阅读图片、漫画评论、章节吐槽。
- 恢复账号相关能力，包括 WebView 登录取 token、手动 token 登录、用户信息、收藏状态、收藏/取消、收藏列表、历史记录。
- 支持 copy20 关键设置：API 域名选择、图片分辨率、章节末吐槽页、隐藏默认章节组、登录状态搜索。
- 保留当前 app 的 UI、模型和 Provider 架构，不直接引入 Tachiyomi 类模型。
- 将请求、配置、DTO、映射和 UI 适配拆开，避免继续在 `copymanga_source_model.dart` 中直接拼接接口。

## 非目标

- 不重写整个漫画源框架。
- 不迁移其他源，例如再漫画或 DMZJ。
- 不直接复刻 Tachiyomi 的 RxJava、OkHttp、PreferenceScreen 类型。
- 不在第一轮实现简繁转换标题的完整行为；若需要，保留配置字段和后续接入点。

## 新结构

在 `lib/requests/copymanga/` 下新增以下模块：

- `copymanga_config.dart`：定义 copy20 常量，包括 `baseUrl=https://www.copy20.com`、API 域名池、默认版本 `2.3.0`、默认分辨率 `800`、配置 key、PC User-Agent、`umstring`。
- `copymanga_preferences.dart`：封装 `DatabaseInstance.modelConfigDao` 读写，提供域名索引、token、登录状态、版本号、分辨率、登录搜索、章节吐槽页、隐藏默认章节组等配置。
- `copymanga_headers.dart`：统一构造请求头，负责 `User-Agent`、`authorization: Token <token>`、`source`、`version`、`umstring`、`region`、`host` 等字段。
- `copymanga_dtos.dart`：定义可空安全的响应 DTO，包括 `CopyMangaResultDto<T>`、`CopyMangaListDto<T>`、`CopyMangaWrapperDto`、`CopyMangaDto`、`CopyMangaChapterDto`、`CopyMangaChapterPageListWrapperDto`、`CopyMangaCommentDto` 等。
- `copymanga_mapper.dart`：将 DTO 转换为当前 app 需要的数据结构或中间领域对象，集中处理字段兼容、章节分组、图片重排、分辨率替换。
- `copymanga_client.dart`：唯一实际发请求的客户端，提供稳定方法给 source model 调用。
- `copymanga_request.dart`：保留原类名作为兼容壳，逐步转调 `CopyMangaClient`，降低一次性替换的风险。

`lib/providers/models/copymanga/copymanga_source_model.dart` 继续负责当前 app 的 UI 和业务模型适配，但不再直接维护 API 细节。

## 请求生命周期

1. `CopyMangaClient` 初始化时从 `CopyMangaPreferences` 读取域名索引和版本号。
2. `apiBaseUrl` 从 copy20 域名池计算，默认使用推荐域名；用户设置切换后立即更新客户端状态。
3. 首次请求前尝试调用 `/api/v3/system/appVersion/last` 更新版本号。失败时继续使用默认版本，不阻塞核心阅读链路。
4. 每个请求通过 `CopyMangaHeaders` 生成 headers。未登录时仍发送 `authorization: Token `，与 copy20 行为保持一致。
5. 响应先进入 DTO 层，校验 HTTP 状态码和业务 `code`。可恢复错误返回空列表或 null，不可恢复错误抛给页面现有错误处理。

## 接口映射

核心接口以 copy20 为准：

- 最新：`GET /api/v3/update/newest?limit=30&offset={offset}`
- 推荐/热门：`GET /api/v3/recs?pos=3200102&limit=30&offset={offset}`
- 排行：`GET /api/v3/ranks?type=1&date_type={day|week|month|total}&limit={limit}&offset={offset}`
- 搜索：`GET /api/v3/search/comic`，参数包含 `q`、`q_type`、`limit`、`offset`、`platform=2`。
- 分类列表：优先沿用当前可用的 `/api/v3/theme/comic/count`；若验证失败，再按 copy20 `FiltersKt` 的分类刷新逻辑补齐。
- 分类详情：`GET /api/v3/comics`，支持 `theme`、`author`、`ordering`、`free_type=1`、`limit`、`offset`。
- 漫画详情：`GET /api/v3/comic2/{path_word}`。
- 章节目录：`GET /api/v3/comic/{path_word}/group/{group}/chapters?limit=500&offset={offset}`，按 `total` 分页拉完。
- 章节阅读：`GET /api/v3/comic/{path_word}/chapter2/{chapter_uuid}`。
- 漫画评论：`GET /api/v3/comments?comic_id={uuid}&limit={limit}&offset={offset}`。
- 章节吐槽：`GET /api/v3/roasts?chapter_id={chapter_uuid}&limit={limit}&offset={offset}`。
- 用户信息、收藏、历史优先复用当前 endpoint 名称，但请求头、域名、token 和错误处理迁移到新客户端；验证失败时继续对照 copy20 或网页 localStorage 行为调整。

旧实现中依赖 `/api/v3/system/network2` 的动态域名逻辑不再作为主路径。可以保留设置项作为兼容显示，但内部应迁移为 copy20 的 API 域名选择。

## 章节与图片处理

章节目录按 copy20 的组逻辑处理：

- 默认先读取 `default` 组。
- 详情接口返回其他 groups 时，继续拉取其他章节组。
- “隐藏默认章节组”配置生效时，指定作品跳过 default 组。
- 每组章节按 copy20 行为反转，使阅读顺序与当前 app 章节列表一致。

阅读图片按 copy20 的 `contents + words` 处理：

- `words` 为空时按 `contents` 原顺序返回图片。
- `words` 存在时，将 `contents[i].url` 放到 `words[i]` 指定的位置。
- 如果 `words` 缺失部分索引，补齐未出现的页码，避免页面丢失。
- 分辨率设置用于替换图片 URL 中的分辨率片段，默认 `800`，支持 `1200`、`1500`。
- 图片请求 headers 使用统一 API headers，并保留必要的 `Referer`/UA 兼容。

## WebView 登录

新增 WebView 登录作为拷贝漫画主登录路径：

- 添加 `webview_flutter` 依赖。
- 在 `CopyMangaAccountModel.buildLoginWidget()` 中增加“网页登录获取 Token”入口，并保留手动 token 登录。
- 新增拷贝漫画专用登录页面或内嵌 Widget，加载 `https://www.copy20.com`。
- 用户完成网页登录后，执行 JavaScript 读取 `localStorage['user']`。
- 将返回值按 JSON 解析，提取 token。若字段结构变化，兼容字符串切分作为兜底。
- token 写入 `modelConfigDao(token, copymanga)`，再调用 `CopyMangaClient.getUserInfo()` 校验。
- 校验成功后写入 `isLogin=true`，刷新账号状态；校验失败不保存登录状态，并显示错误。

WebView 登录只用于获取 token，不承担普通浏览器功能。

## Source Model 接入

`CopyMangaComicSourceModel` 仍暴露当前 app 需要的方法：

- `searchComicDetail()` 调用 `CopyMangaClient.search()`，再映射为 `ComicListItemEntity`。
- `getComicDetail()` 调用 `CopyMangaClient.getComicDetail()` 和章节组拉取，生成 `CopyMangaComicDetailModel`。
- `CopyMangaComicChapterDetailModel.pages` 使用新 mapper 输出的有序图片 URL。
- `CopyMangaAccountModel` 调用新客户端处理 token、用户信息、收藏、历史。
- `CopyMangaComicHomepageModel` 调用新客户端处理首页、最新、排行、分类。

原有 `CopyMangaRequestHandler` 保留方法签名，内部转调新客户端，直到 source model 完全迁移完成。

## 设置项

拷贝漫画源设置页新增或调整为 copy20 语义：

- API 域名：列表来自 copy20 的 API 域名池。
- 图片分辨率：`800`、`1200`、`1500`。
- 章节末吐槽页：开启后阅读末尾附加吐槽页；当前 app 已有章节评论 UI，因此第一轮可以只恢复接口，不强制生成图片页。
- 登录状态搜索：开启后搜索请求带 token。
- 隐藏默认章节组：多行文本，每行一个作品名。

现有“使用动态域名”设置迁移为“API 域名选择”或保留但改为打开域名列表入口。

## 错误处理

- 域名不可用：返回明确错误，提示切换 API 域名。
- 版本更新失败：记录日志，继续使用默认版本。
- 未登录访问账号接口：返回空列表或 false，不影响浏览阅读。
- token 失效：账号相关接口失败时清理 `isLogin`，保留 token 文本供用户复制或重试。
- DTO 字段缺失：mapper 使用空字符串、空列表或 null 兜底，并记录日志。
- 章节目录为空：抛出可读错误，提示切换 API 域名或检查章节组设置。

## 验证计划

实现完成后至少验证：

- `flutter analyze` 通过。
- 拷贝漫画搜索返回结果并可进入详情。
- 详情页显示封面、标题、作者、分类、简介、状态、章节组。
- 点击章节能加载图片，图片顺序正确。
- 最新、排行、分类详情能返回列表。
- WebView 登录能读取 token，并成功获取用户信息。
- 手动 token 登录仍可用。
- 收藏列表、收藏/取消、历史记录在登录后可用；若服务端接口变化，需要记录具体失败响应。
- API 域名和分辨率设置能保存并影响后续请求。

## 风险

- copy20 源来自反编译 smali，部分类型和字段需要通过实际响应验证。
- `webview_flutter` 会引入平台侧依赖，Android/iOS 构建需要验证。
- 当前仓库已有未提交源码改动，实施时必须避免覆盖用户现有修改。
- 账号、收藏和历史接口在 copy20 smali 中覆盖不如阅读链路清晰，可能需要边实现边用响应校正。

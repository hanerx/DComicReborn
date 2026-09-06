# DComicReborn
![GitHub Release](https://img.shields.io/github/v/release/hanerx/DComicReborn?style=for-the-badge&link=https%3A%2F%2Fgithub.com%2Fhanerx%2FDComicReborn%2Freleases%2Flatest)
![GitHub Release Date](https://img.shields.io/github/release-date/hanerx/DComicReborn?style=for-the-badge)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/hanerx/DComicReborn/main.yml?style=for-the-badge)
![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/hanerx/DComicReborn/total?style=for-the-badge)


DComic Ver2.0

## 界面与阅读体验

- 界面采用封面优先的轻量书架布局，统一浅色 / 暗色主题、文字层级、留白与圆角；保留主题颜色和 Material 3 偏好设置。
- 首页与收藏的漫画封面使用固定比例，书名预留两行；分类保留随包素材。排行、更新、搜索和历史使用统一图文列表，不拉伸封面。
- 从漫画详情返回收藏时，只按该漫画的本地已查看时间同步“新”角标，不重新请求收藏列表，保留已加载分页和滚动位置。服务端收藏增删、排序及最新章节信息通过下拉刷新同步。
- 详情页使用较小的封面头部，仅渲染一张封面并统一裁切、缩放，图片延伸到标题栏和状态栏背后。标题从封面下部随上滑逐渐缩小、上移到标题栏，封面先收成“小封面＋标题信息”；继续上滑时，封面和信息区滚出屏幕，仅保留标题栏。下拉回到顶部可反向展开。简介支持展开 / 收起，底部提供开始 / 继续阅读；章节强调色表示本地记录的阅读位置，不推断未知的“最新章节”。
- 封面上下使用正文主题底色的渐变，浅色模式为近白色，暗色模式跟随暗色底；缩放时露出的区域也与正文同色。标题和导航按钮使用主题文字色，避免黑色遮罩与下方内容脱节。
- 详情页下拉刷新提示位于导航 / 封面头部之后的内容区，触发高度为 48 个逻辑像素，减少小屏幕所需的下拉距离；下拉不移动导航栏与封面头部，也不遮挡它们，上滑收缩封面的交互保持不变。
- 详情页使用紧凑的 dense 漫画源行，通过底部面板切换源；链条 / 断链图标表示绑定状态，不常驻显示“已绑定”文字。仅当原始源与当前源不同时，在行尾显示无文字的绑定图标：短按绑定或重新绑定，已有绑定时长按同一图标弹出解除绑定确认框。解除仅影响当前源的绑定，保留收藏与阅读记录，刷新后不会自动重新匹配。详情不可用时隐藏封面与章节，错误图标、说明和重试居中展示，下方紧接同一套紧凑切换源与绑定操作；错误仍由界面解析原始异常。搜索失败也提供重试入口，不阻断其他源的结果。
- 侧边栏使用 DComic 矢量标识，点击当前内容源打开选择面板；设置按阅读、内容源、账户、高级与关于分组。未实现的下载、分享等空入口不再伪装成可用功能。
- 阅读画布、翻页手势及章末吐槽行为保持不变；阅读工具栏增加页码与按钮提示，设置面板可滚动。

## 拷贝 / 热辣源

在「设置 → 漫画源设置 → 拷贝漫画」选择线路：

- **漫画与图片 API 线路**：支持拷贝和热辣，默认 `api.copy4000.com`。
- **拷贝评论与吐槽 API 线路**：独立选择拷贝线路。漫画 API 选择热辣（例如 `api.manga2025.com`）后，可使用热辣图片配合拷贝章节吐槽。
- 两站账号独立；切换站点后在账户设置中登录对应账号。切换立即作用于后续请求；已打开的漫画页面需重新进入。本地收藏和阅读记录仍使用原 `copymanga` 源标识，不迁移或删除。
- 混合吐槽依赖两站共享漫画 / 章节 UUID；热辣独有内容可能没有对应的拷贝吐槽。线路是否可访问取决于网络和源站状态。
- 首页下拉刷新会重新请求源站，不沿用尚未过期的本地缓存；请求失败时保留上一次完整内容，恢复网络后可再次下拉刷新。拷贝和热辣分别展示各自提供的首页栏目。
- 在线收藏通过 `ordering=-datetime_updated` 请求服务端按漫画更新时间倒序返回，保留每页 21 条的分页，不对单页数据做本地排序。
- 分类图片使用随包提供的精选日漫彩图与 Comiket 官方目录插画，不再随机选图或请求远程分类 Logo。新增、未匹配及“其他”分类显示本地拷贝应用 Logo；分类列表本身仍需从源站加载。
- 图片位于 `assets/copymanga/categories/`，统一裁切为 256 × 256 PNG；来源、作品名和原图裁切坐标记录在 [素材清单](assets/copymanga/credits.json)。替换素材时同步更新清单；增加分类需在 `CopyMangaComicHomepageModel._categoryArtwork` 中登记 API 的 `path_word`。第三方图片版权归原权利人所有，来源记录不代表转载授权。

访问协议参考 [LittleSurvival/copymanga-copy20 v1.4.84](https://github.com/LittleSurvival/copymanga-copy20/blob/7591be034286bb19bc8380c4ec3fd8622090f175/apk/tachiyomi-zh.copymanga-v1.4.84.apk)，包含独立吐槽线路、站点请求头和章节路径差异；不再依赖旧版 App 的动态域名发现与随机签名。

## 再漫画收藏

- 收藏使用 `/app/v1/bookshelf/updates/list` 书架接口，已读漫画仍保留在列表中；刷新以服务端收藏为准，不与本地旧列表永久合并。
- 书架混合返回漫画和小说时只显示漫画，继续按服务端页码加载；阅读时间和更新角标沿用本地记录。

## 再漫画阅读历史

- 在「历史 → 再漫画」点击右上角图标切换本地 / 云端历史。云端使用 `/app/v1/readingRecord/list`（`source=mh`）分页读取，显示封面、阅读日期和章节；刷新不使用 HTTP 缓存。
- 登录后，进入章节和翻页会通过 `/app/v1/readingRecord/add` 上传章节及实际图片页码；章末吐槽页按最后一张图片计算，不上传越界页码。上传按顺序执行，不阻塞阅读。
- 本地阅读记录仍独立保存；未登录不上传，上传失败不影响本地记录，也不自动批量上传旧历史。
- 历史加载失败会提示检查网络和登录状态，不再静默显示为空；加载下一页失败后不会跳过该页。

## 再漫画自动签到

- 在「设置 → 漫画源设置 → 再漫画」切换“自动签到”（再漫画卡片位于拷贝漫画卡片下方，可能需要下滑），默认开启，选择会保存并在下次启动时恢复。关闭后不再自动签到或领取 VIP 福利，重新开启时会立即检查并尝试完成当天任务。
- 开启时，密码登录、Token 登录，以及应用启动时恢复有效登录态后，自动检查并完成当天签到，无需每天重新输入账号密码。
- 签到状态以服务端当天的 `is_sign` 为准，不使用个人资料缓存；当天已签则跳过，避免跨日后被旧状态阻止签到。
- 会员身份以个人资料的 `isMember` 为准。VIP 会员会额外查询每日福利任务 `16`，仅在任务可领取时领取；已领取则跳过，不领取其他任务奖励。普通签到与 VIP 福利相互独立，一项失败不会阻止另一项。
- 源设置分别显示今日签到、会员身份和 VIP 每日福利状态，区分未登录、未完成、已完成及查询 / 领取失败。进入设置、设置页回到前台和点击刷新按钮时查询最新状态；状态查询本身不会触发签到或领取。
- 签到接口失败不会退出账号；后续登录或启动恢复时会再次检查。退出登录后不再触发签到。
- 不在应用关闭或停留后台时定时签到。

## 章末吐槽页

- 左翻、右翻和纵向阅读都会在每章最后一张漫画后追加一屏「本章吐槽」，无需先打开侧栏。
- 预览沿用当前章节的吐槽顺序；内容超过一屏时裁切显示，底部「显示更多」打开侧栏的评论标签，查看完整内容。
- 吐槽页计入阅读进度条，继续翻动可进入下一章；点击操作沿用漫画页的阅读方向和区域大小：横向左右翻页、纵向上下翻页，中间区域或右上角菜单按钮切换阅读工具栏。「显示更多」和菜单按钮优先响应，滑动翻页照常；吐槽页不支持双击或捏合缩放。没有吐槽时显示「本章暂无吐槽」。
- 吐槽页底色保持铺满，阅读工具栏的圆角不再露出黑底；内容留白与上下工具栏以同一 300ms 缓入缓出动画同步变化，中途切换显隐也不会突然跳动。
- 在「阅读设置 → 外观 → 阅读面板配色」选择跟随应用、纯白、浅色（冷灰）、深色（低饱和蓝黑）或纯黑，统一调整上下工具栏和页末吐槽的背景、文字与图标；立即生效并保存，默认跟随应用，不改变漫画图片或其他页面的主题。
- 阅读器内的设置弹层也会实时跟随配色变化，无需关闭重开，切换时保留当前滚动位置。

## Getting Started

### 工具链

- Flutter stable **3.47.2** / Dart **3.13.2**，CI 使用同一 Flutter 版本。
- 最低系统：Android **7.0 / API 24**、iOS **15**。
- Android：JDK 21、SDK 36、NDK 28.2.13676358；NDK 版本跟随 Flutter。
- AGP **8.13.2**、Gradle **8.14.5**、Kotlin **2.4.0**。保留 Gradle 8.x 是因为 `flutter_downloader 1.12.1` 的构建依赖尚不兼容 Gradle 9；Flutter 的相关弃用警告未被屏蔽。

```sh
flutter pub get
flutter test
flutter build apk --release
```

Windows 上请将 Pub 缓存与项目放在同一盘符，避免 Kotlin 增量编译报 `this and base files have different roots`。例如项目在 D 盘时，在 PowerShell 中设置本次会话：

```powershell
$env:PUB_CACHE = 'D:\Pub\Cache'
# 仅构建 Android 时可跳过 Windows 桌面插件链接，不改变全局 Flutter 配置。
$env:FLUTTER_WINDOWS = 'false'
flutter pub get
flutter build apk --release
```

如果此前已经发生跨盘缓存错误，关闭当前构建后运行 `.\android\gradlew.bat --stop`、`flutter clean`，再执行上述获取依赖和构建命令。Windows 桌面构建不要设置 `FLUTTER_WINDOWS=false`，并需开发者模式或管理员权限来创建插件符号链接。

iOS 原生依赖须在 macOS / Xcode 环境重新解析。本次 Firebase 升级后需运行 `pod update --repo-update`（在 `ios` 目录），再构建；现有 CI 会删除旧 `Podfile.lock` 并重新安装。Windows 上未验证 iOS 和 Windows 桌面产物。

### 依赖清理

已删除无实际调用的 `cupertino_icons`、`direct_select_flutter`、`extended_nested_scroll_view`、`folding_cell`、`flutter_adaptive_scaffold` 和 `open_file`。安装包打开仍使用 `FlutterDownloader.open`。

`sqlite3_flutter_libs` 已由 `sqlite3 3.x` 的原生资产机制取代。`firebase_analytics` 虽无显式 Dart 埋点调用，但会自动采集事件，因此保留。


## ORM Database

- 数据库已迁移到 `floor_community` / `floor_generator_community` **1.1.0**，避免原生成器依赖新版 Dart 已移除的 `_macros`。
- 保持 `dcomic.db`、schema version 5、表结构及迁移链不变；`test/database_upgrade_test.dart` 验证旧库数据读取、更新和重新打开。
- 生成代码：`dart run build_runner build`；持续生成：`dart run build_runner watch`。
- Protobuf 使用 `protoc 36.1` / `protoc_plugin 25.0.0`，从 `lib/protobuf/comic.proto` 和 `lib/protobuf/novel_chapter.proto` 重新生成，兼容 `protobuf 6.0.0`。

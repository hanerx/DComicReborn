# 漫画下载、离线读取与跨源聚合实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框跟踪进度。前置计划通过后开始，不并行修改数据库版本或公共章节接口。

**目标：** 通过公共下载服务下载漫画，缓存命中免网络，完整章节透明本地读取；按默认关闭的实验开关聚合来源，并由默认开启的子项控制跨源复用。

**架构：** ComicDownloadService 将来源章节展开为持久页清单。OfflineChapterResolver 在 BaseComicDetailModel 的统一读取入口先查完整本地章节，缺失才访问原来源。目录聚合不改写下载归属。

**技术栈：** Flutter/Provider、现有 Floor Community/SQLite、第一部分 DownloadService、现有漫画映射与 ChapterRuleMatcher、ImageType.local。

**规格：** `docs/superpowers/specs/2026-10-24-download-and-offline-comics-design.md`。

**前置计划：** `docs/superpowers/plans/2026-10-24-download-engine.md`。

---

## 1. 文件与责任

| 文件 | 动作与职责 |
| --- | --- |
| lib/database/entity/offline_comic.dart | 新增，漫画、章节、页面清单实体和 DAO |
| lib/downloads/comic_download_models.dart | 新增，稳定来源身份、清单与聚合结果 |
| lib/downloads/comic_download_service.dart | 新增，展开章节、提交页面任务、整章完成 |
| lib/downloads/offline_comic_store.dart | 新增，清单事务、失效、查询和删除 |
| lib/downloads/offline_chapter_resolver.dart | 新增，本源优先、跨源匹配、文件检查 |
| lib/providers/models/offline_comic_model.dart | 新增，本地详情/章节模型与实际来源信息 |
| lib/providers/models/comic_source_model.dart | 公共 getChapter 模板、远端入口和 provenance |
| lib/providers/models/copymanga/copymanga_source_model.dart | 远端章节覆盖迁移，保留来源请求头和解析 |
| lib/providers/models/zaimanhua/zaimanhua_source_model.dart | 同一公共契约的远端实现迁移 |
| lib/providers/page_controllers/comic_viewer_page_controller.dart | 本地阅读不等待评论、保持请求章节历史 |
| lib/providers/page_controllers/comic_detail_page_controller.dart | 下载状态观察和章节下载操作 |
| lib/providers/config_provider.dart | 父子开关及保存/刷新 |
| lib/database/setting_sync_contract.dart | 两项下载开关显式 localOnly |
| lib/database/database_common.dart、database_instance.dart、database_common.g.dart | v11->v12 迁移与生成 |
| lib/view/settings/experimental_features_page.dart | 实验父子选项 |
| lib/view/settings/download_setting_page.dart | 区分临时阅读预缓存和永久下载说明 |
| lib/view/comic_pages/comic_detail_page.dart | 选章下载、状态和跨源角标 |
| lib/view/drawer_page/download_page.dart | 扩展漫画库与任务列表 |
| lib/view/downloads/offline_comic_page.dart | 新增，本地目录/下载详情、来源与版本选择 |
| lib/view/downloads/chapter_download_sheet.dart | 新增，选章与已下载角标；不继续膨胀详情页 |
| lib/view/comic_viewer/comic_viewer_page.dart | 显示实际本地来源及在线能力状态 |
| lib/main.dart | 注入漫画服务、本地解析器和设置 |
| test/offline_comic_store_test.dart | 新增，清单与文件状态恢复 |
| test/comic_download_service_test.dart | 新增，整章提交、资源变化、恢复 |
| test/offline_chapter_resolver_test.dart | 新增，优先级、开关、歧义和来源身份 |
| test/download_aggregation_settings_test.dart | 新增，父子保存与生效组合 |
| test/comic_download_pages_test.dart | 新增，必要状态转换和离线入口行为 |
| test/database_upgrade_test.dart、database_sync_policy_test.dart、sync_store_test.dart | 升级与同步边界回归 |
| test/comic_detail_page_controller_test.dart、comic_viewer_comments_test.dart、reader_return_detail_test.dart | 迁移测试模型远端方法并验证阅读行为 |
| test/copymanga_api_test.dart、zaimanhua_api_test.dart | 保持公共 getChapter 调用契约 |
| README.md、RELEASE_NOTES.md | smoke 后更新离线行为、设置和本地边界 |

## 2. 执行前引用清单

2026-10-24 LSP 结果：BaseComicDetailModel.getChapter 调用包括 ComicViewerPageController.loadChapter、两份来源 API 测试；实现包括两个来源及三份测试模型。正式执行时再次查询 references/implementation，因为用户可能新增来源。

不能把所有 getChapter 引用全局重命名为远端方法：调用方必须留在统一入口。只迁移来源和测试模型的远端覆盖，添加公共模板方法。导出接口改动完成后确认所有实现和调用均归属正确。

## 任务 1：持久漫画清单与完整章节状态

- [ ] 新增不可混淆的来源身份：

```dart
typedef ComicKey = ({String sourceId, String comicId});
typedef ChapterKey = ({String sourceId, String comicId, String chapterId});

class OfflinePage {
  final int index;
  final String taskId;
  final String relativePath;
  const OfflinePage({
    required this.index, required this.taskId, required this.relativePath,
  });
}
```

ComicKey/ChapterKey 用于 Dart 接口，数据库以多字段复合键存储，文件目录不能直接拼用户标题。任务 ID 使用规范 JSON 编码身份与清单代次再取 sha256，避免用分隔符拼接造成碰撞；完成前内容变化必须增加 manifestGeneration。

- [ ] OfflineComicEntity 保存 sourceId/comicId/rawTitle/coverRelativePath/remoteCoverUrl/isLongComic；OfflineChapterEntity 保存来源复合键、rawTitle、group、sortIndex、manifestGeneration、state、completedAt；OfflinePageEntity 保存所属复合键、代次、index/taskId/relativePath/expectedBytes。coverRelativePath 与可同步的远端封面字段分开。
- [ ] OfflineComicStore 定义 `saveManifest`、`loadManifest`、`listReadableComics`、`listReadableChapters`、`commitIfComplete`、`invalidateChapter`、`removeChapter`。saveManifest 与页序一次事务落库；commitIfComplete 必须检查非空清单和全部文件任务 completed，不凭完成计数相等判断。
- [ ] 使用真实 SQLite 写失败测试：三页只完成两页时整章不可读，第三页提交后可读；重复完成不产生重复章节；旧代次完成不能覆盖新清单。示例核心断言：

```dart
expect(await store.commitIfComplete(key, generation: 1), isFalse);
expect(await store.listReadableChapters(comic), isEmpty);
await finishPage(2);
expect(await store.commitIfComplete(key, generation: 1), isTrue);
expect((await store.listReadableChapters(comic)).single.chapterId, 'chapter-1');
```

fixture 中 comic=`(sourceId: 'copymanga', comicId: 'book')`，key 在其上增加 chapterId=`chapter-1`；finishPage 在真实任务表提交对应状态并写真实临时图片，而不是只递增计数。

- [ ] v11->v12 建表与索引并注册 Floor DAO；不修改历史、书架、漫画映射主键。新增版本升级回归保留已存在 v11 下载任务、旧用户历史及配置。
- [ ] 编辑阶段结束生成 Floor 文件，运行 `flutter test test/offline_comic_store_test.dart test/database_upgrade_test.dart`。重开数据库并在文件被删除后核对完整状态失效。

## 任务 2：章节下载编排与缓存命中

- [ ] ComicDownloadService 定义 `downloadChapters(detail, selectedChapterIds)`、`pauseChapter(key)`、`resumeChapter(key)`、`cancelChapter(key)`、`removeChapter(key)`，并暴露目录变化流。所有页面工作复用第一部分 DownloadService。
- [ ] 来源章节解析只走新的远端接口，不调用本地优先 getChapter。下载意图先持久化 source/comic/chapter 身份，随后解析并保存全页清单；解析失败保留可重试章节失败状态，不产生空“完成”章节。
- [ ] 每页调用 DownloadService.submit，固定 strategy=single，headers 使用 ImageEntity.imageHeaders，cacheKey 仅在身份可确认时使用实际图片缓存键。页序按来源返回顺序，不能按任务完成顺序。
- [ ] 有效缓存走第一部分 copyValid；多页并发由同一个全局连接预算管理。整章任务进度按完成页数和已知字节汇总，缓存命中计完成量但不计网络速度。
- [ ] 签名 URL 过期时，重新通过来源取得该章页面清单。清单内容/页序变化则以新代次替换并停止旧代次；不能只用“页数相同”判定内容未变。不能可靠识别同一内容时安全重下该章。
- [ ] 已在原生队列的任务可后台继续；尚未解析的来源请求如果需要 UI isolate/登录环境则保留 waiting/失败原因，重启后恢复，不伪称可在任意后台环境初始化所有 Provider。
- [ ] 测试：缓存两页、网络一页完成整章；网络页失败则本地读取整章不命中；源返回重排清单时旧任务完成不能混入；重复点击同一清单不会创建重复传输。
- [ ] `flutter test test/comic_download_service_test.dart` 后，运行本地受控图片 HTTP 服务，经正式服务下载，观察缓存命中页请求为零、页序和文件内容正确。不得只用模拟引擎回声证明缓存优化。

## 任务 3：父子开关及同步隔离

- [ ] ConfigProvider 增加以下读取与异步 setter，默认值采用持久 getOrCreate 约定：

```dart
bool get aggregateDownloads;
bool get reuseDownloadedChaptersAcrossSources;
Future<void> setAggregateDownloads(bool value);
Future<void> setReuseDownloadedChaptersAcrossSources(bool value);
```

配置键分别为 `AggregateDownloads`（false）、`ReuseDownloadedChaptersAcrossSources`（true）。有效条件只在解析器中组合；不要把父开关关闭时子值写成 false。

- [ ] setting_sync_contract 使用现有准确工厂登记：

```dart
_SettingPolicyEntry.exact(
  'AggregateDownloads',
  SettingSyncDefinition.localOnly(reason: 'Download availability is device-local.'),
),
_SettingPolicyEntry.exact(
  'ReuseDownloadedChaptersAcrossSources',
  SettingSyncDefinition.localOnly(reason: 'Downloaded chapter reuse depends on local files.'),
),
```

- [ ] 实验页父开关控制聚合，子项置灰但保留选择；复用现有保存中和失败提示。配置变更通知聚合视图及后续解析，不替换已经打开的章节。
- [ ] 测试完整行为矩阵：默认不跨源；父开关开启后默认可复用；子项 false 时聚合保留但不复用；父开关关闭再开不改变之前子值。断言解析结果与持久值，不只断言默认 getter。
- [ ] 用现有同步测试框架写入任务、漫画清单及两项设置，导出实际同步载荷，确认它们不出现，其他可同步配置仍出现。数据库备份恢复后检查文件，不能恢复虚假的 completed。
- [ ] 运行 `flutter test test/download_aggregation_settings_test.dart test/database_sync_policy_test.dart test/sync_store_test.dart`。

## 任务 4：公共本地解析、来源身份及阅读历史

- [ ] OfflineChapterResolver 定义 `resolve(detail, requestedChapterId)`，返回 `Future<BaseComicChapterDetailModel?>`；null 仅表示没有可用本地章节，不能吞掉全部数据库异常伪装 miss。它依赖 OfflineComicStore、现有漫画映射、现有章节规则和设置快照，不访问远端。
- [ ] 明确身份模型：

```dart
class ChapterProvenance {
  final ChapterKey requested;
  final ChapterKey actual;
  final bool isLocal;
  const ChapterProvenance({
    required this.requested, required this.actual, required this.isLocal,
  });
}
```

BaseComicChapterDetailModel 新增可空 provenance getter（远端默认 null）；本地模型 chapterId 返回请求章节 ID，provenance.actual 保留文件真实来源。内容相关操作不可误用 requested ID。

- [ ] 统一入口采用模板，远端实现全部迁移到 fetchRemoteChapter，迁移时不重命名上层调用方：

```dart
Future<BaseComicChapterDetailModel?> getChapter(String chapterId) async {
  final local = await offlineResolver.resolve(this, chapterId);
  return local ?? await fetchRemoteChapter(chapterId);
}

Future<BaseComicChapterDetailModel?> fetchRemoteChapter(String chapterId);
```

offlineResolver 是 BaseComicDetailModel 从应用级下载运行时获得的公共依赖；测试通过相同依赖注册显式替换，不要求每个来源实现本地逻辑。应用级运行时只注册一个 resolver 并在数据库恢复时重建绑定，未初始化时抛明确状态错误，不隐式退化为关闭下载。

- [ ] 两个正式来源和 LSP 找到的测试覆盖迁移为 fetchRemoteChapter；远端解析逻辑和图像 headers 不改变。直接在来源内部调用 getChapter 的地方重新检查是否应该走远端，避免递归。
- [ ] 解析顺序固定：本源完整版本 -> 父子开关均开时无歧义其他源版本 -> null。先通过漫画映射识别同一作品，再按现有规则匹配章节；同来源一对多、映射冲突和跨组相同数字都不自动命中。
- [ ] 多个明确等价其他来源版本按 completedAt 升序、sourceId、chapterId 排序。查询不覆盖数据；开启聚合只改变视图。打开前检查所有持久文件存在与已记录长度，缺失就事务撤销可读标记。
- [ ] OfflineComicDetailModel 从本地清单构造，chapters 仅包含本地完整章节；getChapter 显式选定实际来源版本，不走跨源 fallback。没有文件时抛可展示的离线缺失错误，不能暗中访问远端详情。摘要、作者等未保存字段用明确的离线 UI，不伪造远端内容。
- [ ] Reader 本地加载不能等待在线评论。ComicViewerPageController 先提交页面和 notify，再单独加载评论；用现有 _chapterLoad 隔离迟到结果。本地评论状态为离线不可用/可主动联网获取；主动获取必须使用 actual 源身份。不得把返回空列表伪装成网络成功。
- [ ] 阅读历史继续使用当前详情和 currentChapter 的请求身份；离线详情采用实际来源身份。写历史封面使用原远端封面或无封面，不把本地绝对路径写入可同步字段；需要在 BaseComicDetailModel 增加明确的 historyCover 契约并迁移调用，而不是屏蔽所有离线阅读历史。
- [ ] 写回归：A 请求/B 文件返回时页面为本地、历史仍为 A、来源标签为 B；本源始终优先；复用关闭返回 A 远端；歧义不命中；本地打开不触发远端详情与评论；迟到评论不覆盖下一章。
- [ ] 运行：

```text
flutter test test/offline_chapter_resolver_test.dart test/comic_viewer_comments_test.dart test/reader_return_detail_test.dart test/copymanga_api_test.dart test/zaimanhua_api_test.dart test/comic_detail_page_controller_test.dart
```

## 任务 5：下载入口、聚合目录与离线阅读 UI

- [ ] comic_detail_page 增加选章下载入口，实际选择面板放 chapter_download_sheet。按现有分组/顺序列章，支持逐章选择和提交选中章节。角标区分本源完整、他源完整、下载中和失败，不把半章显示为已下载。
- [ ] 父开关关闭时他源角标不显示；开启但复用关闭时角标仍显示来源信息，点击阅读依然走本源远端。选择下载即使他源已完成也允许明确下载本源，不能把“可复用”误作禁止下载。
- [ ] download_page 提供“任务”和“已下载漫画”区域。任务显示未完成/失败及控制；漫画库只显示至少一个完整本地章节的漫画。父开关关闭按源分组，开启时依现有映射聚合，不按同名强行合并。
- [ ] offline_comic_page 展示已完成章节和来源；等价多个版本提供明确来源项，点击项进入原阅读器并传本地模型。不要在打开离线目录时创建远端详情模型并 await init。
- [ ] 操作取消和删除有明确语义：取消停止未完成任务；删除先撤销完整标记，再取消关联活动任务、删除仅属于该章的持久文件；不删除阅读缓存、不级联删除其他来源版本。删除失败保留可解释状态，不宣称空间已释放。
- [ ] Reader 显示“本地 · 实际来源”，正常入口的导航和标题仍对应请求目录。设置切换不在阅读中途换文件。文件被外部删除时显示缺失/修复入口，不循环切源。
- [ ] 下载设置页保留原有 readerPrecacheCount，补充临时预缓存与永久下载的区别；它不是下载并发数，不混用现有设置。
- [ ] UI 使用已存在的 _locale 中英文方式和 SettingsPage/SettingsGroup，不新建一套设置框架。
- [ ] 仅为多状态边界增加 widget 回归：聚合父子关闭/开启、部分章节不出现在离线目录、选定版本打开正确源。实际 UI smoke 必须覆盖选章下载、退回详情、跨源角标、下载页、离线翻章、删除后状态；widget 测试不能代替表面验证。

## 任务 6：端到端验证、文档与清理

- [ ] 在所有编辑整合后集中执行：

```text
dart run build_runner build --delete-conflicting-outputs
dart format lib/downloads lib/database/entity/offline_comic.dart lib/providers/models/offline_comic_model.dart lib/view/downloads
flutter analyze
flutter test
flutter build apk --debug
flutter build windows --debug
```

已有非行为测试若因代码搬迁失败，删除其源码/接线断言，而非重写字符串硬编码。真实行为契约保持并更新。

- [ ] 实际运行 `flutter run -d windows`，另在 Android 实际设备运行；使用现有来源完成至少一话下载。缓存复用网络次数用受控服务器验证，真实来源用于确认 headers/认证/图片格式。
- [ ] 断网后从下载列表打开：不发远端详情/评论请求，完整翻页、前后章正确；从正常详情打开未完整章仍走云端。
- [ ] 建立明确 A/B 漫画映射，完整下载 B：父关不聚合；父开子关有角标但正常入口读 A；父子开读 B 本地并显示实际来源；再完整下载 A 后优先 A。
- [ ] 杀进程后恢复下载；校验失败不变成可读；更新包校验后安装；清图片缓存不删除下载；删除持久文件撤销完整标记；同步导出不含任务、路径或本地设置。
- [ ] 在 macOS/iOS 宿主验证平台实际可执行行为。缺设备/宿主是明确验收阻塞，不把 Windows 测试当作移动端后台证据。
- [ ] smoke 后更新 README/RELEASE_NOTES，清除探针与临时文件，移除旧插件、旧回调及所有过渡别名。请求代码审查；用户未要求时不自动提交其他工作区变更。

## 规格覆盖矩阵

| 规格部分 | 实施任务 |
| --- | --- |
| 1 范围、3 现有集成、4 引擎选型 | 通用计划任务 1、5、6 |
| 2 父子设置与入口 | 本计划任务 3、5 |
| 5 分层、6 状态与提交 | 通用计划任务 2、3、4 |
| 7 缓存 | 通用计划任务 3，本计划任务 2 |
| 8 校验与更新包 | 通用计划任务 3、5 |
| 9 分块/续传/链接失效 | 通用计划任务 1、4，本计划任务 2 |
| 10 后台与通知 | 通用计划任务 1、4、6 |
| 11 本地目录与聚合 | 本计划任务 1、4、5 |
| 12 公共本地读取与身份 | 本计划任务 4 |
| 13 本地存储、同步及备份边界 | 本计划任务 1、3、4、6 |
| 14 实测验收 | 两份计划各自任务 6 |

## 完成定义

两份计划都通过用户需求对应的行为验收才能宣布整体完成。每份计划可单独审查，但通用下载完成不等于漫画下载完成；只通过测试不等于后台下载和安装实机通过。所有未执行平台验证明确列出，不降低承诺、不假报结果。

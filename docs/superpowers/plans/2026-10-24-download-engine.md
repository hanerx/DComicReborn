# 通用下载与更新迁移实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框跟踪进度。与另一计划共享数据库和启动入口时，由同一集成负责人顺序修改。

**目标：** 建立可恢复、支持缓存和校验的通用下载服务，以真实更新包下载替换旧链路。

**架构：** 业务任务与引擎任务分离，持久意图先于入队。background_downloader 负责传输；业务服务负责缓存、校验、文件提交和恢复。完成状态不依赖页面生命周期。

**技术栈：** Flutter/Dart、background_downloader（通过准入后锁定发布版本）、Floor Community/SQLite、flutter_cache_manager、现有 crypto。

**规格：** `docs/superpowers/specs/2026-10-24-download-and-offline-comics-design.md`。

---

## 执行约束与交付顺序

本计划先于 `2026-10-24-offline-comics.md`。不因平台限制删除分块、恢复或校验要求；实机准入失败要保留证据并重新选型。平台不具备相同通知能力不等于功能实现失败，但不得宣称同等保活。

用户已批准规格；本文件是执行计划，不是已经执行的记录。下列结果均是预期，不是实测。

数据库当前 v10，本计划升到 v11；漫画计划再升到 v12。执行前如用户已有迁移，顺延版本而不覆盖。生成文件只通过生成器更新。修改导出符号前重新查询 LSP 引用。

不为验证改掉线上服务器，不重复确认用户已报告的安装失败。新增测试限于恢复、完整性、缓存边界等用户可见风险；引擎验证使用真实 HTTP 传输。阶段内先完成编辑再集中生成、检查；红绿回归在所对应修复边界运行，不让并行工作者各跑全量检查。

## 文件布局

| 文件 | 动作与职责 |
| --- | --- |
| lib/downloads/download_models.dart | 新增，业务请求、状态、错误及校验配置 |
| lib/downloads/download_store.dart | 新增，持久状态、执行代次及引擎映射 |
| lib/database/entity/download_task.dart | 新增，Floor entity/DAO，沿用 entity 文件内 DAO 习惯 |
| lib/downloads/download_engine.dart | 新增，插件适配及原生任务对账 |
| lib/downloads/download_files.dart | 新增，临时文件、摘要、原子改名、相对路径 |
| lib/downloads/download_cache.dart | 新增，现有图片缓存只读适配及复制 |
| lib/downloads/download_service.dart | 新增，统一提交、控制、恢复、事件 |
| lib/providers/download_provider.dart | 替换旧回调管理，成为服务状态的 UI facade |
| lib/downloads/update_download.dart | 新增，发布附件解析、校验要求和安装动作 |
| lib/providers/version_provider.dart | 改为提交通用更新下载，不再直接引用旧插件 |
| lib/main.dart | 初始化服务并注入 facade；应用重启启动 reconcile |
| lib/database/database_common.dart、database_instance.dart | v11 注册与迁移 |
| lib/database/database_common.g.dart | 生成，不手改 |
| pubspec.yaml、pubspec.lock | 依赖切换 |
| android/app/src/main/AndroidManifest.xml | 新插件权限和服务配置，移除旧插件 provider |
| ios/Runner/AppDelegate.swift、Info.plist | 按锁定版要求配置通知和后台；不保留旧注册 |
| macos/Runner/DebugProfile.entitlements、Release.entitlements | 保留并检查网络权限 |
| lib/view/drawer_page/download_page.dart | 新增，文件任务管理入口，下一计划扩展漫画区域 |
| lib/view/components/left_drawer.dart | 增加下载管理导航 |
| test/download_store_test.dart | 新增，真实临时 SQLite 恢复与代次测试 |
| test/download_files_test.dart | 新增，真实文件校验与提交中断测试 |
| test/download_cache_test.dart | 新增，缓存有效性和副本独立性 |
| test/download_service_test.dart | 新增，服务恢复、取消竞争及完成门控 |
| test/version_provider_test.dart | 更新契约，并覆盖附件校验数据的解析 |
| README.md、RELEASE_NOTES.md | 实测后更新行为与平台限制 |

测试支持代码放 `test/support/download_harness.dart`：临时目录、内存/临时 SQLite、可控引擎事件源；销毁时关闭所有句柄。它不替代原生准入验证。

## 任务 1：锁定引擎并完成准入验证

**文件：** 先在 `.dart_tool/download_probe/` 创建一次性独立 Flutter 工程与 HTTP 服务；通过后才修改 pubspec 和平台配置。

- [ ] 查询发布版 9.6.4 的源码/文档、最低系统版本及依赖，确认 ParallelDownloadTask、恢复和通知实际 API；禁止凭 main 文档猜 API。
- [ ] 创建独立探针，不在正式代码先搭空实现：

```text
flutter create --platforms=android,ios,windows,macos .dart_tool/download_probe
```

- [ ] 探针 HTTP 服务用 Dart HttpServer 绑定测试设备可达地址，提供同一确定性字节流、固定强 ETag、正确 HEAD/206/Content-Range；提供可切换的“忽略 Range 返回 200”“中途断开”“ETag 变化”“摘要错误”端点。文件内容按 `byte[i] = i % 251` 生成；原文件用 sha256 流式计算作为预期值。记录 Range 请求次数与实际传输字节数。
- [ ] 探针 UI 实际使用普通 DownloadTask 和 ParallelDownloadTask，显示 task ID、完成状态和最终摘要；运行：

```text
flutter devices
flutter run -d windows
```

以上运行命令使用工具 cwd=`.dart_tool/download_probe`。Android 使用 `flutter devices` 返回的实际设备 ID 替换 `-d windows` 的设备参数，在同一目录执行；不把设备发现结果写死在计划中。

- [ ] Android 执行切后台、暂停恢复、断网恢复、进程终止后重启；明确区分普通进程终止与系统设置中的强制停止。普通及分块最终摘要必须一致；并行用真实 Range 日志证明，不只看 UI 百分比。
- [ ] 验证通知分组、权限拒绝、取消和完成后文件打开；关闭插件“传输完立即打开文件”行为，安装入口必须由业务校验控制。
- [ ] 记录每个平台可执行结果与缺失环境；无 Android 设备时不把后台能力标为通过。可继续编写平台无关模块，但不得跨过最终产品验收。
- [ ] 准入通过后锁定版本，执行 `flutter pub get`；只按发布版实际要求更新平台文件。随后删掉旧 flutter_downloader 依赖及旧平台专属配置，迁移与正式调用方同阶段完成，不能留下双引擎常态。

## 任务 2：固定业务契约及持久任务

**文件：** models/store/entity、database_common/instance、download_store_test。

- [ ] 定义以下稳定值，不向调用方泄漏插件 Task：

```dart
enum DownloadState { queued, running, paused, verifying, completed, failed, canceled }
enum TransferStrategy { single, parallel }

class DownloadIntegrity {
  final int? expectedBytes;
  final String? sha256Hex;
  const DownloadIntegrity({this.expectedBytes, this.sha256Hex});
}

class DownloadRequest {
  final String id;
  final Uri url;
  final Map<String, String> headers;
  final String relativePath;
  final String group;
  final DownloadIntegrity integrity;
  final TransferStrategy strategy;
  final int chunks;
  final String? cacheKey;
  const DownloadRequest({
    required this.id, required this.url, required this.relativePath,
    required this.group, this.headers = const {},
    this.integrity = const DownloadIntegrity(),
    this.strategy = TransferStrategy.single, this.chunks = 1, this.cacheKey,
  });
}
```

新增 DownloadRecord 保存 request、state、generation、engineTaskId、bytesReceived、totalBytes、error、createdAt、completedAt。持久化使用标量与 JSON headers；URL/token 不写日志，不进入同步。所有目标路径必须为下载根目录内的相对路径。

- [ ] DownloadStore 定义 `insert(request)`、`get(id)`、`list()`、`transition(id, generation, from, to)`、`bindEngine(id, generation, engineTaskId)`、`invalidate(id, reason)`。transition 在事务内检查当前状态及执行代次并返回 bool；cancel 增加代次使迟到事件失效。主键为业务 id。
- [ ] 按以下精确行为编写真实 SQLite 测试；测试 fixture `openStore(path)` 通过真实数据库打开，不能用 Map 假装持久化：

```dart
test('cancelled generation cannot be completed by a late event', () async {
  final store = await openStore(databasePath);
  await store.insert(request);
  final before = await store.get(request.id);
  await store.cancel(request.id);
  final accepted = await store.transition(
    request.id, before!.generation,
    DownloadState.running, DownloadState.completed,
  );
  expect(accepted, isFalse);
  expect((await store.get(request.id))!.state, DownloadState.canceled);
});
```

fixture 中 request 为 http://127.0.0.1/file，relativePath=`files/sample.bin`，group=`files`，id=`sample`。另测关闭并重新打开数据库后 queued/paused 意图、请求头和代次均保留。实现 cancel 为 store 的状态操作，更新事务必须与上述 transition 共享规则。

- [ ] 运行 `flutter test test/download_store_test.dart`，观察目标断言失败后实现 DAO/事务。v10->v11 增加任务表和索引，不触碰既有用户数据；Floor 注解新装结构必须与 migration 一致。
- [ ] 同一编辑阶段结束执行 `dart run build_runner build --delete-conflicting-outputs`，然后运行 store 和已有 database_upgrade_test，验证新装及旧库升级均可保存/恢复业务任务。

## 任务 3：实现文件校验、缓存复用与可重复提交

**文件：** download_files/cache，两个对应测试文件。

- [ ] DownloadFiles 注入根目录；定义 `stagingPath(id, generation)`、`resolve(relativePath)`、`verify(file, integrity)`、`commit(staging, relativePath)`。对越界路径拒绝操作；改名位于同一文件系统。用 streaming hash：

```dart
final actualBytes = await file.length();
if (integrity.expectedBytes != null && actualBytes != integrity.expectedBytes) {
  throw const FormatException('download length mismatch');
}
if (integrity.sha256Hex != null) {
  final actual = (await sha256.bind(file.openRead()).first).toString();
  if (actual != integrity.sha256Hex!.toLowerCase()) {
    throw const FormatException('download sha256 mismatch');
  }
}
```

- [ ] 先写失败测试：真实文件 `abc`，预期 SHA-256 为 `ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad` 时成功；改成 `abd` 时拒绝且目标文件不存在。测试只断言结果文件及业务失败，不锁定报错措辞。
- [ ] DownloadCache 定义 `copyValid(request, staging)` 返回 bool。注入 BaseCacheManager 和时间函数，检查 cacheKey 与请求身份、validTill、文件存在。无法验证受保护资源身份则 miss，不剥离 URL 参数。
- [ ] 复制使用文件流或 File.copy，不读全文件到内存。过期、复制途中消失均按 miss；不得移动缓存。测试复制后删除源缓存，副本字节仍与原图一致；过期缓存不成为 completed。
- [ ] 测试校验成功改名后但 DB 提交前模拟中断：重新启动用最终文件核验修复状态；目标已存在时不可直接信任旧文件，必须按任务描述核验。测试取消后的 staging 不能被迟到校验提交。
- [ ] 运行 `flutter test test/download_files_test.dart test/download_cache_test.dart`。缓存命中零 HTTP 请求另由本地服务 smoke 证明，不把方法调用计数当作全部证据。

## 任务 4：接入引擎、恢复调度和通知

**文件：** download_engine/service/provider、main、download_service_test。

- [ ] DownloadEngine 对外提供 `enqueue(request, stagingPath, generation)`、`pause(engineId)`、`resume(engineId)`、`cancel(engineId)`、`snapshot()` 和更新流。更新包含业务 ID、代次、引擎 ID、状态、字节及最终临时文件。插件专有 enum 在此转换。
- [ ] DownloadService 接口固定为 `submit(request)`、`pause(id)`、`resume(id)`、`cancel(id)`、`remove(id)`、`reconcile()`、`watch()`；submit 返回业务 ID，watch 提供 DownloadRecord 列表。同一 ID 的相同请求去重，不覆盖不同内容请求。
- [ ] 实现顺序：事务保存 queued -> 缓存查询/复制 -> miss 才 enqueue -> 持久 engine ID -> 原生事件 -> verifying -> 校验 -> 最终改名 -> completed。网络和文件操作在事务外；持久状态判断在事务内；每个异步阶段前后检查 generation。
- [ ] 完成通知与可打开动作由业务 completed 驱动；插件传输通知到达 100% 不意味着可用。若校验延后至重启，应用内显示 verifying，不能自动安装。
- [ ] 恢复矩阵逐项实现：

```text
queued + no native task       => safely enqueue once
running + native active      => attach and reconcile progress
running + native complete    => verify staged file
verifying + final file       => verify and commit business completion
paused                       => retain until explicit resume
canceled                     => cancel orphan native task, never resurrect
completed + file missing     => invalidate local availability
```

入队成功但映射尚未保存的窗口，通过业务 ID/代次写入引擎 metadata 查找现存任务，不能再重复入队。

- [ ] 设置原生并发限额，建议初始总连接预算 4、每主机 2；单大文件分块数受同一预算约束。图片由下一计划选择 single。Range 不支持时降级，资源版本变化安全重下。并发上限作为本地配置，不能通过 Dart 内存队列承担唯一持久调度。
- [ ] 对系统中断和用户暂停区分原因；resume 无法恢复部分文件时重新下载并报告状态。不要无限重试认证失败。临时 URL 重新解析入口留在业务请求更新流程，由漫画计划实现来源刷新，不加空回调。
- [ ] 保留 DownloadProvider 作为 UI facade，但删除旧 registerDownloadCallback/onDownloadCallback/ReceivePort 逻辑；VersionProvider 与新页面都观察同一服务。main 先创建服务再注入调用方；初始化失败可见，不能靠无限空进度掩盖。
- [ ] 测试验证取消迟到事件、两次完成事件、入队窗口重启、验证中重启、已暂停不自启。运行 `flutter test test/download_service_test.dart`，然后用任务 1 的真实服务器运行正式服务路径，核对最终文件字节。

## 任务 5：迁移更新下载并提供通用管理界面

**文件：** update_download、version_provider、download_page、left_drawer、version_provider_test。

- [ ] ReleaseInfo 附件信息携带 `expectedBytes`、`sha256Hex`，从 GitHub `size` 和 `digest` 解析；摘要格式不是 sha256 或长度错误按无法校验处理。Android 选 APK、Windows 优先 setup.exe、macOS 选 universal.dmg；iOS 保持未签名 IPA 限制说明，不声称可直接安装。
- [ ] 更新按钮先以页面外的服务引用建立请求，再关闭弹窗；不要在 pop 后获取 Provider。使用唯一版本/平台文件路径，不再复用无校验的固定 app.apk。
- [ ] 每次安装前确认业务状态 completed 且文件仍存在；摘要失败或缺失不开放安装，提供发布页。下载/安装分别展示失败原因，平台打开调用失败不能改写为下载失败。
- [ ] 下载管理显示普通任务名称、阶段、字节/未知总量、暂停继续取消、失败原因与已验证文件打开；实现 Drawer 入口，使用现有 NavigatorProvider 导航。UI 观察服务，不拥有任务生命周期。
- [ ] 复用现有设置组件和中英文文案方式，不顺便重构导航。首阶段不增加漫画假列表；漫画功能由下一计划真实接入。
- [ ] 更新 release 解析契约测试，覆盖缺少摘要、错误摘要格式和 Windows 附件；删除若存在的“源码含插件调用”类测试，不换新字符串继续锁实现。
- [ ] 运行 `flutter test test/version_provider_test.dart test/download_service_test.dart`；在实际 UI 点击下载、关弹窗、查看任务、校验后打开。Android 通过系统安装结果确认包是否可安装；若失败收集包摘要和安装器错误，不宣布已修复损坏问题。

## 任务 6：集中验证与交付第一部分

- [ ] 同阶段只执行一次生成器、格式、静态分析和全套测试，修复时只重跑受影响验证：

```text
dart run build_runner build --delete-conflicting-outputs
dart format lib/downloads lib/providers/download_provider.dart lib/providers/version_provider.dart lib/database/entity/download_task.dart lib/view/drawer_page/download_page.dart
flutter analyze
flutter test
flutter build apk --debug
flutter build windows --debug
```

平台代码或设置变化在对应宿主环境验证；Windows 不能证明 iOS/macOS 构建成功。

- [ ] 实际程序 smoke：缓存命中零网络请求、Range 分块、暂停恢复、进程恢复、错误摘要不可打开、更新安装、Windows 下载入口。保存观察证据，未具备环境的项列为验收阻塞，不用单测代替。
- [ ] smoke 后更新 README 与 RELEASE_NOTES 的真实能力和限制，删除探针工程及临时服务器，保留能发现消费者可见问题的测试。
- [ ] 请求代码审查，重点检查事务窗口、取消竞争、文件路径、凭据泄露、旧插件残留。只在用户要求提交时创建提交，不混入用户其他改动。

## 与漫画计划的交接契约

漫画计划只调用 DownloadService/Store 公共接口：用稳定业务 ID 提交每页 single 下载，观察 completed 并形成整章可读状态。DownloadRequest.cacheKey 用于明确身份的缓存资源；通用服务不导入 ComicSourceModel。本阶段 v11 已有下载任务表；下一阶段以 v12 添加漫画清单表，不重做下载引擎。

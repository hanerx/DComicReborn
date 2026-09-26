# 拷贝漫画 copy20 客户端重建 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 以 copy20 的结构和接口行为为准，重建当前 app 的拷贝漫画客户端，使浏览、阅读、账号、收藏、评论和配置能力恢复可用。

**架构：** 在 `lib/requests/copymanga/` 下新增独立客户端层，拆分配置、偏好、headers、DTO、mapper、网络 client。`copymanga_source_model.dart` 只做当前 app 的 UI/业务模型适配，旧 `CopyMangaRequestHandler` 保留为兼容壳并转调新客户端。

**技术栈：** Flutter/Dart、Dio、Floor 配置存储、Provider、`webview_flutter`、`flutter_test`。

---

## 文件结构

- 创建：`lib/requests/copymanga/copymanga_config.dart`
  - copy20 常量：域名池、默认版本、默认分辨率、User-Agent、base URL、配置 key。
- 创建：`lib/requests/copymanga/copymanga_headers.dart`
  - 纯 Dart header 构造器，方便单测。
- 创建：`lib/requests/copymanga/copymanga_dtos.dart`
  - API 响应 DTO 和 `fromJson` 方法。
- 创建：`lib/requests/copymanga/copymanga_mapper.dart`
  - DTO 到中间领域对象的映射，包含章节图片排序和分辨率替换。
- 创建：`lib/requests/copymanga/copymanga_preferences.dart`
  - 当前 app 数据库配置读写封装。
- 创建：`lib/requests/copymanga/copymanga_client.dart`
  - 实际 Dio 请求入口。
- 修改：`lib/requests/copymanga/copymanga_request.dart`
  - 保留旧 handler API，内部转调 `CopyMangaClient`。
- 修改：`lib/providers/models/copymanga/copymanga_source_model.dart`
  - 从旧 request/raw map 解析迁移到新客户端和 mapper。
- 创建：`lib/view/settings/copymanga_web_login_page.dart`
  - WebView 登录页，读取 `localStorage['user']`。
- 修改：`pubspec.yaml`
  - 添加 `webview_flutter` 依赖。
- 修改：`lib/l10n/intl_en.arb`、`lib/l10n/intl_zh.arb`
  - 添加 WebView 登录和 copy20 设置项文本。
- 创建：`test/requests/copymanga/copymanga_headers_test.dart`
- 创建：`test/requests/copymanga/copymanga_dtos_test.dart`
- 创建：`test/requests/copymanga/copymanga_mapper_test.dart`

## 任务 1：配置与 Header 基础层

**文件：**
- 创建：`lib/requests/copymanga/copymanga_config.dart`
- 创建：`lib/requests/copymanga/copymanga_headers.dart`
- 测试：`test/requests/copymanga/copymanga_headers_test.dart`

- [ ] **步骤 1：编写 header 单测**

在 `test/requests/copymanga/copymanga_headers_test.dart` 写入：

```dart
import 'package:dcomic/requests/copymanga/copymanga_config.dart';
import 'package:dcomic/requests/copymanga/copymanga_headers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds anonymous copy20 headers', () {
    final headers = CopyMangaHeaders.build(
      apiBaseUrl: 'https://api.mangacopy.com',
      appVersion: CopyMangaConfig.defaultAppVersion,
    );

    expect(headers['User-Agent'], CopyMangaConfig.pcUserAgent);
    expect(headers['authorization'], 'Token ');
    expect(headers['source'], '');
    expect(headers['version'], CopyMangaConfig.defaultAppVersion);
    expect(headers['umstring'], CopyMangaConfig.umstring);
    expect(headers['host'], 'api.mangacopy.com');
  });

  test('builds authenticated copy20 headers', () {
    final headers = CopyMangaHeaders.build(
      apiBaseUrl: 'https://www.copy20.com',
      appVersion: '2.4.0',
      token: 'abc',
    );

    expect(headers['authorization'], 'Token abc');
    expect(headers['version'], '2.4.0');
    expect(headers['host'], 'www.copy20.com');
  });
}
```

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/requests/copymanga/copymanga_headers_test.dart`

预期：FAIL，提示 `copymanga_config.dart` 或 `copymanga_headers.dart` 不存在。

- [ ] **步骤 3：实现配置常量**

创建 `lib/requests/copymanga/copymanga_config.dart`：

```dart
class CopyMangaConfig {
  static const baseUrl = 'https://www.copy20.com';
  static const apiPrefix = 'https://';
  static const defaultAppVersion = '2.3.0';
  static const defaultResolution = '800';
  static const umstring = 'b4c89ca4104ea9a97750314d791520ac';
  static const pcUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36';

  static const apiDomains = <String>[
    'api.mangacopy.com',
    'api.copymanga.tv',
    'api.copymanga.org',
    'api.copymanga.info',
    'api.copymanga.net',
    'api.xsskc.com',
    'api.copymanga.site',
    'www.copy20.com',
  ];

  static const resolutions = <String>['800', '1200', '1500'];

  static const sourceId = 'copymanga';
  static const tokenKey = 'token';
  static const isLoginKey = 'isLogin';
  static const domainIndexKey = 'domain';
  static const appVersionKey = 'appVersion';
  static const resolutionKey = 'resolution';
  static const loginSearchKey = 'loginSearch2';
  static const chapterCommentsKey = 'chapterComments';
  static const hideDefaultChapterGroupKey = 'hideDefaultChapterGroup';

  static String apiBaseUrlForIndex(int index) {
    final safeIndex = index >= 0 && index < apiDomains.length ? index : 0;
    return '$apiPrefix${apiDomains[safeIndex]}';
  }
}
```

- [ ] **步骤 4：实现 header 构造器**

创建 `lib/requests/copymanga/copymanga_headers.dart`：

```dart
import 'package:dcomic/requests/copymanga/copymanga_config.dart';

class CopyMangaHeaders {
  static Map<String, dynamic> build({
    required String apiBaseUrl,
    required String appVersion,
    String? token,
    bool overseasCdn = false,
  }) {
    return {
      'User-Agent': CopyMangaConfig.pcUserAgent,
      'authorization': 'Token ${token ?? ''}',
      'source': '',
      'version': appVersion,
      'umstring': CopyMangaConfig.umstring,
      'region': overseasCdn ? '0' : '1',
      'host': Uri.parse(apiBaseUrl).host,
      'accept': 'application/json',
    };
  }
}
```

- [ ] **步骤 5：运行测试确认通过**

运行：`flutter test test/requests/copymanga/copymanga_headers_test.dart`

预期：PASS。

- [ ] **步骤 6：Commit**

运行：

```bash
git add lib/requests/copymanga/copymanga_config.dart lib/requests/copymanga/copymanga_headers.dart test/requests/copymanga/copymanga_headers_test.dart
git commit -m "feat: add copymanga copy20 header config"
```

## 任务 2：DTO 与响应解析

**文件：**
- 创建：`lib/requests/copymanga/copymanga_dtos.dart`
- 测试：`test/requests/copymanga/copymanga_dtos_test.dart`

- [ ] **步骤 1：编写 DTO 单测**

在 `test/requests/copymanga/copymanga_dtos_test.dart` 写入：

```dart
import 'package:dcomic/requests/copymanga/copymanga_dtos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses manga detail wrapper', () {
    final wrapper = CopyMangaResultDto.fromJson(
      {
        'code': 200,
        'results': {
          'comic': {
            'uuid': 'comic-uuid',
            'path_word': 'one-piece',
            'name': 'One Piece',
            'cover': 'https://img/cover.jpg',
            'brief': 'brief',
            'author': [
              {'name': 'Oda', 'path_word': 'oda'}
            ],
            'theme': [
              {'name': 'Adventure', 'path_word': 'adventure'}
            ],
            'status': {'display': '连载'},
            'datetime_updated': '2026-01-02T03:04:05+08:00',
          },
          'groups': {
            'default': {'name': '默认', 'path_word': 'default', 'count': 1}
          }
        }
      },
      CopyMangaWrapperDto.fromJson,
    );

    expect(wrapper.code, 200);
    expect(wrapper.results?.comic.pathWord, 'one-piece');
    expect(wrapper.results?.groups.first.pathWord, 'default');
  });

  test('parses chapter page list wrapper', () {
    final wrapper = CopyMangaResultDto.fromJson(
      {
        'code': 200,
        'results': {
          'show_app': false,
          'chapter': {
            'uuid': 'chapter-uuid',
            'name': 'Chapter 1',
            'contents': [
              {'url': 'https://img/1500/2.jpg'},
              {'url': 'https://img/1500/1.jpg'}
            ],
            'words': [1, 0]
          }
        }
      },
      CopyMangaChapterPageListWrapperDto.fromJson,
    );

    expect(wrapper.results?.chapter.uuid, 'chapter-uuid');
    expect(wrapper.results?.chapter.contents.length, 2);
    expect(wrapper.results?.chapter.words, [1, 0]);
  });
}
```

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/requests/copymanga/copymanga_dtos_test.dart`

预期：FAIL，提示 DTO 文件或类型不存在。

- [ ] **步骤 3：实现 DTO**

创建 `lib/requests/copymanga/copymanga_dtos.dart`，包含：

```dart
typedef CopyMangaJsonFactory<T> = T Function(Map<String, dynamic> json);

class CopyMangaResultDto<T> {
  final int? code;
  final T? results;
  final String? message;

  CopyMangaResultDto({this.code, this.results, this.message});

  factory CopyMangaResultDto.fromJson(
    Map<String, dynamic> json,
    CopyMangaJsonFactory<T> resultsFactory,
  ) {
    final rawResults = json['results'];
    return CopyMangaResultDto<T>(
      code: json['code'] is int ? json['code'] as int : null,
      message: json['message']?.toString(),
      results: rawResults is Map<String, dynamic>
          ? resultsFactory(rawResults)
          : null,
    );
  }
}

class CopyMangaListDto<T> {
  final int total;
  final int limit;
  final int offset;
  final List<T> list;

  CopyMangaListDto({
    required this.total,
    required this.limit,
    required this.offset,
    required this.list,
  });

  factory CopyMangaListDto.fromJson(
    Map<String, dynamic> json,
    CopyMangaJsonFactory<T> itemFactory,
  ) {
    final rawList = json['list'];
    return CopyMangaListDto<T>(
      total: json['total'] is int ? json['total'] as int : 0,
      limit: json['limit'] is int ? json['limit'] as int : 0,
      offset: json['offset'] is int ? json['offset'] as int : 0,
      list: rawList is List
          ? rawList
              .whereType<Map>()
              .map((e) => itemFactory(Map<String, dynamic>.from(e)))
              .toList()
          : <T>[],
    );
  }
}
```

继续在同一文件中定义 `CopyMangaNamedDto`、`CopyMangaGroupDto`、`CopyMangaDto`、`CopyMangaWrapperDto`、`CopyMangaChapterDto`、`CopyMangaUrlDto`、`CopyMangaChapterPageListDto`、`CopyMangaChapterPageListWrapperDto`、`CopyMangaCommentDto`。字段至少覆盖现有 source model 使用的 `uuid/path_word/name/cover/brief/author/theme/status/datetime_updated/groups/contents/words/url/comment/user_avatar/user_name/count`。

- [ ] **步骤 4：运行 DTO 测试**

运行：`flutter test test/requests/copymanga/copymanga_dtos_test.dart`

预期：PASS。

- [ ] **步骤 5：Commit**

运行：

```bash
git add lib/requests/copymanga/copymanga_dtos.dart test/requests/copymanga/copymanga_dtos_test.dart
git commit -m "feat: add copymanga copy20 dtos"
```

## 任务 3：Mapper 与图片排序

**文件：**
- 创建：`lib/requests/copymanga/copymanga_mapper.dart`
- 测试：`test/requests/copymanga/copymanga_mapper_test.dart`

- [ ] **步骤 1：编写 mapper 单测**

在 `test/requests/copymanga/copymanga_mapper_test.dart` 写入：

```dart
import 'package:dcomic/requests/copymanga/copymanga_dtos.dart';
import 'package:dcomic/requests/copymanga/copymanga_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('orders chapter pages using words', () {
    final chapter = CopyMangaChapterPageListDto(
      uuid: 'c1',
      name: 'Chapter 1',
      contents: [
        const CopyMangaUrlDto(url: 'https://img/1500/page-b.jpg'),
        const CopyMangaUrlDto(url: 'https://img/1500/page-a.jpg'),
      ],
      words: [1, 0],
    );

    final urls = CopyMangaMapper.orderedPageUrls(chapter, resolution: '800');

    expect(urls, [
      'https://img/800/page-a.jpg',
      'https://img/800/page-b.jpg',
    ]);
  });

  test('keeps content order without words', () {
    final chapter = CopyMangaChapterPageListDto(
      uuid: 'c1',
      name: 'Chapter 1',
      contents: [
        const CopyMangaUrlDto(url: 'https://img/1500/1.jpg'),
        const CopyMangaUrlDto(url: 'https://img/1500/2.jpg'),
      ],
      words: const [],
    );

    final urls = CopyMangaMapper.orderedPageUrls(chapter, resolution: '1200');

    expect(urls, [
      'https://img/1200/1.jpg',
      'https://img/1200/2.jpg',
    ]);
  });
}
```

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/requests/copymanga/copymanga_mapper_test.dart`

预期：FAIL，提示 mapper 不存在。

- [ ] **步骤 3：实现 mapper**

创建 `lib/requests/copymanga/copymanga_mapper.dart`：

```dart
import 'package:dcomic/requests/copymanga/copymanga_config.dart';
import 'package:dcomic/requests/copymanga/copymanga_dtos.dart';

class CopyMangaMapper {
  static List<String> orderedPageUrls(
    CopyMangaChapterPageListDto chapter, {
    String resolution = CopyMangaConfig.defaultResolution,
  }) {
    final contents = chapter.contents;
    if (contents.isEmpty) {
      return const [];
    }

    if (chapter.words.isEmpty) {
      return contents
          .map((e) => replaceResolution(e.url, resolution))
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final words = List<int>.from(chapter.words);
    for (var i = 0; i < contents.length; i++) {
      if (!words.contains(i)) {
        words.add(i);
      }
    }

    final byIndex = <int, String>{};
    for (var i = 0; i < contents.length && i < words.length; i++) {
      byIndex[words[i]] = contents[i].url;
    }

    return List.generate(contents.length, (i) => byIndex[i] ?? '')
        .map((e) => replaceResolution(e, resolution))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String replaceResolution(String url, String resolution) {
    if (url.isEmpty) {
      return url;
    }
    return url.replaceFirst(RegExp(r'/(800|1200|1500)/'), '/$resolution/');
  }
}
```

- [ ] **步骤 4：运行 mapper 测试**

运行：`flutter test test/requests/copymanga/copymanga_mapper_test.dart`

预期：PASS。

- [ ] **步骤 5：Commit**

运行：

```bash
git add lib/requests/copymanga/copymanga_mapper.dart test/requests/copymanga/copymanga_mapper_test.dart
git commit -m "feat: add copymanga page mapper"
```

## 任务 4：偏好配置封装

**文件：**
- 创建：`lib/requests/copymanga/copymanga_preferences.dart`
- 修改：`lib/providers/models/copymanga/copymanga_source_model.dart`

- [ ] **步骤 1：实现偏好封装**

创建 `lib/requests/copymanga/copymanga_preferences.dart`：

```dart
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/requests/copymanga/copymanga_config.dart';

class CopyMangaPreferences {
  Future<T> _getOrDefault<T>(String key, T value) async {
    final database = await DatabaseInstance.instance;
    final entity = await database.modelConfigDao.getOrCreateConfigByKey(
      key,
      CopyMangaConfig.sourceId,
      value: value,
    );
    return entity.get<T>() ?? value;
  }

  Future<void> _set<T>(String key, T value) async {
    final database = await DatabaseInstance.instance;
    final entity = await database.modelConfigDao.getOrCreateConfigByKey(
      key,
      CopyMangaConfig.sourceId,
      value: value,
    );
    entity.set(value);
    await database.modelConfigDao.updateConfig(entity);
  }

  Future<int> getDomainIndex() =>
      _getOrDefault<int>(CopyMangaConfig.domainIndexKey, 0);

  Future<void> setDomainIndex(int value) =>
      _set<int>(CopyMangaConfig.domainIndexKey, value);

  Future<String> getAppVersion() => _getOrDefault<String>(
        CopyMangaConfig.appVersionKey,
        CopyMangaConfig.defaultAppVersion,
      );

  Future<void> setAppVersion(String value) =>
      _set<String>(CopyMangaConfig.appVersionKey, value);

  Future<String> getResolution() => _getOrDefault<String>(
        CopyMangaConfig.resolutionKey,
        CopyMangaConfig.defaultResolution,
      );

  Future<void> setResolution(String value) =>
      _set<String>(CopyMangaConfig.resolutionKey, value);

  Future<String> getToken() =>
      _getOrDefault<String>(CopyMangaConfig.tokenKey, '');

  Future<void> setToken(String value) =>
      _set<String>(CopyMangaConfig.tokenKey, value);

  Future<bool> isLogin() =>
      _getOrDefault<bool>(CopyMangaConfig.isLoginKey, false);

  Future<void> setLogin(bool value) =>
      _set<bool>(CopyMangaConfig.isLoginKey, value);

  Future<bool> useLoginSearch() =>
      _getOrDefault<bool>(CopyMangaConfig.loginSearchKey, false);

  Future<bool> showChapterCommentsPage() =>
      _getOrDefault<bool>(CopyMangaConfig.chapterCommentsKey, false);

  Future<String> hiddenDefaultChapterGroupText() => _getOrDefault<String>(
        CopyMangaConfig.hideDefaultChapterGroupKey,
        '',
      );
}
```

- [ ] **步骤 2：迁移初始化读取**

在 `CopyMangaComicSourceModel.initModel()` 中读取 `CopyMangaPreferences.getDomainIndex()` 替代 `useDynamicBaseUrl` 的核心状态。保留 `_useDynamicBaseUrl` 字段直到 UI 设置任务完成，但不要再让它驱动请求层。

- [ ] **步骤 3：运行静态分析**

运行：`flutter analyze`

预期：没有新增与 `copymanga_preferences.dart` 相关的错误。

- [ ] **步骤 4：Commit**

运行：

```bash
git add lib/requests/copymanga/copymanga_preferences.dart lib/providers/models/copymanga/copymanga_source_model.dart
git commit -m "feat: add copymanga preferences"
```

## 任务 5：客户端网络层与旧 Handler 兼容壳

**文件：**
- 创建：`lib/requests/copymanga/copymanga_client.dart`
- 修改：`lib/requests/copymanga/copymanga_request.dart`

- [ ] **步骤 1：实现客户端骨架**

创建 `lib/requests/copymanga/copymanga_client.dart`。构造函数接收 `Dio? dio`、`CopyMangaPreferences? preferences`，便于后续测试注入。实现 `ensureReady()`、`headers()`、`updateAppVersion()` 和这些方法：

```dart
Future<CopyMangaListDto<CopyMangaWrapperDto>> latest({int page = 0, int limit = 30});
Future<CopyMangaListDto<CopyMangaWrapperDto>> recommendations({int page = 0, int limit = 30});
Future<CopyMangaListDto<CopyMangaWrapperDto>> ranks({String dateType = 'day', int page = 0, int limit = 30});
Future<CopyMangaListDto<CopyMangaDto>> search(String keyword, {int page = 0, int limit = 18, bool login = false});
Future<CopyMangaWrapperDto?> comicDetail(String pathWord);
Future<CopyMangaListDto<CopyMangaChapterDto>> chapters(String pathWord, String groupPathWord, {int offset = 0, int limit = 500});
Future<List<CopyMangaChapterDto>> allChapters(String pathWord, String groupPathWord);
Future<CopyMangaChapterPageListWrapperDto?> chapterPages(String pathWord, String chapterUuid);
```

- [ ] **步骤 2：实现请求和解析**

每个方法使用 `dio.get()`，`Options(headers: await headers(login: ...))`，然后调用 DTO 的 `fromJson`。业务 `code != 200` 时抛出 `DioException.badResponse` 或返回空结果；阅读链路优先抛错，列表链路可返回空列表。

- [ ] **步骤 3：迁移旧 Handler**

在 `copymanga_request.dart` 中保留 `CopyMangaRequestHandler` 公共方法名。内部新增字段：

```dart
final CopyMangaClient client = CopyMangaClient();
```

将 `getComicDetail()`、`getChapters()`、`getComic()`、`search()`、`getRankList()`、`getLatestList()` 先转调新 client，再封装成当前调用方仍能读取的 `Response(data: ...)`。如果封装成本过高，则先修改 source model 调新 client，旧方法标记为兼容保留。

- [ ] **步骤 4：运行分析**

运行：`flutter analyze`

预期：没有新增客户端类型错误。

- [ ] **步骤 5：Commit**

运行：

```bash
git add lib/requests/copymanga/copymanga_client.dart lib/requests/copymanga/copymanga_request.dart
git commit -m "feat: add copymanga copy20 client"
```

## 任务 6：Source Model 核心浏览阅读迁移

**文件：**
- 修改：`lib/providers/models/copymanga/copymanga_source_model.dart`

- [ ] **步骤 1：迁移搜索**

将 `CopyMangaComicSourceModel.searchComicDetail()` 改为调用 `CopyMangaClient.search()`。保留原来的 `ComicListItemEntity` UI 字段：标题、封面、作者、热度、点击进入详情。

- [ ] **步骤 2：迁移详情和章节**

将 `getComicDetail()` 改为调用 `client.comicDetail(comicId)`，再对 `wrapper.groups` 调 `client.allChapters(comicId, group.pathWord)`。`CopyMangaComicDetailModel` 构造参数改为强类型 DTO 或中间模型，不再依赖裸 `Map`。

- [ ] **步骤 3：迁移章节阅读**

将 `CopyMangaComicDetailModel.getChapter()` 改为调用 `client.chapterPages(comicId, chapterId)`。`CopyMangaComicChapterDetailModel.pages` 调用 `CopyMangaMapper.orderedPageUrls()`，再映射为 `ImageEntity(ImageType.network, url)`。

- [ ] **步骤 4：迁移最新和排行**

将 `CopyMangaComicHomepageModel.getLatestList()` 和 `getRankingList()` 改为使用 `client.latest()` 与 `client.ranks()`。

- [ ] **步骤 5：运行分析**

运行：`flutter analyze`

预期：没有新增 `copymanga_source_model.dart` 类型错误。

- [ ] **步骤 6：Commit**

运行：

```bash
git add lib/providers/models/copymanga/copymanga_source_model.dart
git commit -m "refactor: migrate copymanga browsing to copy20 client"
```

## 任务 7：账号、收藏、历史和评论迁移

**文件：**
- 修改：`lib/requests/copymanga/copymanga_client.dart`
- 修改：`lib/requests/copymanga/copymanga_dtos.dart`
- 修改：`lib/providers/models/copymanga/copymanga_source_model.dart`

- [ ] **步骤 1：补齐客户端账号方法**

在 `CopyMangaClient` 中添加：

```dart
Future<Map<String, dynamic>?> userInfo();
Future<CopyMangaListDto<CopyMangaWrapperDto>> collectList({int page = 0, int limit = 21});
Future<bool> isCollected(String comicUuid);
Future<bool> setCollected(String comicUuid, bool collect);
Future<CopyMangaListDto<CopyMangaWrapperDto>> history({int page = 0, int limit = 12});
Future<CopyMangaListDto<CopyMangaCommentDto>> comicComments(String comicUuid, {int page = 0, int limit = 20});
Future<CopyMangaListDto<CopyMangaCommentDto>> chapterComments(String chapterUuid, {int page = 0, int limit = 50});
```

- [ ] **步骤 2：实现登录状态处理**

账号接口读取 token 后发送鉴权 headers。收到 401、403、业务 code 210 或用户信息解析失败时，调用 `CopyMangaPreferences.setLogin(false)`，但不删除 token。

- [ ] **步骤 3：迁移 AccountModel**

将 `CopyMangaAccountModel.initAccount()`、`getSubscribeComics()`、`subscribeComic()`、`unsubscribeComic()`、`getIfSubscribed()`、`logout()` 改为调用新 client 和 preferences。保留手动 token 登录。

- [ ] **步骤 4：迁移评论**

将 `CopyMangaComicDetailModel.getComments()` 与 `CopyMangaComicChapterDetailModel.getChapterComments()` 改为调用新 client 的评论方法。

- [ ] **步骤 5：运行分析**

运行：`flutter analyze`

预期：没有新增账号和评论相关类型错误。

- [ ] **步骤 6：Commit**

运行：

```bash
git add lib/requests/copymanga/copymanga_client.dart lib/requests/copymanga/copymanga_dtos.dart lib/providers/models/copymanga/copymanga_source_model.dart
git commit -m "feat: migrate copymanga account APIs"
```

## 任务 8：WebView 登录

**文件：**
- 修改：`pubspec.yaml`
- 创建：`lib/view/settings/copymanga_web_login_page.dart`
- 修改：`lib/providers/models/copymanga/copymanga_source_model.dart`
- 修改：`lib/l10n/intl_en.arb`
- 修改：`lib/l10n/intl_zh.arb`

- [ ] **步骤 1：添加依赖**

在 `pubspec.yaml` dependencies 添加：

```yaml
  webview_flutter: ^4.10.0
```

运行：`flutter pub get`

预期：依赖解析成功，`pubspec.lock` 更新。

- [ ] **步骤 2：创建 WebView 登录页**

创建 `lib/view/settings/copymanga_web_login_page.dart`。页面包含 `WebViewController`，加载 `CopyMangaConfig.baseUrl`，提供 AppBar 按钮“获取 Token”。按钮执行：

```dart
final rawUser = await controller.runJavaScriptReturningResult(
  "localStorage.getItem('user')",
);
final token = CopyMangaWebLoginPage.extractToken(rawUser);
```

`extractToken()` 作为静态方法实现，先处理 `"null"` 和空值，再 `jsonDecode()`；若 decode 后是字符串，再 decode 一次；最后从 `token`、`results.token` 或 `user.token` 中取值。

- [ ] **步骤 3：接入 AccountModel 登录入口**

在 `CopyMangaAccountModel.buildLoginWidget()` 中添加一个 `ElevatedButton.icon`，点击 push `CopyMangaWebLoginPage`。页面返回 token 后调用 `loginWithToken(token)`，成功后关闭登录页。

- [ ] **步骤 4：补充本地化**

在 `intl_zh.arb` 添加：

```json
"CopyMangaWebLogin": "网页登录",
"CopyMangaWebLoginGetToken": "获取 Token",
"CopyMangaWebLoginTokenMissing": "未从网页登录状态中读取到 Token"
```

在 `intl_en.arb` 添加对应英文：

```json
"CopyMangaWebLogin": "Web Login",
"CopyMangaWebLoginGetToken": "Get Token",
"CopyMangaWebLoginTokenMissing": "No token was found in the web login state"
```

运行项目现有 intl 生成命令；如果仓库没有脚本，运行：`flutter pub run intl_utils:generate`。

- [ ] **步骤 5：运行分析**

运行：`flutter analyze`

预期：WebView API、intl 生成文件和 account model 无新增错误。

- [ ] **步骤 6：Commit**

运行：

```bash
git add pubspec.yaml pubspec.lock lib/view/settings/copymanga_web_login_page.dart lib/providers/models/copymanga/copymanga_source_model.dart lib/l10n/intl_en.arb lib/l10n/intl_zh.arb lib/generated
git commit -m "feat: add copymanga web login"
```

## 任务 9：copy20 设置项接入

**文件：**
- 修改：`lib/providers/models/copymanga/copymanga_source_model.dart`
- 修改：`lib/l10n/intl_en.arb`
- 修改：`lib/l10n/intl_zh.arb`

- [ ] **步骤 1：替换动态域名设置 UI**

将 `getSourceSettingWidget()` 从单个 `Switch` 改为 `Column`，包含：

```dart
ListTile(title: Text(S.of(context).CopyMangaApiDomain), subtitle: Text(currentDomain))
ListTile(title: Text(S.of(context).CopyMangaImageResolution), subtitle: Text(currentResolution))
SwitchListTile(title: Text(S.of(context).CopyMangaLoginSearch), value: loginSearch, onChanged: ...)
SwitchListTile(title: Text(S.of(context).CopyMangaChapterCommentsPage), value: chapterComments, onChanged: ...)
ListTile(title: Text(S.of(context).CopyMangaHideDefaultChapterGroup), onTap: openEditDialog)
```

域名和分辨率选择使用 `showDialog<SimpleDialog>`，写入 `CopyMangaPreferences` 后 `notifyListeners()`。

- [ ] **步骤 2：补充本地化**

在 ARB 中添加 API 域名、图片分辨率、登录状态搜索、章节末吐槽页、隐藏默认章节组相关文本。运行 intl 生成命令。

- [ ] **步骤 3：运行分析**

运行：`flutter analyze`

预期：设置 UI 无新增错误。

- [ ] **步骤 4：Commit**

运行：

```bash
git add lib/providers/models/copymanga/copymanga_source_model.dart lib/l10n/intl_en.arb lib/l10n/intl_zh.arb lib/generated
git commit -m "feat: add copymanga copy20 settings"
```

## 任务 10：端到端验证与修正

**文件：**
- 修改：按验证发现的问题限定到相关文件。

- [ ] **步骤 1：运行单元测试**

运行：`flutter test test/requests/copymanga`

预期：PASS。

- [ ] **步骤 2：运行全量测试**

运行：`flutter test`

预期：现有默认 widget test 可能因 app 初始化依赖失败。如果失败，记录失败原因；若与本次变更无关，不在此任务重写全局 widget test。

- [ ] **步骤 3：运行静态分析**

运行：`flutter analyze`

预期：无新增 errors。已有仓库历史 warnings 需要分辨是否由本次引入。

- [ ] **步骤 4：Android 构建验证**

运行：`flutter build apk --debug`

预期：构建通过，尤其验证 `webview_flutter` 平台依赖。

- [ ] **步骤 5：手动功能验证**

在 Android 设备或模拟器验证：

```text
1. 打开拷贝漫画首页，最新/排行有数据。
2. 搜索一个关键词，结果可进入详情。
3. 详情页显示章节组。
4. 打开章节，图片加载且顺序正确。
5. 设置中切换 API 域名和分辨率，重新打开章节后生效。
6. 使用 WebView 登录获取 token，账号页显示用户信息。
7. 登录后收藏列表、收藏/取消、历史和评论接口可用。
```

- [ ] **步骤 6：修正验证失败**

如果某项失败，定位到对应层修正：

```text
DTO 解析失败 -> 修改 copymanga_dtos.dart 和对应测试。
图片顺序失败 -> 修改 copymanga_mapper.dart 和 mapper 测试。
请求 401/403 -> 修改 copymanga_headers.dart 或 token 登录流程。
域名连接失败 -> 修改 copymanga_config.dart 默认域名或设置保存逻辑。
UI 类型错误 -> 修改 copymanga_source_model.dart 的适配代码。
```

- [ ] **步骤 7：最终 Commit**

运行：

```bash
git status --short
git add lib/requests/copymanga lib/providers/models/copymanga/copymanga_source_model.dart lib/view/settings/copymanga_web_login_page.dart pubspec.yaml pubspec.lock lib/l10n lib/generated test/requests/copymanga
git commit -m "fix: stabilize copymanga copy20 integration"
```

如果没有验证修正文件，则不创建空提交。

## 自检

- 规格中的配置、headers、DTO、mapper、client、source model、WebView 登录、设置项、错误处理和验证要求都有对应任务。
- 计划没有保留未决实现点；账号端点如果服务端变化，会在任务 10 以实际响应修正。
- 类型命名统一使用 `CopyMangaConfig`、`CopyMangaHeaders`、`CopyMangaPreferences`、`CopyMangaClient`、`CopyMangaMapper` 和 `CopyManga*Dto`。
- 每个任务都能独立产生可提交变更。

## 执行交接

计划完成并保存到 `docs/superpowers/plans/2026-05-14-copymanga-copy20-client-rebuild.md`。两种执行方式：

**1. 子代理驱动（推荐）** - 每个任务调度一个新的子代理，任务间进行审查，快速迭代。

**2. 内联执行** - 在当前会话中使用 executing-plans 执行任务，批量执行并设有检查点。

请选择执行方式。

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/network_diagnostics_controller.dart';
import 'package:dcomic/requests/copymanga/copymanga_request.dart';
import 'package:dcomic/requests/github/github_request.dart';
import 'package:dcomic/requests/zaimanhua/zaimanhua_request.dart';

List<NetworkDiagnosticTarget> networkDiagnosticTargets({
  required bool chinese,
}) {
  String text(String zh, String en) => chinese ? zh : en;
  NetworkDiagnosticTarget domain(String label, String baseUrl) =>
      NetworkDiagnosticTarget(
        label: label,
        uri: Uri.parse(baseUrl).replace(path: '/', query: null, fragment: null),
      );

  return [
    for (final api in CopyMangaApiDomain.values)
      domain(
        api.isHotManga ? text('热辣漫画', 'HotManga') : text('拷贝漫画', 'CopyManga'),
        'https://${api.host}',
      ),
    domain(
      text('再漫画网页', 'ZaiManHua website'),
      ZaiManHuaRequestHandler.endpoint,
    ),
    domain(
      text('再漫画 API', 'ZaiManHua API'),
      ZaiManHuaMobileRequestHandler.endpoint,
    ),
    domain(
      text('再漫画账户', 'ZaiManHua account'),
      ZaiManHuaAccountRequestHandler.endpoint,
    ),
    domain(
      text('再漫画任务', 'ZaiManHua tasks'),
      ZaiManHuaTaskRequestHandler.endpoint,
    ),
    domain(text('GitHub 网站', 'GitHub website'), 'https://github.com'),
    domain('GitHub API', GithubRequestHandler.endpoint),
  ];
}

/// Read-only snapshot: never refresh accounts (which can sign in or clear tokens).
Future<List<String>> readNetworkDiagnosticAccounts(
  List<BaseComicSourceModel> sources, {
  required bool chinese,
}) async {
  String text(String zh, String en) => chinese ? zh : en;
  final lines = <String>[
    text(
      '登录状态为应用当前状态，不代表本次已验证凭据有效性。',
      'Login states are the current app state, not a fresh credential check.',
    ),
  ];
  for (final source in sources) {
    final account = source.accountModel;
    final state = account == null
        ? text('不支持登录', 'Login not supported')
        : account.isLoading
        ? text('正在加载，状态未确定', 'Loading; state unknown')
        : account.isLogin
        ? text('已登录', 'Logged in')
        : text('未登录', 'Not logged in');
    lines.add('${source.type.sourceName} (${source.type.sourceId}): $state');
  }

  try {
    final dao = (await DatabaseInstance.instance).modelConfigDao;
    final configuredApi = await dao.getConfigByKeyAndModel(
      'apiDomain',
      'copymanga',
    );
    final api = CopyMangaApiDomain.fromHost(configuredApi?.get<String>());
    final configuredComments = await dao.getConfigByKeyAndModel(
      'chapterCommentApiDomain',
      'copymanga',
    );
    final selectedComments = CopyMangaApiDomain.fromHost(
      configuredComments?.get<String>(),
    );
    final comments = selectedComments.isHotManga
        ? CopyMangaApiDomain.defaultDomain
        : selectedComments;
    lines.add(
      '${text('当前拷贝/热辣 API', 'Active CopyManga/HotManga API')}: ${api.host}',
    );
    lines.add(
      '${text('当前章节评论 API', 'Active chapter comments API')}: ${comments.host}',
    );
    lines.add(
      '${text('当前账户空间', 'Active account namespace')}: ${api.accountSourceId}',
    );
    // CopyManga and HotManga store independent accounts even though they share a source UI.
    for (final entry in const {
      'copymanga': 'CopyManga',
      'hotmanga': 'HotManga',
      'zaimanhua': 'ZaiManHua',
    }.entries) {
      final saved = await dao.getConfigByKeyAndModel('isLogin', entry.key);
      final state = saved?.get<bool>() == true
          ? text('已保存登录标记（未在线验证）', 'Saved login flag (not verified online)')
          : text('未保存登录标记', 'No saved login flag');
      lines.add('${entry.value}: $state');
    }
  } catch (_) {
    // Never format database exceptions: they may contain a row with credentials.
    lines.add(
      text('本地线路/登录配置读取失败', 'Could not read local endpoint/login settings'),
    );
  }
  return lines;
}

import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/page_controllers/debug_database_page_controller.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dcomic/utils/firbaselogoutput.dart';
import 'package:dcomic/utils/layout_utils.dart';
import 'package:dcomic/view/components/empty_widget.dart';
import 'package:dcomic/view/components/settings_widgets.dart';
import 'package:dcomic/view/splash_page.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:logger/logger.dart';
import 'package:motion_toast/motion_toast.dart';
import 'package:provider/provider.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _DebugPageState();
  }
}

class _DebugPageState extends State<DebugPage> {
  bool _hiding = false;

  String _locale(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  Future<void> _hideAdvancedSettings() async {
    if (_hiding) return;
    setState(() => _hiding = true);
    try {
      await context.read<ConfigProvider>().setAdvancedSettingsUnlocked(false);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _locale('保存失败，请重试。', 'Could not save. Please try again.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _hiding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: Text(S.of(context).DebugSettings),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
          child: ListView(
            padding: EdgeInsets.only(
              left: 12,
              top: 12,
              right: 12,
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              SettingsNotice(
                icon: Icons.warning_amber_rounded,
                child: Text(
                  _locale(
                    '诊断操作会记录真实异常日志，数据库页面长按数据行会删除该行，请谨慎操作。',
                    'Diagnostics log real exceptions, and long-pressing a row in the database page deletes it. Use with care.',
                  ),
                ),
              ),
              SettingsSection(title: _locale('诊断', 'Diagnostics')),
              SettingsGroup(
                children: [
                  SettingsTile(
                    leading: const Icon(Icons.network_check),
                    title: Text(S.of(context).DebugPageNetworkCheck),
                    subtitle: Text(
                      S.of(context).DebugPageNetworkCheckDescription,
                    ),
                    onTap: () async {
                      try {
                        var request = RequestHandlers.githubRequestHandler;
                        int ping = await request.ping();
                        if (!context.mounted) {
                          return;
                        }
                        MotionToast.success(
                          title: Text(S.of(context).DebugPagePingSuccessTitle),
                          description: Text(
                            S.of(context).DebugPagePingSuccessDescription(ping),
                          ),
                        ).show(context);
                      } catch (e) {
                        if (!context.mounted) {
                          return;
                        }
                        MotionToast.error(
                          title: Text(S.of(context).DebugPagePingFailedTitle),
                          description: Text(
                            S.of(context).DebugPagePingFailedDescription(e),
                          ),
                        ).show(context);
                      }
                    },
                  ),
                  SettingsTile(
                    leading: const Icon(FontAwesome5.bug),
                    title: Text(S.of(context).DebugPageTryCrash),
                    subtitle: Text(S.of(context).DebugPageTryCrashDescription),
                    onTap: () {
                      Logger logger = Logger(
                        printer: PrettyPrinter(
                          noBoxingByDefault: true,
                          methodCount: 2,
                        ),
                        filter: ProductionFilter(),
                        output: CrashConsoleOutput(),
                      );
                      try {
                        dynamic x = 0;
                        String y = x;
                      } catch (e, s) {
                        logger.e(e, error: e, stackTrace: s);
                      }
                    },
                  ),
                ],
              ),
              SettingsSection(title: _locale('调试工具', 'Debug Tools')),
              SettingsGroup(
                children: [
                  SettingsTile(
                    leading: const Icon(FontAwesome5.database),
                    title: Text(S.of(context).DebugPagePrintModelDatabase),
                    subtitle: Text(
                      S.of(context).DebugPagePrintModelDatabaseDescription,
                    ),
                    onTap: () async {
                      Provider.of<NavigatorProvider>(context, listen: false)
                          .getNavigator(context, NavigatorType.defaultNavigator)
                          ?.push(
                            MaterialPageRoute(
                              builder: (context) => const DatabaseDebugPage(),
                              settings: const RouteSettings(
                                name: 'DatabaseDebugPage',
                              ),
                            ),
                          );
                    },
                  ),
                  SettingsTile(
                    leading: const Icon(Icons.open_in_browser),
                    title: Text(S.of(context).DebugPageShowSplashTitle),
                    subtitle: Text(
                      S.of(context).DebugPageShowSplashDescription,
                    ),
                    onTap: () async {
                      Provider.of<NavigatorProvider>(context, listen: false)
                          .getNavigator(context, NavigatorType.defaultNavigator)
                          ?.push(
                            MaterialPageRoute(
                              builder: (context) => const SplashPage(),
                              settings: const RouteSettings(name: 'SplashPage'),
                            ),
                          );
                    },
                  ),
                ],
              ),
              SettingsSection(title: _locale('高级设置', 'Advanced')),
              SettingsGroup(
                children: [
                  SettingsTile(
                    leading: const Icon(Icons.visibility_off_outlined),
                    title: Text(
                      _locale(
                        '重新隐藏调试与实验性功能',
                        'Hide Debug and Experimental Settings',
                      ),
                    ),
                    subtitle: Text(
                      _locale(
                        '只隐藏两个设置入口，不修改功能开关。可在关于页再次点击顶部版本号 7 次解锁。',
                        'Hide both entries without changing feature choices. Tap the top version number in About 7 times to unlock again.',
                      ),
                    ),
                    onTap: _hiding ? null : _hideAdvancedSettings,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DatabaseDebugPage extends StatefulWidget {
  const DatabaseDebugPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _DatabaseDebugPage();
  }
}

class _DatabaseDebugPage extends State<DatabaseDebugPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChangeNotifierProvider<DatabaseDebugPageController>(
      create: (_) => DatabaseDebugPageController(),
      builder: (context, child) => DefaultTabController(
        length: Provider.of<DatabaseDebugPageController>(context).tableLength,
        child: Scaffold(
          backgroundColor: theme.colorScheme.surfaceContainerLow,
          appBar: AppBar(
            backgroundColor: theme.colorScheme.surfaceContainerLow,
            title: Text(S.of(context).DatabaseDebugPageTitle),
            bottom: TabBar(
              isScrollable: true,
              tabs: Provider.of<DatabaseDebugPageController>(context).tabs,
            ),
          ),
          body: TabBarView(
            children: Provider.of<DatabaseDebugPageController>(context).tabNames
                .map(
                  (e) => EasyRefresh(
                    refreshOnStart: true,
                    onRefresh: () async {
                      await Provider.of<DatabaseDebugPageController>(
                        context,
                        listen: false,
                      ).refreshDatabase(e);
                    },
                    child: AutoEmptyWidget(
                      isEmpty: Provider.of<DatabaseDebugPageController>(context)
                          .tableData[e]
                          .isEmpty,
                      notEmptyChild: Builder(
                        builder: (context) => SingleChildScrollView(
                          child: SingleChildScrollView(
                            primary: false,
                            physics: const ClampingScrollPhysics(),
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns:
                                  Provider.of<DatabaseDebugPageController>(
                                        context,
                                      ).columnData[e]
                                      .map<DataColumn>(
                                        (column) =>
                                            DataColumn(label: Text(column)),
                                      )
                                      .toList(),
                              rows:
                                  Provider.of<DatabaseDebugPageController>(
                                        context,
                                      ).tableData[e]
                                      .map<DataRow>(
                                        (row) => DataRow(
                                          cells: row.values
                                              .map<DataCell>(
                                                (value) => DataCell(
                                                  Text(value.toString()),
                                                ),
                                              )
                                              .toList(),
                                          onLongPress: () {
                                            Provider.of<
                                                  DatabaseDebugPageController
                                                >(context, listen: false)
                                                .delete(row, e);
                                          },
                                        ),
                                      )
                                      .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

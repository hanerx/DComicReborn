import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/page_controllers/debug_database_page_controller.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dcomic/utils/firbaselogoutput.dart';
import 'package:dcomic/view/components/empty_widget.dart';
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
  State<StatefulWidget> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).DebugSettings),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.network_check),
            title: Text(S.of(context).DebugPageNetworkCheck),
            subtitle: Text(S.of(context).DebugPageNetworkCheckDescription),
            onTap: () async {
              try {
                var request = RequestHandler("https://dmzj.com");
                int ping = await request.ping();
                if (!context.mounted) {
                  return;
                }
                MotionToast.success(
                        title: Text(S.of(context).DebugPagePingSuccessTitle),
                        description: Text(S
                            .of(context)
                            .DebugPagePingSuccessDescription(ping)))
                    .show(context);
              } catch (e) {
                if (!context.mounted) {
                  return;
                }
                MotionToast.error(
                        title: Text(S.of(context).DebugPagePingFailedTitle),
                        description: Text(
                            S.of(context).DebugPagePingFailedDescription(e)))
                    .show(context);
              }
            },
          ),
          ListTile(
            leading: const Icon(FontAwesome5.bug),
            title: Text(S.of(context).DebugPageTryCrash),
            subtitle: Text(S.of(context).DebugPageTryCrashDescription),
            onTap: () {
              Logger logger = Logger(
                  printer:
                      PrettyPrinter(noBoxingByDefault: true, methodCount: 2),
                  filter: ProductionFilter(),
                  output: CrashConsoleOutput());
              try {
                dynamic x = 0;
                String y = x;
              } catch (e, s) {
                logger.e(e, error: e, stackTrace: s);
              }
            },
          ),
          ListTile(
            leading: const Icon(FontAwesome5.database),
            title: Text(S.of(context).DebugPagePrintModelDatabase),
            subtitle:
                Text(S.of(context).DebugPagePrintModelDatabaseDescription),
            onTap: () async {
              Provider.of<NavigatorProvider>(context, listen: false)
                  .getNavigator(context, NavigatorType.defaultNavigator)
                  ?.push(MaterialPageRoute(
                      builder: (context) => const DatabaseDebugPage(),
                      settings:
                          const RouteSettings(name: 'DatabaseDebugPage')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.open_in_browser),
            title: Text(S.of(context).DebugPageShowSplashTitle),
            subtitle: Text(S.of(context).DebugPageShowSplashDescription),
            onTap: () async {
              Provider.of<NavigatorProvider>(context, listen: false)
                  .getNavigator(context, NavigatorType.defaultNavigator)
                  ?.push(MaterialPageRoute(
                      builder: (context) => const SplashPage(),
                      settings: const RouteSettings(name: 'SplashPage')));
            },
          )
        ],
      ),
    );
  }
}

class DatabaseDebugPage extends StatefulWidget {
  const DatabaseDebugPage({super.key});

  @override
  State<StatefulWidget> createState() => _DatabaseDebugPage();
}

class _DatabaseDebugPage extends State<DatabaseDebugPage> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DatabaseDebugPageController>(
        create: (_) => DatabaseDebugPageController(),
        builder: (context, child) => DefaultTabController(
            length:
                Provider.of<DatabaseDebugPageController>(context).tableLength,
            child: Scaffold(
              appBar: AppBar(
                title: Text(S.of(context).DatabaseDebugPageTitle),
                bottom: TabBar(
                    isScrollable: true,
                    tabs:
                        Provider.of<DatabaseDebugPageController>(context).tabs),
              ),
              body: TabBarView(
                children: Provider.of<DatabaseDebugPageController>(context)
                    .tabNames
                    .map((e) => EasyRefresh(
                        refreshOnStart: true,
                        onRefresh: () async {
                          await Provider.of<DatabaseDebugPageController>(
                                  context,
                                  listen: false)
                              .refreshDatabase(e);
                        },
                        child: AutoEmptyWidget(
                          isEmpty:
                              Provider.of<DatabaseDebugPageController>(context)
                                  .tableData[e]
                                  .isEmpty,
                          notEmptyChild: Builder(
                              builder: (context) => SingleChildScrollView(
                                      child: SingleChildScrollView(
                                    primary: false,
                                    physics: const ClampingScrollPhysics(),
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: Provider.of<
                                                  DatabaseDebugPageController>(
                                              context)
                                          .columnData[e]
                                          .map<DataColumn>((column) =>
                                              DataColumn(label: Text(column)))
                                          .toList(),
                                      rows: Provider.of<
                                                  DatabaseDebugPageController>(
                                              context)
                                          .tableData[e]
                                          .map<DataRow>((row) => DataRow(
                                              cells: row.values
                                                  .map<DataCell>((value) =>
                                                      DataCell(Text(
                                                          value.toString())))
                                                  .toList(),
                                              onLongPress: () {
                                                Provider.of<DatabaseDebugPageController>(
                                                        context,
                                                        listen: false)
                                                    .delete(row, e);
                                              }))
                                          .toList(),
                                    ),
                                  ))),
                        )))
                    .toList(),
              ),
            )));
  }
}

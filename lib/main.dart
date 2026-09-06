import 'dart:async';

import 'package:dcomic/providers/download_provider.dart';
import 'package:dcomic/providers/version_provider.dart';
import 'package:dcomic/view/drawer_page/search_page.dart';
import 'package:dcomic/view/homepage/category_page.dart';
import 'package:dcomic/view/homepage/latest_page.dart';
import 'package:dcomic/view/homepage/rank_page.dart';
import 'package:dcomic/view/splash_page.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/utils/theme_utils.dart';
import 'package:dcomic/view/components/dcomic_mark.dart';
import 'package:dcomic/view/components/left_drawer.dart';
import 'package:dcomic/view/homepage/homepage.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:provider/provider.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // The following lines are the same as previously explained in "Handling uncaught errors"
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

    // Set Easy Refresh
    EasyRefresh.defaultHeaderBuilder = () => const ClassicHeader(
          showMessage: false,
          spacing: 8,
          textStyle: TextStyle(fontSize: 12),
          progressIndicatorSize: 20,
          progressIndicatorStrokeWidth: 2,
        );
    EasyRefresh.defaultFooterBuilder = () => const ClassicFooter(
          showMessage: false,
          spacing: 8,
          textStyle: TextStyle(fontSize: 12),
          progressIndicatorSize: 20,
          progressIndicatorStrokeWidth: 2,
        );
    runApp(const App());
  },
      (error, stack) =>
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true));
}

class App extends StatelessWidget {
  const App({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          ChangeNotifierProvider<ConfigProvider>(
            create: (_) => ConfigProvider(),
            lazy: false,
          ),
          ChangeNotifierProvider<NavigatorProvider>(
            create: (_) => NavigatorProvider(context),
            lazy: false,
          ),
          ChangeNotifierProvider<ComicSourceProvider>(
            create: (_) => ComicSourceProvider(),
            lazy: false,
          ),
          ChangeNotifierProvider<VersionProvider>(
            create: (_) => VersionProvider(),
            lazy: false,
          ),
          ChangeNotifierProvider<DownloadProvider>(
            create: (_) => DownloadProvider(),
            lazy: false,
          ),
        ],
        builder: (context, child) => MaterialApp(
            title: 'DComic',
            theme: ThemeModel.buildTheme(
              brightness: Brightness.light,
              useMaterial3:
                  Provider.of<ConfigProvider>(context).useMaterial3Design,
              seedColor: Provider.of<ConfigProvider>(context).themeColor.color,
            ),
            darkTheme: ThemeModel.buildTheme(
              brightness: Brightness.dark,
              useMaterial3:
                  Provider.of<ConfigProvider>(context).useMaterial3Design,
              seedColor: Provider.of<ConfigProvider>(context).themeColor.color,
            ),
            themeMode: Provider.of<ConfigProvider>(context).themeMode,
            supportedLocales: S.delegate.supportedLocales,
            localizationsDelegates: const [
              //此处
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              DefaultCupertinoLocalizations.delegate,
            ],
            home: const MainFramework()));
  }
}

class MainFramework extends StatefulWidget {
  const MainFramework({super.key});

  @override
  State<MainFramework> createState() => _MainFrameworkState();
}

class _MainFrameworkState extends State<MainFramework> {
  @override
  Widget build(BuildContext context) {
    if (Provider.of<ComicSourceProvider>(context).isLoading) {
      return SplashPage();
    }
    if (Provider.of<VersionProvider>(context).needShowUpdateDialog &&
        !Provider.of<VersionProvider>(context).isUpdateDialogShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<VersionProvider>(context, listen: false)
            .tryShowUpdateDialog(context);
      });
    }
    return ChangeNotifierProvider<AppBarProvider>(
        create: (_) => AppBarProvider(context),
        builder: (context, child) => DefaultTabController(
              length: 4,
              child: Scaffold(
                appBar: AppBar(
                  toolbarHeight: 68,
                  titleSpacing: 0,
                  title: Row(
                    children: [
                      const DComicMark(size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(S.of(context).AppName),
                            Text(
                              Provider.of<ComicSourceProvider>(context)
                                  .activeHomeModel
                                  .type
                                  .sourceName,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.w400,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: IconButton.filledTonal(
                          tooltip: MaterialLocalizations.of(context)
                              .searchFieldLabel,
                          onPressed: () {
                            Provider.of<NavigatorProvider>(context,
                                    listen: false)
                                .getNavigator(
                                    context, NavigatorType.defaultNavigator)
                                ?.push(MaterialPageRoute(
                                    builder: (context) => const SearchPage(),
                                    settings: const RouteSettings(
                                        name: 'SearchPage')));
                          },
                          icon: const Icon(Icons.search_rounded)),
                    ),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(64),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TabBar(
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerHeight: 0,
                          indicator: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelPadding: EdgeInsets.zero,
                          splashBorderRadius: BorderRadius.circular(12),
                          tabs: [
                            Tab(text: S.of(context).MainPageHome),
                            Tab(text: S.of(context).MainPageCategory),
                            Tab(text: S.of(context).MainPageRank),
                            Tab(text: S.of(context).MainPageLatest),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                drawer: LeftDrawer(),
                body: const TabBarView(
                  children: [
                    HomePage(),
                    CategoryPage(),
                    RankPage(),
                    LatestPage()
                  ],
                ),
              ),
            ));
  }
}

import 'dart:async';

import 'package:dcomic/providers/comic_veiwer_config_provider.dart';
import 'package:dcomic/providers/version_provider.dart';
import 'package:dcomic/view/drawer_page/search_page.dart';
import 'package:dcomic/view/homepage/category_page.dart';
import 'package:dcomic/view/homepage/latest_page.dart';
import 'package:dcomic/view/homepage/rank_page.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/utils/theme_utils.dart';
import 'package:dcomic/view/components/left_drawer.dart';
import 'package:dcomic/view/homepage/homepage.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:firebase_analytics/firebase_analytics.dart';
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
    EasyRefresh.defaultHeaderBuilder = () => const ClassicHeader();
    EasyRefresh.defaultFooterBuilder = () => const ClassicFooter();

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
          ChangeNotifierProvider<ComicViewerConfigProvider>(
            create: (_) => ComicViewerConfigProvider(),
            lazy: false,
          )
        ],
        builder: (context, child) => MaterialApp(
            title: 'DComic',
            theme: ThemeModel.light,
            darkTheme: ThemeModel.dark,
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
    return ChangeNotifierProvider<AppBarProvider>(
        create: (_) => AppBarProvider(context),
        builder: (context, child) => DefaultTabController(
              length: 4,
              child: Scaffold(
                appBar: AppBar(
                  title: Text(S.of(context).AppName),
                  actions: [
                    IconButton(onPressed: () {
                      Provider.of<NavigatorProvider>(context, listen: false)
                          .getNavigator(context, NavigatorType.defaultNavigator)
                          ?.push(MaterialPageRoute(
                          builder: (context) => const SearchPage(),
                          settings: const RouteSettings(name: 'SearchPage')));
                    }, icon: const Icon(Icons.search))
                  ],
                  bottom: TabBar(
                    tabs: [
                      Tab(
                        text: S.of(context).MainPageHome,
                      ),
                      Tab(
                        text: S.of(context).MainPageCategory,
                      ),
                      Tab(
                        text: S.of(context).MainPageRank,
                      ),
                      Tab(
                        text: S.of(context).MainPageLatest,
                      )
                    ],
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

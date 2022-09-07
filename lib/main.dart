import 'dart:async';

import 'package:dcomic/view/homepage/category_page.dart';
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
import 'package:flutter_adaptive_ui/flutter_adaptive_ui.dart';
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
  }, (error, stack) => FirebaseCrashlytics.instance.recordError(error, stack,fatal: true));
}

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

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
        )
      ],
      builder: (context, child) => Breakpoint(
          breakpointData: const BreakpointData(),
          child: MaterialApp(
              title: 'DComic',
              theme: ThemeModel.light,
              darkTheme: ThemeModel.dark,
              supportedLocales: S.delegate.supportedLocales,
              localizationsDelegates: const [
                //此处
                S.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                DefaultCupertinoLocalizations.delegate,
                //TODO 这个不知道干嘛的，反正先不用他
                // ChineseCupertinoLocalizations.delegate,
              ],
              home: const MainFramework())),
    );
  }
}

class MainFramework extends StatefulWidget {
  const MainFramework({Key? key}) : super(key: key);

  @override
  State<MainFramework> createState() => _MainFrameworkState();
}

class _MainFrameworkState extends State<MainFramework> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppBarProvider>(
      create: (_) => AppBarProvider(context),
      builder: (context, child) => AdaptiveBuilder(
        defaultBuilder: (context, screen) {
          return DefaultTabController(
            length: 4,
            child: Scaffold(
              appBar: AppBar(
                title: Text(S.of(context).AppName),
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
              body: TabBarView(
                children: [
                  const HomePage(),
                  const CategoryPage(),
                  Container(
                    color: Colors.green,
                  ),
                  Container(
                    color: Colors.blue,
                  )
                ],
              ),
            ),
          );
        },
        layoutDelegate: const AdaptiveLayoutDelegateWithMinimallScreenType(
          // handset: (context, screen) => DefaultTabController(
          //   length: 4,
          //   child: Scaffold(
          //     appBar: AppBar(
          //       title: Text(S.of(context).AppName),
          //       bottom: TabBar(
          //         tabs: [
          //           Tab(
          //             text: S.of(context).MainPageHome,
          //           ),
          //           Tab(
          //             text: S.of(context).MainPageCategory,
          //           ),
          //           Tab(
          //             text: S.of(context).MainPageRank,
          //           ),
          //           Tab(
          //             text: S.of(context).MainPageLatest,
          //           )
          //         ],
          //       ),
          //     ),
          //     drawer: LeftDrawer(),
          //     body: TabBarView(
          //       children: [
          //         const HomePage(),
          //         const CategoryPage(),
          //         Container(
          //           color: Colors.green,
          //         ),
          //         Container(
          //           color: Colors.blue,
          //         )
          //       ],
          //     ),
          //   ),
          // ),
          // Todo: 后面再写
          // tablet: (context, screen) => Scaffold(
          //       appBar: Provider.of<AppBarProvider>(context).currentAppBar,
          //       drawer: LeftDrawer(),
          //       body: Navigator(
          //         key: Provider.of<NavigatorProvider>(context).largeNavigator,
          //         initialRoute: '',
          //         onGenerateRoute: (val) => PageRouteBuilder(
          //             pageBuilder: (BuildContext nContext,
          //                     Animation<double> animation,
          //                     Animation<double> secondaryAnimation) =>
          //                 Row(
          //                   children: [
          //                     Expanded(
          //                         child: Navigator(
          //                       key: Provider.of<NavigatorProvider>(context)
          //                           .homeNavigator,
          //                       initialRoute: '',
          //                       onGenerateRoute: (val) => PageRouteBuilder(
          //                           pageBuilder: (BuildContext nContext,
          //                                   Animation<double> animation,
          //                                   Animation<double>
          //                                       secondaryAnimation) =>
          //                               HomePage()),
          //                     )),
          //                     Expanded(
          //                         child: Navigator(
          //                       key: Provider.of<NavigatorProvider>(context)
          //                           .rightNavigator,
          //                       initialRoute: '',
          //                       onGenerateRoute: (val) => PageRouteBuilder(
          //                           pageBuilder: (BuildContext nContext,
          //                                   Animation<double> animation,
          //                                   Animation<double>
          //                                       secondaryAnimation) =>
          //                               Container(
          //                                 color: Colors.orange,
          //                               )),
          //                     ))
          //                   ],
          //                 )),
          //       ),
          //     ),
          // desktop: (context, screen) => Scaffold(
          //       appBar: AppBar(
          //         title: Text(S.of(context).AppName),
          //       ),
          //       body: Navigator(
          //         key: Provider.of<NavigatorProvider>(context).largeNavigator,
          //         initialRoute: '',
          //         onGenerateRoute: (val) => PageRouteBuilder(
          //             pageBuilder: (BuildContext nContext,
          //                     Animation<double> animation,
          //                     Animation<double> secondaryAnimation) =>
          //                 Row(
          //                   children: [
          //                     Expanded(child: LeftDrawer()),
          //                     Expanded(
          //                       flex: 2,
          //                         child: Navigator(
          //                       key: Provider.of<NavigatorProvider>(context)
          //                           .homeNavigator,
          //                       initialRoute: '',
          //                       onGenerateRoute: (val) => PageRouteBuilder(
          //                           pageBuilder: (BuildContext nContext,
          //                                   Animation<double> animation,
          //                                   Animation<double>
          //                                       secondaryAnimation) =>
          //                               HomePage()),
          //                     )),
          //                     Expanded(
          //                       flex: 2,
          //                         child: Container(
          //                       color: Colors.orange,
          //                     ))
          //                   ],
          //                 )),
          //       ),
          //     )
        ),
      ),
    );
  }
}

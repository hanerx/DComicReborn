import 'dart:async';

import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/view/homepage/homepage.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_ui/flutter_adaptive_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // The following lines are the same as previously explained in "Handling uncaught errors"
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

    runApp(const App());
  }, (error, stack) => FirebaseCrashlytics.instance.recordError(error, stack));
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
        )
      ],
      builder: (context, child) => Breakpoint(
          breakpointData: const BreakpointData(),
          child: MaterialApp(
              title: 'DComic',
              // theme: ThemeData(
              //   primarySwatch: Colors.blue,
              // ),
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
              themeMode: Provider.of<ConfigProvider>(context).themeMode,
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
    return AdaptiveBuilder(
      defaultBuilder: (context, screen) {
        return Scaffold(
          appBar: AppBar(
            title: Text(S.of(context).AppName),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const <Widget>[
                Text(
                  'You have pushed the button this many times:',
                ),
              ],
            ),
          ),
        );
      },
      layoutDelegate: AdaptiveLayoutDelegateWithMinimallScreenType(
          handset: (context, screen) => Scaffold(
                appBar: AppBar(
                  title: Text(S.of(context).AppName),
                ),
                drawer: Navigator(
                  key: Provider.of<NavigatorProvider>(context).leftNavigator,
                  initialRoute: '',
                  onGenerateRoute: (val) => PageRouteBuilder(
                      pageBuilder: (BuildContext nContext,
                              Animation<double> animation,
                              Animation<double> secondaryAnimation) =>
                          Container(
                            color: Colors.brown,
                          )),
                ),
              ),
          tablet: (context, screen) => Scaffold(
                appBar: AppBar(
                  title: Text(S.of(context).AppName),
                ),
                drawer: Navigator(
                  key: Provider.of<NavigatorProvider>(context).leftNavigator,
                  initialRoute: '',
                  onGenerateRoute: (val) => PageRouteBuilder(
                      pageBuilder: (BuildContext nContext,
                              Animation<double> animation,
                              Animation<double> secondaryAnimation) =>
                          Container(
                            color: Colors.brown,
                          )),
                ),
                body: Navigator(
                  key: Provider.of<NavigatorProvider>(context).largeNavigator,
                  initialRoute: '',
                  onGenerateRoute: (val) => PageRouteBuilder(
                      pageBuilder: (BuildContext nContext,
                              Animation<double> animation,
                              Animation<double> secondaryAnimation) =>
                          Row(
                            children: [
                              Expanded(
                                  child: HomePage(),
                              ),
                              Expanded(
                                  child: Container(
                                color: Colors.orange,
                              ))
                            ],
                          )),
                ),
              ),
          desktop: (context, screen) => Scaffold(
                appBar: AppBar(
                  title: Text(S.of(context).AppName),
                ),
                body: Navigator(
                  key: Provider.of<NavigatorProvider>(context).largeNavigator,
                  initialRoute: '',
                  onGenerateRoute: (val) => PageRouteBuilder(
                      pageBuilder: (BuildContext nContext,
                              Animation<double> animation,
                              Animation<double> secondaryAnimation) =>
                          Row(
                            children: [
                              Expanded(
                                  child: Container(
                                color: Colors.brown,
                              )),
                              Expanded(
                                  child: Container(
                                color: Colors.white,
                              )),
                              Expanded(
                                  child: Container(
                                color: Colors.orange,
                              ))
                            ],
                          )),
                ),
              )),
    );
  }
}

import 'dart:async';

import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/main.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/models/zaimanhua/zaimanhua_source_model.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/providers/version_provider.dart';
import 'package:dcomic/view/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _PendingVersionProvider extends VersionProvider {
  final pending = Completer<void>();

  @override
  Future<void> init() => pending.future;
}

class _MemoryConfigProvider extends ConfigProvider {
  @override
  Future<void> init() async {}
}

class _ReadySourceProvider extends ComicSourceProvider {
  _ReadySourceProvider() {
    sources = [_OfflineSource()];
    isLoading = false;
  }

  @override
  Future<void> init() async {}
}

class _OfflineSource extends ZaiManHuaSourceModel {
  @override
  BaseComicHomepageModel get homepage => _OfflineHomepage(this);
}

class _OfflineHomepage extends ZaiManHuaHomepageModel {
  _OfflineHomepage(super.parent);

  @override
  Future<List<CarouselEntity>> getHomepageCarousel() async => [];

  @override
  Future<List<HomepageCardEntity>> getHomepageCard() async => [];
}

void main() {
  testWidgets('home navigation is usable while the update check is pending',
      (tester) async {
    final version = _PendingVersionProvider();
    final source = _ReadySourceProvider();
    final config = _MemoryConfigProvider();
    addTearDown(() {
      version.pending.complete();
      version.dispose();
      source.dispose();
      config.dispose();
    });

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ComicSourceProvider>.value(value: source),
        ChangeNotifierProvider<VersionProvider>.value(value: version),
        ChangeNotifierProvider<ConfigProvider>.value(value: config),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: S.delegate.supportedLocales,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const MainFramework(),
      ),
    ));
    await tester.pump();

    expect(find.byType(SplashPage), findsNothing);
    expect(find.byType(TabBar), findsOneWidget);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.state<ScaffoldState>(find.byType(Scaffold)).isDrawerOpen,
        isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

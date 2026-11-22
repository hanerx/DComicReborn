import 'dart:async';

import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/drawer_page/favorite_page.dart';
import 'package:dcomic/view/settings/account_manage_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Account extends BaseComicAccountModel {
  @override
  bool isLogin = false;
  @override
  bool isLoading = false;
  @override
  String? token = 'retained-token';
  @override
  BaseComicSourceModel? parent;

  Completer<void>? refreshGate;
  bool verifyOnRefresh = false;
  int refreshes = 0;
  int logouts = 0;

  @override
  ImageEntity? get avatar => null;
  @override
  String? get nickname => isLogin ? '测试读者' : null;
  @override
  String? get uid => isLogin ? '42' : null;
  @override
  String? get username => isLogin ? 'reader' : null;

  @override
  Future<void> initAccount() async {
    refreshes++;
    isLoading = true;
    notifyListeners();
    await refreshGate?.future;
    isLogin = verifyOnRefresh;
    isLoading = false;
    notifyListeners();
  }

  @override
  Future<bool> logout() async {
    logouts++;
    token = null;
    isLogin = false;
    isLoading = false;
    notifyListeners();
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Source extends BaseComicSourceModel {
  _Source(this.accountModel) {
    accountModel.parent = this;
  }

  @override
  final _Account accountModel;

  @override
  ComicSourceEntity get type => ComicSourceEntity(
    '测试漫画源',
    'test-source',
    hasAccountSupport: true,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sources extends ComicSourceProvider {
  _Sources(_Source source) {
    for (final initial in sources) {
      initial.dispose();
    }
    sources = [source];
    isLoading = false;
  }

  @override
  Future<void> init() async {}
}

void main() {
  Future<_Account> showPage(WidgetTester tester, Widget page) async {
    final account = _Account();
    final source = _Source(account);
    final sources = _Sources(source);
    addTearDown(account.dispose);
    addTearDown(source.dispose);
    addTearDown(sources.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<ComicSourceProvider>.value(
      value: sources,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: page,
      ),
    ));
    await tester.pumpAndSettle();
    return account;
  }

  testWidgets('unverified account can retry without entering credentials again',
      (tester) async {
    final account = await showPage(tester, const AccountManagePage());
    expect(find.text('账户暂时无法验证'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(find.byIcon(Icons.login), findsNothing);

    account.refreshGate = Completer<void>();
    account.verifyOnRefresh = true;
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(account.refreshes, 1);
    expect(find.text('正在验证账户'), findsOneWidget);
    expect(account.token, 'retained-token');

    account.refreshGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('已登录'), findsOneWidget);
    expect(find.textContaining('测试读者'), findsOneWidget);
    expect(find.text('账户暂时无法验证'), findsNothing);
  });

  testWidgets('unverified account can explicitly sign out', (tester) async {
    final account = await showPage(tester, const AccountManagePage());
    expect(find.byIcon(Icons.logout), findsOneWidget);
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    expect(account.logouts, 1);
    expect(account.token, isNull);
    expect(find.byIcon(Icons.login), findsOneWidget);
    expect(find.text('账户暂时无法验证'), findsNothing);
  });

  testWidgets('favorites distinguish verification failure from signed out',
      (tester) async {
    final account = await showPage(tester, const FavoritePage());
    expect(find.text('账户暂时无法验证'), findsOneWidget);
    expect(find.text(S.current.JumpToLogin), findsNothing);

    account.refreshGate = Completer<void>();
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(account.refreshes, 1);
    expect(find.text('正在验证账户'), findsOneWidget);
    account.refreshGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('账户暂时无法验证'), findsOneWidget);
    expect(account.token, 'retained-token');

    await account.logout();
    await tester.pumpAndSettle();
    expect(find.text(S.current.RequireLogin), findsOneWidget);
    expect(find.text(S.current.JumpToLogin), findsOneWidget);
  });
}

import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/models/copymanga/copymanga_source_model.dart';
import 'package:dcomic/providers/models/zaimanhua/zaimanhua_source_model.dart';
import 'package:dcomic/view/settings/account_login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final entry in <String, BaseComicSourceModel Function()>{
    'CopyManga': CopyMangaComicSourceModel.new,
    'ZaiManHua': ZaiManHuaSourceModel.new,
  }.entries) {
    testWidgets('${entry.key} preserves editing when keyboard changes padding',
        (tester) async {
      final source = entry.value();
      addTearDown(source.dispose);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(bottom: 72);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: AccountLoginPage(sourceModel: source),
      ));
      await tester.pumpAndSettle();

      for (var index = 0; index < 3; index++) {
        final field = find.byType(TextFormField).at(index);
        await tester.ensureVisible(field);
        await tester.enterText(field, 'credential-$index');
        await tester.pump();
        tester.view.viewInsets = const FakeViewPadding(bottom: 900);
        tester.view.padding = FakeViewPadding.zero;
        await tester.pumpAndSettle();

        var editable = tester.widget<EditableText>(
          find.descendant(of: field, matching: find.byType(EditableText)),
        );
        expect(editable.focusNode.hasFocus, isTrue);
        expect(editable.controller.text, 'credential-$index');
        expect(tester.testTextInput.isVisible, isTrue);
        tester.testTextInput.updateEditingValue(
          TextEditingValue(text: 'continued-$index'),
        );
        await tester.pump();

        tester.view.viewInsets = FakeViewPadding.zero;
        tester.view.padding = const FakeViewPadding(bottom: 72);
        await tester.pumpAndSettle();
        editable = tester.widget<EditableText>(
          find.descendant(of: field, matching: find.byType(EditableText)),
        );
        expect(editable.controller.text, 'continued-$index');
        expect(editable.focusNode.hasFocus, isTrue);
      }
    });
  }
}

import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/view/comic_pages/comic_browser_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('detail stays selected across resize and full-window reading', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late NavigatorProvider navigation;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          return ChangeNotifierProvider(
            create: (_) => navigation = NavigatorProvider(context),
            child: const MaterialApp(
              home: ComicBrowserShell(child: _Library()),
            ),
          );
        },
      ),
    );
    await tester.tap(find.text('Comic A'));
    await tester.pumpAndSettle();
    expect(find.text('Comic A'), findsOneWidget);
    expect(find.text('Details A'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'retained');
    final left = tester.getRect(find.text('Comic A'));
    final right = tester.getRect(find.text('Details A'));
    expect(right.left, greaterThan(left.right));

    await tester.binding.setSurfaceSize(const Size(500, 800));
    await tester.pumpAndSettle();
    expect(find.text('Comic A'), findsNothing);
    expect(find.text('retained'), findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpAndSettle();
    expect(find.text('Comic A'), findsOneWidget);
    expect(find.text('retained'), findsOneWidget);

    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    expect(find.text('Comic A'), findsNothing);
    expect(tester.getSize(find.byKey(const ValueKey('reader'))).width, 1200);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Comic A'), findsOneWidget);
    expect(find.text('retained'), findsOneWidget);

    await tester.tap(find.text('Comic B'));
    await tester.pumpAndSettle();
    expect(find.text('Details A'), findsNothing);
    expect(find.text('Details B'), findsOneWidget);
    expect(find.text('retained'), findsNothing);
    await tester.binding.setSurfaceSize(const Size(500, 800));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Comic A'), findsOneWidget);
    expect(find.text('Details A'), findsNothing);
    expect(find.text('Details B'), findsNothing);
    expect(navigation.hasDetail, isFalse);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'browse routes stay on the left and system back closes detail first',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            return ChangeNotifierProvider(
              create: (_) => NavigatorProvider(context),
              child: const MaterialApp(
                home: ComicBrowserShell(child: _Library()),
              ),
            );
          },
        ),
      );
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comic A'));
      await tester.pumpAndSettle();
      expect(find.text('Search results'), findsOneWidget);
      expect(find.text('Details A'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Details A'), findsNothing);
      expect(find.text('Search results'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Library'), findsOneWidget);
    },
  );

  testWidgets('detail links browse beside the book on wide windows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          return ChangeNotifierProvider(
            create: (_) => NavigatorProvider(context),
            child: const MaterialApp(
              home: ComicBrowserShell(child: _Library()),
            ),
          );
        },
      ),
    );
    await tester.tap(find.text('Comic A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse author'));
    await tester.pumpAndSettle();
    expect(find.text('Search results'), findsOneWidget);
    expect(find.text('Details A'), findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(500, 800));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse author'));
    await tester.pumpAndSettle();
    expect(find.text('Details A'), findsNothing);
    expect(find.text('Search results'), findsOneWidget);
  });
}

class _Library extends StatelessWidget {
  const _Library({this.search = false});
  final bool search;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(search ? 'Search results' : 'Library')),
    body: Column(
      children: [
        if (!search)
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const _Library(search: true),
              ),
            ),
            child: const Text('Search'),
          ),
        for (final id in ['A', 'B'])
          TextButton(
            onPressed: () => context.read<NavigatorProvider>().showDetail(
              identity: id,
              builder: (_, embedded) => _Details(id: id),
            ),
            child: Text('Comic $id'),
          ),
      ],
    ),
  );
}

class _Details extends StatelessWidget {
  const _Details({required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Details $id')),
    body: Column(
      children: [
        const TextField(),
        TextButton(
          onPressed: () => context
              .read<NavigatorProvider>()
              .getNavigator(context, NavigatorType.defaultNavigator)
              ?.push(
                MaterialPageRoute<void>(
                  builder: (_) => const _Library(search: true),
                ),
              ),
          child: const Text('Browse author'),
        ),
        TextButton(
          onPressed: () => context
              .read<NavigatorProvider>()
              .getNavigator(context, NavigatorType.root)
              ?.push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    key: const ValueKey('reader'),
                    appBar: AppBar(title: const Text('Reader')),
                  ),
                ),
              ),
          child: const Text('Read'),
        ),
      ],
    ),
  );
}

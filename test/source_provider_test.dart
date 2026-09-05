import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/providers/models/copymanga/copymanga_source_model.dart';
import 'package:dcomic/providers/models/zaimanhua/zaimanhua_source_model.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _OfflineCopySource extends CopyMangaComicSourceModel {
  @override
  Future<void> initModel() async {}
}

class _OfflineZaiSource extends ZaiManHuaSourceModel {
  @override
  Future<void> initModel() async {}
}

class _RestorableSourceProvider extends ComicSourceProvider {
  _RestorableSourceProvider() {
    sources = [_OfflineCopySource(), _OfflineZaiSource()];
    logger = Logger(output: ConsoleOutput());
  }

  @override
  Future<void> init() async {}

  Future<void> restore() => super.init();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('source_restore_');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
  });

  setUp(() async {
    await (await DatabaseInstance.instance).database.delete('ConfigEntity');
  });

  tearDownAll(() async {
    await (await DatabaseInstance.instance).close();
    await directory.delete(recursive: true);
  });

  Future<void> saveSelection(Map<String, int> order, int index) async {
    final dao = (await DatabaseInstance.instance).configDao;
    await dao.getOrCreateConfigByKey('sourceModelSortOrder', value: order);
    await dao.getOrCreateConfigByKey('activeHomeModelIndex', value: index);
  }

  test('legacy source ordering restores Copy for both homepage and selector',
      () async {
    await saveSelection({'dmzj': 0, 'copymanga': 1, 'zaimanhua': 2}, 0);
    final provider = _RestorableSourceProvider();
    addTearDown(provider.dispose);
    await provider.restore();

    expect(provider.activeHomeModel.type.sourceId, 'copymanga');
    expect(
      provider.hasHomepageSources[provider.activeHomeModelIndex].type.sourceId,
      'copymanga',
    );
  });

  test('custom order stays consistent across source lists after startup',
      () async {
    await saveSelection({'copymanga': 1, 'zaimanhua': 0}, 0);
    final provider = _RestorableSourceProvider();
    addTearDown(provider.dispose);
    await provider.restore();

    expect(provider.activeHomeModel.type.sourceId, 'zaimanhua');
    for (final sources in [
      provider.hasHomepageSources,
      provider.hasAccountSettingSources,
      provider.orderedSources,
    ]) {
      expect(sources.map((source) => source.type.sourceId),
          ['zaimanhua', 'copymanga']);
    }
  });

  test('reordering sources preserves the selected homepage across restart',
      () async {
    await saveSelection({'copymanga': 0, 'zaimanhua': 1}, 0);
    final provider = _RestorableSourceProvider();
    addTearDown(provider.dispose);
    await provider.restore();
    provider.swapOrder(0, 1);
    // Wait for the persisted selection and sort order before restoring again.
    await (await DatabaseInstance.instance).configDao.getAllConfig();

    final restored = _RestorableSourceProvider();
    addTearDown(restored.dispose);
    await restored.restore();
    expect(restored.orderedSources.map((source) => source.type.sourceId),
        ['zaimanhua', 'copymanga']);
    expect(restored.activeHomeModel.type.sourceId, 'copymanga');
    expect(
      restored.hasHomepageSources[restored.activeHomeModelIndex].type.sourceId,
      'copymanga',
    );
  });
}

import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('history_order_');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
  });

  tearDownAll(() async {
    await (await DatabaseInstance.instance).close();
    await directory.delete(recursive: true);
  });

  test('history orders by latest reading time and moves reread comics first', () async {
    final dao = (await DatabaseInstance.instance).comicHistoryDao;
    Future<void> save(String comic, int? time, {String source = 'source'}) async {
      final row = await dao.getOrCreateConfigByComicId(comic, source);
      row.timestamp = time == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(time);
      await dao.updateComicHistory(row);
    }

    await save('100', 1000);
    await save('200', 2000);
    await save('000', null);
    await save('other', 9000, source: 'other-source');
    expect(
      (await dao.getComicHistoryByProvider('source')).map((row) => row.comicId),
      ['200', '100', '000'],
    );

    await save('100', 3000);
    expect(
      (await dao.getComicHistoryByProvider('source')).map((row) => row.comicId),
      ['100', '200', '000'],
    );
  });
}

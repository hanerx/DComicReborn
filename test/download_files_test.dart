import 'dart:convert';
import 'dart:io';

import 'package:dcomic/downloads/download_files.dart';
import 'package:crypto/crypto.dart';
import 'package:dcomic/downloads/download_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late DownloadFiles files;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('download_files_');
    files = DownloadFiles(root);
  });

  tearDown(() => root.delete(recursive: true));

  test('streams SHA-256 and length verification before atomic commit', () async {
    final staging = await files.prepareStaging('sample', 0);
    await staging.writeAsString('abc', flush: true);
    const integrity = DownloadIntegrity(
      expectedBytes: 3,
      sha256Hex:
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );

    await files.verify(staging, integrity);
    final committed = await files.commit(staging, 'files/sample.bin');

    expect(await committed.readAsString(), 'abc');
    expect(await staging.exists(), isFalse);
    expect(committed.path, files.resolve('files/sample.bin').path);
  });

  test('hash mismatch never publishes a destination file', () async {
    final staging = await files.prepareStaging('sample', 0);
    await staging.writeAsString('abd', flush: true);
    const integrity = DownloadIntegrity(
      expectedBytes: 3,
      sha256Hex:
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );

    await expectLater(files.verify(staging, integrity), throwsFormatException);

    expect(await files.resolve('files/sample.bin').exists(), isFalse);
  });

  test('length mismatch is rejected even without an expected digest', () async {
    final staging = await files.prepareStaging('sample', 0);
    await staging.writeAsString('abc', flush: true);

    await expectLater(
      files.verify(
        staging,
        const DownloadIntegrity(expectedBytes: 4),
      ),
      throwsFormatException,
    );
  });

  test('relative path traversal and absolute targets are rejected', () {
    expect(() => files.resolve('../outside.bin'), throwsArgumentError);
    expect(() => files.resolve(r'..\outside.bin'), throwsArgumentError);
    expect(() => files.resolve('/outside.bin'), throwsArgumentError);
    expect(() => files.resolve(r'C:\outside.bin'), throwsArgumentError);
  });

  test('commit is restart-idempotent when final file already exists', () async {
    final finalFile = files.resolve('files/sample.bin');
    await finalFile.parent.create(recursive: true);
    await finalFile.writeAsString('abc', flush: true);

    final recovered = await files.commit(
      files.staging('sample', 0),
      'files/sample.bin',
    );

    expect(recovered.path, finalFile.path);
    expect(await recovered.readAsString(), 'abc');
  });

  test('root with trailing separator still verifies and commits staged bytes', () async {
    final trailingRoot = DownloadFiles(Directory('${root.path}${Platform.pathSeparator}'));
    final staged = await trailingRoot.prepareStaging('trailing', 0);
    await staged.writeAsString('abc', flush: true);
    await trailingRoot.verify(staged, const DownloadIntegrity(expectedBytes: 3));
    final result = await trailingRoot.commit(staged, 'final.bin');
    expect(await result.readAsString(), 'abc');
  });

  test('public destinations cannot overwrite another task staging file', () async {
    final staged = await files.prepareStaging('other-task', 0);
    await staged.writeAsString('unfinished');
    final name = staged.uri.pathSegments.last;
    expect(() => files.resolve('.staging/$name'), throwsArgumentError);
    expect(await staged.readAsString(), 'unfinished');
  });

  test('linked final directory cannot delete or replace outside files', () async {
    final outside = await Directory.systemTemp.createTemp('download_outside_');
    addTearDown(() => outside.delete(recursive: true));
    final victim = File('${outside.path}${Platform.pathSeparator}victim.bin');
    await victim.writeAsString('outside', flush: true);
    try {
      await Link('${root.path}${Platform.pathSeparator}files').create(
        outside.path,
      );
    } on FileSystemException {
      markTestSkipped('platform cannot create directory links');
      return;
    }

    await expectLater(
      files.deleteFinal('files/victim.bin'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await victim.readAsString(), 'outside');

    final staged = await files.prepareStaging('sample', 0);
    await staged.writeAsString('replacement', flush: true);
    await expectLater(
      files.commit(staged, 'files/victim.bin'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await victim.readAsString(), 'outside');
  });

  test('linked staging directory cannot delete outside files', () async {
    final outside = await Directory.systemTemp.createTemp('staging_outside_');
    addTearDown(() => outside.delete(recursive: true));
    final stagedName =
        '${sha256.convert(utf8.encode('sample'))}.0.part';
    final victim = File(
      '${outside.path}${Platform.pathSeparator}$stagedName',
    );
    await victim.writeAsString('outside', flush: true);
    try {
      await Link(
        '${root.path}${Platform.pathSeparator}.staging',
      ).create(outside.path);
    } on FileSystemException {
      markTestSkipped('platform cannot create directory links');
      return;
    }

    await expectLater(
      files.prepareStaging('sample', 0),
      throwsA(isA<FileSystemException>()),
    );
    expect(await victim.readAsString(), 'outside');
  });
  test('public destinations cannot use the staging namespace', () {
    expect(
      () => DownloadRequest(
        id: 'reserved',
        url: Uri.parse('https://example.com/file'),
        relativePath: '.staging/final.bin',
        group: 'files',
      ),
      throwsArgumentError,
    );
  });

}

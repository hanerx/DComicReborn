import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dcomic/downloads/download_models.dart';
import 'package:path/path.dart' as p;

class DownloadFiles {
  final Directory root;

  DownloadFiles(this.root);

  Future<void> initialize() => root.create(recursive: true);

  File staging(String id, int generation) {
    final relative =
        '.staging/${sha256.convert(utf8.encode(id))}.$generation.part';
    _assertSafeRelative(relative);
    return File(
      '${root.path}${Platform.pathSeparator}'
      '${relative.replaceAll('/', Platform.pathSeparator)}',
    );
  }

  String stagingPath(String id, int generation) => staging(id, generation).path;

  Future<File> prepareStaging(String id, int generation) async {
    final file = staging(id, generation);
    _assertManagedFile(file, stagingOnly: true);
    await file.parent.create(recursive: true);
    _assertManagedFile(file, stagingOnly: true);
    if (await file.exists()) await file.delete();
    return file;
  }

  File resolve(String relativePath) {
    validateRelativeDownloadPath(relativePath);
    if (relativePath.replaceAll('\\', '/').split('/').first.toLowerCase() ==
        '.staging') {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'reserved staging namespace',
      );
    }
    _assertSafeRelative(relativePath);
    final segments = relativePath.replaceAll('\\', '/').split('/');
    return File(
      '${root.path}${Platform.pathSeparator}'
      '${segments.join(Platform.pathSeparator)}',
    );
  }

  Future<void> verify(File file, DownloadIntegrity integrity) async {
    _assertManagedFile(file);
    if (!await file.exists()) {
      throw FileSystemException('downloaded file is missing', file.path);
    }
    final actualBytes = await file.length();
    final expectedBytes = integrity.expectedBytes;
    if (expectedBytes != null && actualBytes != expectedBytes) {
      throw const FormatException('download length mismatch');
    }
    final expectedSha256 = integrity.normalizedSha256;
    if (expectedSha256 != null) {
      final actualSha256 = (await sha256.bind(file.openRead()).first)
          .toString();
      if (actualSha256 != expectedSha256) {
        throw const FormatException('download SHA-256 mismatch');
      }
    }
  }

  /// Flushes staged bytes and publishes them with a same-filesystem rename.
  /// If a prior run already renamed the file, its path is returned for the
  /// caller to verify before committing business state.
  Future<File> commit(File staged, String relativePath) async {
    final destination = resolve(relativePath);
    _assertManagedFile(staged, stagingOnly: true);
    _assertSafeRelative(relativePath);
    if (!await staged.exists()) {
      if (await destination.exists()) return destination;
      throw FileSystemException('staged download is missing', staged.path);
    }
    await destination.parent.create(recursive: true);
    _assertSafeRelative(relativePath);
    _assertManagedFile(staged, stagingOnly: true);
    final handle = await staged.open(mode: FileMode.append);
    try {
      await handle.flush();
    } finally {
      await handle.close();
    }
    _assertManagedFile(staged, stagingOnly: true);
    _assertSafeRelative(relativePath);
    if (await destination.exists()) await destination.delete();
    return staged.rename(destination.path);
  }

  Future<void> deleteStaging(String id, int generation) async {
    final file = staging(id, generation);
    _assertManagedFile(file, stagingOnly: true);
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteAllStaging(String id) async {
    const relative = '.staging';
    _assertSafeRelative(relative);
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}.staging',
    );
    if (!await directory.exists()) return;
    _assertSafeRelative(relative);
    final prefix = '${sha256.convert(utf8.encode(id))}.';
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File) {
        final name = entry.path.substring(
          entry.path.lastIndexOf(Platform.pathSeparator) + 1,
        );
        if (name.startsWith(prefix) && name.endsWith('.part')) {
          await entry.delete();
        }
      }
    }
  }

  Future<void> deleteFinal(String relativePath) async {
    final file = resolve(relativePath);
    _assertSafeRelative(relativePath);
    if (await file.exists()) await file.delete();
  }

  void _assertManagedFile(File file, {bool stagingOnly = false}) {
    final rootPath = _normalizedAbsolute(root.path);
    final filePath = _normalizedAbsolute(file.path);
    final prefix = '$rootPath/';
    if (!filePath.startsWith(prefix)) {
      throw FileSystemException(
        'download path escapes managed root',
        file.path,
      );
    }
    final relative = filePath.substring(prefix.length);
    if (stagingOnly && !relative.startsWith('.staging/')) {
      throw FileSystemException('invalid staging path', file.path);
    }
    _assertSafeRelative(relative);
  }

  void _assertSafeRelative(String relativePath) {
    validateRelativeDownloadPath(relativePath);
    final rootCanonical = _canonical(root);
    var current = root.path;
    for (final segment in relativePath.replaceAll('\\', '/').split('/')) {
      current = '$current${Platform.pathSeparator}$segment';
      final type = FileSystemEntity.typeSync(current, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type == FileSystemEntityType.link) {
        throw FileSystemException(
          'download path traverses a filesystem link',
          current,
        );
      }
      final resolved = _canonical(
        FileSystemEntity.isDirectorySync(current)
            ? Directory(current)
            : File(current),
      );
      if (!_isWithin(rootCanonical, resolved)) {
        throw FileSystemException(
          'download path escapes managed root',
          current,
        );
      }
    }
  }

  String _canonical(FileSystemEntity entity) =>
      _normalizedAbsolute(entity.resolveSymbolicLinksSync());

  String _normalizedAbsolute(String path) {
    var normalized = p.normalize(p.absolute(path)).replaceAll('\\', '/');
    while (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  bool _isWithin(String rootPath, String candidate) =>
      candidate == rootPath || candidate.startsWith('$rootPath/');
}

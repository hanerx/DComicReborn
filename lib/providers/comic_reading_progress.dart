import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/comic_history.dart';
import 'package:dcomic/utils/comic_mapping_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:pinyin/pinyin.dart';

class ComicReadingProgress {
  static const configKey = 'AggregateReadingProgress';
  static final changes = ChangeNotifier();
  static final _whitespace = RegExp(r'\s+', unicode: true);

  static String _chapterTitle(String title) {
    // Fold only full-width ASCII and whitespace, not chapter numbers, types,
    // suffixes or punctuation. In particular, volumes and extras stay distinct.
    final widthFolded = String.fromCharCodes(
      title.runes.map((rune) {
        if (rune >= 0xff01 && rune <= 0xff5e) return rune - 0xfee0;
        return rune == 0x3000 ? 0x20 : rune;
      }),
    );
    return ChineseHelper.convertToSimplifiedChinese(widthFolded)
        .replaceAll(_whitespace, '');
  }

  /// Returns a current-source chapter ID, never a foreign chapter ID. The
  /// catalog callback stays lazy so disabled/unbound books do no matching work.
  static Future<String?> resolve({
    required String sourceId,
    required String comicId,
    required ComicHistoryEntity? local,
    required Iterable<(String, String)> Function() chapters,
  }) async {
    final localId = local?.lastChapterId;
    final fallback = localId == null || localId.isEmpty ? null : localId;
    final database = await DatabaseInstance.instance;
    final setting = await database.configDao.getConfigByKey(configKey);
    if (setting?.get<bool>() != true) return localId;
    // An undated existing record cannot safely be ordered against another one.
    if (fallback != null && local?.timestamp == null) return fallback;
    final origin = (sourceId, comicId);
    final mappings = await database.comicMappingDao.getAllComicMappingEntity();
    List<(String, String)>? related;
    for (final group in reliableComicGroups(mappings)) {
      if (group.contains(origin)) {
        related = group;
        break;
      }
    }
    if (related == null) return fallback;

    Map<String, String?>? byTitle;
    var selected = fallback;
    var latest = fallback == null ? null : local?.timestamp;
    var ambiguous = false;
    for (final (provider, id) in related) {
      if ((provider, id) == origin) continue;
      final record = await database.comicHistoryDao.getComicHistoryByComicId(
        id,
        provider,
      );
      final timestamp = record?.timestamp;
      if (record == null || record.lastChapterId.isEmpty || timestamp == null) {
        continue;
      }
      if (latest != null && timestamp.isBefore(latest)) continue;
      // Equal timestamps keep the local record; no source-order tie breaker.
      if (fallback != null && timestamp == local?.timestamp) continue;
      final title = _chapterTitle(record.lastChapterTitle);
      if (title.isEmpty) continue;
      if (byTitle == null) {
        byTitle = {};
        for (final (chapterId, chapterTitle) in chapters()) {
          final normalized = _chapterTitle(chapterTitle);
          if (normalized.isEmpty || chapterId.isEmpty) continue;
          byTitle[normalized] = byTitle.containsKey(normalized)
              ? null
              : chapterId;
        }
      }
      final match = byTitle[title];
      if (match == null) continue;
      if (timestamp == latest) {
        if (selected != match) ambiguous = true;
      } else {
        latest = timestamp;
        selected = match;
        ambiguous = false;
      }
    }
    return ambiguous ? fallback : selected;
  }
}

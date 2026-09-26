import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/comic_history.dart';
import 'package:dcomic/providers/chapter_rule_store.dart';
import 'package:dcomic/utils/chapter_matching_rules.dart';
import 'package:dcomic/utils/comic_mapping_utils.dart';

class ComicReadingProgress {
  static const configKey = 'AggregateReadingProgress';
  static final changes = ChapterRuleStore.changes;

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
    ChapterRuleMatcher? rules;
    final byRule = <(int, String), String?>{};
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
      final title = normalizeChapterTitle(record.lastChapterTitle);
      if (title.isEmpty) continue;
      if (byTitle == null) {
        byTitle = {};
        rules = ChapterRuleMatcher(await ChapterRuleStore.load());
        for (final (chapterId, chapterTitle) in chapters()) {
          final normalized = normalizeChapterTitle(chapterTitle);
          if (normalized.isEmpty || chapterId.isEmpty) continue;
          byTitle[normalized] = byTitle.containsKey(normalized)
              ? null
              : chapterId;
          final rule = rules.matchNormalized(normalized);
          if (rule != null) {
            final key = (rule.groupIndex, rule.number);
            byRule[key] = byRule.containsKey(key) ? null : chapterId;
          }
        }
      }
      // Exact titles retain precedence, including an ambiguous exact title.
      // Regex matching only supplements titles with no exact counterpart.
      var match = byTitle[title];
      if (!byTitle.containsKey(title)) {
        final rule = rules!.matchNormalized(title);
        if (rule != null) match = byRule[(rule.groupIndex, rule.number)];
      }
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

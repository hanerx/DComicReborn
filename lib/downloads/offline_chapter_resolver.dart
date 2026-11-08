import 'package:dcomic/database/entity/comic_mapping.dart';
import 'package:dcomic/downloads/comic_download_models.dart';
import 'package:dcomic/downloads/offline_comic_store.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/models/offline_comic_model.dart';
import 'package:dcomic/utils/chapter_matching_rules.dart';
import 'package:dcomic/utils/comic_mapping_utils.dart';

typedef OfflineMappingLoader = Future<List<ComicMappingEntity>> Function();
typedef OfflineRuleLoader = Future<List<ChapterRuleGroup>> Function();

class OfflineChapterResolver {
  final OfflineComicStore store;
  final OfflineMappingLoader mappingLoader;
  final OfflineRuleLoader ruleLoader;
  final bool Function() aggregateDownloads;
  final bool Function() reuseAcrossSources;
  final OfflineChapterCommentsLoader? commentLoader;

  const OfflineChapterResolver({
    required this.store,
    required this.mappingLoader,
    required this.ruleLoader,
    required this.aggregateDownloads,
    required this.reuseAcrossSources,
    this.commentLoader,
  });

  void install() {
    BaseComicDetailModel.installOfflineResolver(resolve);
  }

  Future<BaseComicChapterDetailModel?> resolve(
    BaseComicDetailModel detail,
    String requestedChapterId,
  ) async {
    final availability = await this.availability(
      detail,
      requestedChapterId,
      includeMapped:
          detail is! OfflineComicDetailModel &&
          aggregateDownloads() &&
          reuseAcrossSources(),
    );
    final selected = availability.preferred;
    if (selected == null) return null;
    final root = await store.transfers.rootDirectory;
    return OfflineComicChapterDetailModel.fromSnapshot(
      snapshot: selected,
      requested: availability.requested,
      rootDirectory: root,
      commentsLoader: commentLoader,
    );
  }

  /// Computes local badge/selection facts only. It never touches a source
  /// registry, remote detail or chapter API.
  Future<OfflineChapterAvailability> availability(
    BaseComicDetailModel detail,
    String requestedChapterId, {
    required bool includeMapped,
  }) async {
    final requested = (
      sourceId: detail.parent.type.sourceId,
      comicId: detail.comicId,
      chapterId: requestedChapterId,
    );
    final requestedChapter = _findRequestedChapter(detail, requestedChapterId);
    if (requestedChapter == null) {
      return OfflineChapterAvailability(
        requested: requested,
        ownComplete: null,
        alternateCompletes: const [],
        preferred: null,
      );
    }

    final own = await _findById(
      await store.listReadableChapters((
        sourceId: requested.sourceId,
        comicId: requested.comicId,
      )),
      requested.chapterId,
    );
    if (!includeMapped) {
      return OfflineChapterAvailability(
        requested: requested,
        ownComplete: own,
        alternateCompletes: const [],
        preferred: own,
      );
    }

    final mappings = await mappingLoader();
    final origin = (requested.sourceId, requested.comicId);
    List<(String, String)>? related;
    for (final group in reliableComicGroups(mappings)) {
      if (group.contains(origin)) {
        related = group;
        break;
      }
    }
    if (related == null) {
      return OfflineChapterAvailability(
        requested: requested,
        ownComplete: own,
        alternateCompletes: const [],
        preferred: own,
      );
    }

    final matcher = ChapterRuleMatcher(await ruleLoader());
    if (_requestedCatalogIsAmbiguous(detail, requestedChapter, matcher)) {
      return OfflineChapterAvailability(
        requested: requested,
        ownComplete: own,
        alternateCompletes: const [],
        preferred: own,
      );
    }

    final alternates = <OfflineChapterSnapshot>[];
    for (final node in related) {
      if (node == origin) continue;
      final comic = await store.loadComicSnapshot((
        sourceId: node.$1,
        comicId: node.$2,
      ));
      if (comic == null || comic.catalog.isEmpty) continue;
      final catalogMatches = [
        for (final chapter in comic.catalog)
          if (_equivalent(requestedChapter.rawTitle, chapter.rawTitle, matcher))
            chapter,
      ];
      // Uniqueness is established against the persisted full source catalog,
      // not merely whichever candidates currently have readable files.
      if (catalogMatches.length > 1) {
        return OfflineChapterAvailability(
          requested: requested,
          ownComplete: own,
          alternateCompletes: const [],
          preferred: own,
        );
      }
      if (catalogMatches.length != 1) continue;
      final chapters = await store.listReadableChapters((
        sourceId: node.$1,
        comicId: node.$2,
      ));
      final match = await _findById(chapters, catalogMatches.single.chapterId);
      if (match != null) alternates.add(match);
    }
    alternates.sort(_compareCompleted);
    return OfflineChapterAvailability(
      requested: requested,
      ownComplete: own,
      alternateCompletes: alternates,
      preferred: own ?? (alternates.isEmpty ? null : alternates.first),
    );
  }

  BaseComicChapterEntityModel? _findRequestedChapter(
    BaseComicDetailModel detail,
    String chapterId,
  ) {
    BaseComicChapterEntityModel? result;
    for (final chapter in detail.chapterCatalog.values.expand((group) => group)) {
      if (chapter.chapterId != chapterId) continue;
      if (result != null) return null;
      result = chapter;
    }
    return result;
  }

  bool _requestedCatalogIsAmbiguous(
    BaseComicDetailModel detail,
    BaseComicChapterEntityModel requested,
    ChapterRuleMatcher matcher,
  ) {
    var equivalents = 0;
    // Version variants share one logical chapter and must not make matching
    // ambiguous merely because the source exposes every UUID for persistence.
    for (final chapter in detail.chapters.values.expand((group) => group)) {
      if (_equivalent(requested.rawTitle, chapter.rawTitle, matcher)) {
        equivalents++;
        if (equivalents > 1) return true;
      }
    }
    return false;
  }

  bool _equivalent(
    String requestedTitle,
    String candidateTitle,
    ChapterRuleMatcher matcher,
  ) {
    final requestedNormalized = normalizeChapterTitle(requestedTitle);
    final candidateNormalized = normalizeChapterTitle(candidateTitle);
    if (requestedNormalized.isEmpty || candidateNormalized.isEmpty)
      return false;
    if (requestedNormalized == candidateNormalized) return true;
    final requestedMatch = matcher.matchNormalized(requestedNormalized);
    final candidateMatch = matcher.matchNormalized(candidateNormalized);
    return requestedMatch != null &&
        candidateMatch != null &&
        requestedMatch.groupIndex == candidateMatch.groupIndex &&
        requestedMatch.number == candidateMatch.number;
  }

  Future<OfflineChapterSnapshot?> _findById(
    List<OfflineChapterSnapshot> chapters,
    String chapterId,
  ) async {
    for (final chapter in chapters) {
      if (chapter.key.chapterId == chapterId) return chapter;
    }
    return null;
  }

  int _compareCompleted(
    OfflineChapterSnapshot left,
    OfflineChapterSnapshot right,
  ) {
    final leftTime = left.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightTime =
        right.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final time = leftTime.compareTo(rightTime);
    if (time != 0) return time;
    final source = left.key.sourceId.compareTo(right.key.sourceId);
    if (source != 0) return source;
    return left.key.chapterId.compareTo(right.key.chapterId);
  }
}

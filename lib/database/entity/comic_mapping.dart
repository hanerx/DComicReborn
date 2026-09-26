import 'package:dcomic/database/entity/entity_base.dart';
import 'package:floor_community/floor.dart';

@Entity(
  primaryKeys: ['providerA', 'comicA', 'providerB', 'comicB'],
  indices: [
    Index(value: ['providerB', 'comicB', 'providerA']),
  ],
)
class ComicMappingEntity extends EntityBase {
  final String providerA;
  final String comicA;
  final String providerB;
  final String comicB;
  final bool blocked;

  ComicMappingEntity(
    this.providerA,
    this.comicA,
    this.providerB,
    this.comicB,
    this.blocked,
  );

  factory ComicMappingEntity.between(
    String provider,
    String comic,
    String otherProvider,
    String otherComic, {
    bool blocked = false,
  }) {
    final providerOrder = provider.compareTo(otherProvider);
    final ordered = providerOrder < 0 ||
        (providerOrder == 0 && comic.compareTo(otherComic) <= 0);
    return ordered
        ? ComicMappingEntity(
            provider,
            comic,
            otherProvider,
            otherComic,
            blocked,
          )
        : ComicMappingEntity(
            otherProvider,
            otherComic,
            provider,
            comic,
            blocked,
          );
  }
}

typedef _ComicMappingKey = (String, String, String, String);

@dao
abstract class ComicMappingDao {
  @Query('SELECT * FROM ComicMappingEntity')
  Future<List<ComicMappingEntity>> getAllComicMappingEntity();

  @Query(
    'SELECT * FROM ComicMappingEntity '
    'WHERE (`providerA` = :provider AND `comicA` = :comicId '
    'AND `providerB` = :otherProvider) '
    'OR (`providerB` = :provider AND `comicB` = :comicId '
    'AND `providerA` = :otherProvider)',
  )
  Future<List<ComicMappingEntity>> getIncidentComicMappings(
    String comicId,
    String provider,
    String otherProvider,
  );

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertComicMapping(ComicMappingEntity comicMappingEntity);

  /// Returns `null` for no stored decision, an empty string for suppression or
  /// ambiguity, and the unique active counterpart otherwise.
  Future<String?> lookupComicId(
    String comicId,
    String provider,
    String otherProvider,
  ) async {
    String? activeComicId;
    var activeConflict = false;
    var suppressed = false;
    for (final mapping
        in await getIncidentComicMappings(comicId, provider, otherProvider)) {
      final counterpart = _counterpart(mapping, comicId, provider);
      if (mapping.blocked || counterpart.isEmpty) {
        suppressed = true;
      } else if (activeComicId == null) {
        activeComicId = counterpart;
      } else if (activeComicId != counterpart) {
        activeConflict = true;
      }
    }
    if (activeConflict) {
      return '';
    }
    return activeComicId ?? (suppressed ? '' : null);
  }

  /// Applies a manual bind or unbind atomically.
  ///
  /// An empty [otherComicId] means unbind. Displaced active edges are retained
  /// as suppression records so automatic matching cannot recreate them.
  @transaction
  Future<void> bindComic(
    String comicId,
    String provider,
    String otherProvider,
    String otherComicId,
  ) async {
    if (comicId.isEmpty) {
      throw ArgumentError.value(comicId, 'comicId', 'must not be empty');
    }
    if (otherComicId.isEmpty) {
      final incident =
          await getIncidentComicMappings(comicId, provider, otherProvider);
      var blockedActiveEdge = false;
      for (final mapping in incident) {
        if (!mapping.blocked) {
          blockedActiveEdge = true;
          await insertComicMapping(_withBlocked(mapping));
        }
      }
      if (!blockedActiveEdge) {
        await insertComicMapping(
          ComicMappingEntity.between(
            provider,
            comicId,
            otherProvider,
            '',
            blocked: true,
          ),
        );
      }
      return;
    }

    final desired = ComicMappingEntity.between(
      provider,
      comicId,
      otherProvider,
      otherComicId,
    );
    final incident = <_ComicMappingKey, ComicMappingEntity>{};
    for (final mapping
        in await getIncidentComicMappings(comicId, provider, otherProvider)) {
      incident[_key(mapping)] = mapping;
    }
    for (final mapping in await getIncidentComicMappings(
      otherComicId,
      otherProvider,
      provider,
    )) {
      incident[_key(mapping)] = mapping;
    }
    final desiredKey = _key(desired);
    for (final entry in incident.entries) {
      if (!entry.value.blocked && entry.key != desiredKey) {
        await insertComicMapping(_withBlocked(entry.value));
      }
    }
    await insertComicMapping(desired);
  }

  /// Inserts an automatic edge only while both endpoints have no stored state.
  ///
  /// The caller-side result wins unchanged. Any occupied, suppressed, or
  /// ambiguous counterpart prevents insertion and returns an empty string.
  @transaction
  Future<String> insertAutomaticMappingIfAbsent(
    String comicId,
    String provider,
    String otherProvider,
    String otherComicId,
  ) async {
    if (comicId.isEmpty || otherComicId.isEmpty) {
      return '';
    }
    final callerResult =
        await lookupComicId(comicId, provider, otherProvider);
    if (callerResult != null) {
      return callerResult;
    }
    final counterpartResult =
        await lookupComicId(otherComicId, otherProvider, provider);
    if (counterpartResult != null) {
      return '';
    }
    await insertComicMapping(
      ComicMappingEntity.between(
        provider,
        comicId,
        otherProvider,
        otherComicId,
      ),
    );
    return otherComicId;
  }

  static String _counterpart(
    ComicMappingEntity mapping,
    String comicId,
    String provider,
  ) {
    if (mapping.providerA == provider && mapping.comicA == comicId) {
      return mapping.comicB;
    }
    return mapping.comicA;
  }

  static _ComicMappingKey _key(ComicMappingEntity mapping) => (
        mapping.providerA,
        mapping.comicA,
        mapping.providerB,
        mapping.comicB,
      );

  static ComicMappingEntity _withBlocked(ComicMappingEntity mapping) =>
      ComicMappingEntity(
        mapping.providerA,
        mapping.comicA,
        mapping.providerB,
        mapping.comicB,
        true,
      );
}

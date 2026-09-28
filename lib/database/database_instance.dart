import 'package:dcomic/database/database_common.dart';
import 'package:dcomic/database/entity/chapter_rule.dart';
import 'package:dcomic/database/sync/sync_store.dart';
import 'package:floor_community/floor.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

class DatabaseInstance {
  static final List<Migration> migrations = [
    Migration(2, 3, (database) async {
      await database.execute(
        'CREATE TABLE IF NOT EXISTS `ModelConfigEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `key` TEXT NOT NULL, `value` TEXT, `sourceModel` TEXT)',
      );
    }),
    Migration(4, 5, (database) async {
      await database.execute(
        'CREATE TABLE IF NOT EXISTS `ComicSubscribeStateEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `comicId` TEXT NOT NULL, `timestamp` INTEGER, `providerName` TEXT NOT NULL)',
      );
    }),
    Migration(5, 6, (database) async {
      await createChapterRuleTables(database);
      await seedChapterRuleDefaults(database);
    }),
    Migration(6, 7, _migrateComicMappingsToV7),
    Migration(7, 8, (database) async {
      await database.execute(
        'ALTER TABLE `ComicHistoryEntity` ADD COLUMN `lastPage` INTEGER NOT NULL DEFAULT 1',
      );
    }),
  ];

  /// 新装数据库建表完成后写入默认章节匹配分组；升级场景由 5 -> 6 迁移负责。
  static final Callback databaseCallback = Callback(
    onCreate: (database, _) => seedChapterRuleDefaults(database),
    onOpen: SyncStore.installSchema,
  );

  static Future<DComicDatabase>? _databaseFuture;
  static SyncStore? _syncStore;

  static Future<DComicDatabase> get instance =>
      _databaseFuture ??= _initialize();

  static SyncStore get syncStore => _syncStore ??
      (throw StateError(
        'DatabaseInstance.instance must be awaited before accessing syncStore',
      ));

  static Future<DComicDatabase> _initialize() async {
    final database = await $FloorDComicDatabase
        .databaseBuilder('dcomic.db')
        .addMigrations(migrations)
        .addCallback(databaseCallback)
        .build();
    try {
      _syncStore = await SyncStore.attach(database);
      return database;
    } on Object {
      await database.close();
      rethrow;
    }
  }
}

typedef _ComicEndpoint = ({String provider, String comic});
typedef _ComicEdgeKey = (
  String providerA,
  String comicA,
  String providerB,
  String comicB,
);

class _MigratedComicEdge {
  final _ComicEndpoint endpointA;
  final _ComicEndpoint endpointB;
  final bool blocked;

  const _MigratedComicEdge(
    this.endpointA,
    this.endpointB, {
    required this.blocked,
  });

  _ComicEdgeKey get key => (
        endpointA.provider,
        endpointA.comic,
        endpointB.provider,
        endpointB.comic,
      );

  _MigratedComicEdge asBlocked() =>
      _MigratedComicEdge(endpointA, endpointB, blocked: true);
}

class _ComicComponent {
  final Set<_ComicEndpoint> endpoints;
  final Set<_ComicEdgeKey> edges;

  const _ComicComponent(this.endpoints, this.edges);
}

Future<void> _migrateComicMappingsToV7(sqflite.Database database) async {
  final legacyRows = await database.query('ComicMappingEntity');
  final activeEdges = <_ComicEdgeKey, _MigratedComicEdge>{};
  final blockedEdges = <_ComicEdgeKey, _MigratedComicEdge>{};

  for (final row in legacyRows) {
    final source = (
      provider: row['sourceProviderName'] as String,
      comic: row['comicId'] as String,
    );
    final target = (
      provider: row['targetProviderName'] as String,
      comic: row['resultComicId'] as String,
    );
    final edge = _canonicalComicEdge(
      source,
      target,
      blocked: target.comic.isEmpty,
    );
    if (edge.blocked) {
      blockedEdges.putIfAbsent(edge.key, () => edge);
    } else {
      activeEdges.putIfAbsent(edge.key, () => edge);
    }
  }

  final adjacency = <_ComicEndpoint, Set<_ComicEndpoint>>{};
  final endpointEdges = <_ComicEndpoint, Set<_ComicEdgeKey>>{};
  for (final edge in activeEdges.values) {
    (adjacency[edge.endpointA] ??= <_ComicEndpoint>{}).add(edge.endpointB);
    (adjacency[edge.endpointB] ??= <_ComicEndpoint>{}).add(edge.endpointA);
    (endpointEdges[edge.endpointA] ??= <_ComicEdgeKey>{}).add(edge.key);
    (endpointEdges[edge.endpointB] ??= <_ComicEdgeKey>{}).add(edge.key);
  }

  final components = <_ComicComponent>[];
  final componentByEndpoint = <_ComicEndpoint, int>{};
  for (final start in adjacency.keys) {
    if (componentByEndpoint.containsKey(start)) {
      continue;
    }
    final componentIndex = components.length;
    final pending = <_ComicEndpoint>[start];
    final endpoints = <_ComicEndpoint>{};
    final edges = <_ComicEdgeKey>{};
    while (pending.isNotEmpty) {
      final endpoint = pending.removeLast();
      if (!endpoints.add(endpoint)) {
        continue;
      }
      componentByEndpoint[endpoint] = componentIndex;
      edges.addAll(endpointEdges[endpoint] ?? const <_ComicEdgeKey>{});
      for (final neighbor
          in adjacency[endpoint] ?? const <_ComicEndpoint>{}) {
        if (!endpoints.contains(neighbor)) {
          pending.add(neighbor);
        }
      }
    }
    components.add(_ComicComponent(endpoints, edges));
  }

  final unreliableComponents = <int>{};
  for (var index = 0; index < components.length; index++) {
    final component = components[index];
    final providerCounts = <String, int>{};
    for (final endpoint in component.endpoints) {
      providerCounts.update(
        endpoint.provider,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final hasDuplicateProvider =
        providerCounts.values.any((count) => count > 1);
    final isSingleSameProviderOverride = component.edges.length == 1 &&
        component.endpoints.length == 2 &&
        providerCounts.length == 1;
    if (hasDuplicateProvider && !isSingleSameProviderOverride) {
      unreliableComponents.add(index);
    }
  }

  for (final blocked in blockedEdges.values) {
    final _ComicEndpoint knownEndpoint;
    final String unknownProvider;
    if (blocked.endpointA.comic.isEmpty) {
      knownEndpoint = blocked.endpointB;
      unknownProvider = blocked.endpointA.provider;
    } else if (blocked.endpointB.comic.isEmpty) {
      knownEndpoint = blocked.endpointA;
      unknownProvider = blocked.endpointB.provider;
    } else {
      continue;
    }
    final componentIndex = componentByEndpoint[knownEndpoint];
    if (componentIndex == null) {
      continue;
    }
    final conflictsWithActive =
        (adjacency[knownEndpoint] ?? const <_ComicEndpoint>{})
                .any((endpoint) => endpoint.provider == unknownProvider) ||
            components[componentIndex].endpoints.any(
              (endpoint) =>
                  endpoint != knownEndpoint &&
                  endpoint.provider == unknownProvider,
            );
    if (conflictsWithActive) {
      unreliableComponents.add(componentIndex);
    }
  }

  final migratedEdges = <_ComicEdgeKey, _MigratedComicEdge>{
    ...blockedEdges,
  };
  for (final edge in activeEdges.values) {
    final componentIndex = componentByEndpoint[edge.endpointA]!;
    migratedEdges[edge.key] = unreliableComponents.contains(componentIndex)
        ? edge.asBlocked()
        : edge;
  }

  await database.execute(
    'ALTER TABLE `ComicMappingEntity` RENAME TO `ComicMappingEntity_v6`',
  );
  await database.execute(
    'CREATE TABLE `ComicMappingEntity` ('
    '`providerA` TEXT NOT NULL, '
    '`comicA` TEXT NOT NULL, '
    '`providerB` TEXT NOT NULL, '
    '`comicB` TEXT NOT NULL, '
    '`blocked` INTEGER NOT NULL, '
    'PRIMARY KEY (`providerA`, `comicA`, `providerB`, `comicB`))',
  );
  await database.execute(
    'CREATE INDEX `index_ComicMappingEntity_providerB_comicB_providerA` '
    'ON `ComicMappingEntity` (`providerB`, `comicB`, `providerA`)',
  );
  for (final edge in migratedEdges.values) {
    await database.execute(
      'INSERT INTO `ComicMappingEntity` '
      '(`providerA`, `comicA`, `providerB`, `comicB`, `blocked`) '
      'VALUES (?, ?, ?, ?, ?)',
      [
        edge.endpointA.provider,
        edge.endpointA.comic,
        edge.endpointB.provider,
        edge.endpointB.comic,
        edge.blocked ? 1 : 0,
      ],
    );
  }
  await database.execute('DROP TABLE `ComicMappingEntity_v6`');
}

_MigratedComicEdge _canonicalComicEdge(
  _ComicEndpoint endpoint,
  _ComicEndpoint otherEndpoint, {
  required bool blocked,
}) {
  final providerOrder = endpoint.provider.compareTo(otherEndpoint.provider);
  final ordered = providerOrder < 0 ||
      (providerOrder == 0 &&
          endpoint.comic.compareTo(otherEndpoint.comic) <= 0);
  return ordered
      ? _MigratedComicEdge(endpoint, otherEndpoint, blocked: blocked)
      : _MigratedComicEdge(otherEndpoint, endpoint, blocked: blocked);
}

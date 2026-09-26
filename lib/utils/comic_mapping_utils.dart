import 'package:dcomic/database/entity/comic_mapping.dart';

/// Connected identity groups formed by active undirected bindings.
///
/// Suppression records are not identities. A component containing more than
/// one comic from the same provider is ambiguous and is omitted as a whole.
Iterable<List<(String, String)>> reliableComicGroups(
  Iterable<ComicMappingEntity> mappings,
) sync* {
  final edges = <(String, String), Set<(String, String)>>{};
  for (final row in mappings) {
    if (row.blocked || row.comicA.isEmpty || row.comicB.isEmpty) continue;
    final a = (row.providerA, row.comicA);
    final b = (row.providerB, row.comicB);
    (edges[a] ??= {}).add(b);
    (edges[b] ??= {}).add(a);
  }

  final visited = <(String, String)>{};
  for (final root in edges.keys) {
    if (!visited.add(root)) continue;
    final group = [root];
    final providers = <String>{};
    var ambiguous = false;
    for (var i = 0; i < group.length; i++) {
      final node = group[i];
      if (!providers.add(node.$1)) ambiguous = true;
      for (final neighbor in edges[node]!) {
        if (visited.add(neighbor)) group.add(neighbor);
      }
    }
    if (!ambiguous) yield group;
  }
}

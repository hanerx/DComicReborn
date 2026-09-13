import 'package:dcomic/database/entity/comic_mapping.dart';

/// Bidirectional identity groups from stored bindings only. Explicit unbinding,
/// conflicting reverse bindings and same-source ambiguity must not merge books.
Iterable<List<(String, String)>> reliableComicGroups(
  Iterable<ComicMappingEntity> mappings,
) sync* {
  final directed = <(String, String, String), Set<String>>{};
  for (final row in mappings) {
    (directed[(row.sourceProviderName, row.comicId, row.targetProviderName)] ??=
            <String>{})
        .add(row.resultComicId);
  }
  final edges = <(String, String), Set<(String, String)>>{};
  final conflicting = <(String, String)>{};
  for (final entry in directed.entries) {
    final (source, id, target) = entry.key;
    if (source == target) continue;
    final from = (source, id);
    for (final targetId in entry.value) {
      if (targetId.isEmpty) continue;
      final to = (target, targetId);
      final reverse = directed[(target, targetId, source)];
      if (entry.value.length != 1 ||
          (reverse != null && (reverse.length != 1 || reverse.single != id))) {
        conflicting.add(from);
        conflicting.add(to);
      }
      // Retain contradictory edges until the whole group is checked. Dropping
      // one early could make a conflicting many-to-one group look unambiguous.
      (edges[from] ??= {}).add(to);
      (edges[to] ??= {}).add(from);
    }
  }
  final visited = <(String, String)>{};
  for (final root in edges.keys) {
    if (!visited.add(root)) continue;
    final group = [root];
    final providers = <String>{};
    var ambiguous = false;
    for (var i = 0; i < group.length; i++) {
      final node = group[i];
      if (!providers.add(node.$1) || conflicting.contains(node)) {
        ambiguous = true;
      }
      for (final neighbor in edges[node]!) {
        if (visited.add(neighbor)) group.add(neighbor);
      }
    }
    if (!ambiguous) yield group;
  }
}

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/utils/comic_mapping_utils.dart';
import 'package:flutter/foundation.dart';

/// Local badge state only. Never resolves bindings through network searches or
/// copies viewing records between sources.
class SubscribeBadgeState {
  static const configKey = 'AggregateSubscribeBadges';
  static final changes = ChangeNotifier();

  static Future<Map<String, DateTime>> viewingTimes(String sourceId) async {
    final database = await DatabaseInstance.instance;
    final setting = await database.configDao.getConfigByKey(configKey);
    final aggregate = setting?.get<bool>() == true;
    final states = aggregate
        ? await database.comicSubscribeStateDao
              .getAllComicSubscribeStateEntity()
        : await database.comicSubscribeStateDao
              .getComicSubscribeStateByProvider(sourceId);
    final times = <(String, String), DateTime>{};
    for (final state in states) {
      final time = state.timestamp;
      final key = (state.providerName, state.comicId);
      if (time != null && (times[key] == null || time.isAfter(times[key]!))) {
        times[key] = time;
      }
    }
    if (aggregate) {
      final mappings = await database.comicMappingDao
          .getAllComicMappingEntity();
      for (final group in reliableComicGroups(mappings)) {
        DateTime? latest;
        for (final node in group) {
          final time = times[node];
          if (time != null && (latest == null || time.isAfter(latest))) {
            latest = time;
          }
        }
        if (latest == null) continue;
        for (final node in group) {
          times[node] = latest;
        }
      }
    }
    return {
      for (final entry in times.entries)
        if (entry.key.$1 == sourceId) entry.key.$2: entry.value,
    };
  }
}

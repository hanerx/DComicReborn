import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/chapter_rule.dart';
import 'package:dcomic/utils/chapter_matching_rules.dart';
import 'package:flutter/foundation.dart';

/// 跨源章节匹配规则的唯一存取入口：读取、保存、删除、重置。
/// 任何改动成功提交后只广播一次 [changes]。
class ChapterRuleStore {
  static final changes = ValueNotifier<int>(0);

  static Future<List<ChapterRuleGroup>> load() async {
    final database = await DatabaseInstance.instance;
    return database.chapterRuleDao.loadChapterRules();
  }

  /// 保存分组：id 为空时新增，否则更新名称并整体替换规则。
  /// 名称或任一规则非法时抛出 [ArgumentError]，数据库保持原状。
  static Future<void> save(ChapterRuleGroup group) async {
    if (group.name.trim().isEmpty) {
      throw ArgumentError('分组名称不能为空');
    }
    for (final pattern in group.patterns) {
      final error = validateChapterPattern(pattern);
      if (error != null) throw ArgumentError(error);
    }
    final database = await DatabaseInstance.instance;
    await database.chapterRuleDao.saveChapterRuleGroup(
      ChapterRuleGroupEntity(group.id, group.name),
      group.patterns,
    );
    changes.value++;
  }

  static Future<void> delete(int id) async {
    final database = await DatabaseInstance.instance;
    await database.chapterRuleDao.deleteChapterRuleGroup(id);
    changes.value++;
  }

  /// 清空现有分组并用 [defaultChapterRuleGroups] 重建。
  static Future<void> reset() async {
    final database = await DatabaseInstance.instance;
    await database.chapterRuleDao.replaceChapterRules(defaultChapterRuleGroups);
    changes.value++;
  }
}

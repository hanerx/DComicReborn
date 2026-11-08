import 'package:dcomic/providers/models/chapter_metadata.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chapter attribution remains separate from identity and title', () {
    final groups = [const ScanlationGroup('group-id', '联合汉化组')];
    final chapter = DefaultComicChapterEntityModel(
      '第 1 话',
      'real-chapter-uuid',
      DateTime.utc(2026),
      language: 'zh',
      scanlationGroups: groups,
    );
    groups.clear();
    expect(chapter.chapterId, 'real-chapter-uuid');
    expect(chapter.rawTitle, '第 1 话');
    expect(chapter.language, 'zh');
    expect(chapter.scanlationGroups.single.id, 'group-id');
    expect(chapter.scanlationGroups.single.name, '联合汉化组');
    expect(() => chapter.scanlationGroups.clear(), throwsUnsupportedError);
  });
}

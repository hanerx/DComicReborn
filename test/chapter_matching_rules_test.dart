import 'package:dcomic/utils/chapter_matching_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'same group canonicalizes decimal numbers without floating point loss',
    () {
      final matcher = ChapterRuleMatcher(defaultChapterRuleGroups);
      final chapter = matcher.match('第００１２.５０話')!;
      final english = matcher.match('Chapter 12.5')!;
      expect(
        (chapter.groupIndex, chapter.number),
        (english.groupIndex, english.number),
      );
      expect(chapter.number, '12.5');
      expect(matcher.match('12话')!.number, '12');
      expect(matcher.match('第12卷')!.groupIndex, isNot(chapter.groupIndex));
      expect(matcher.match('第9007199254740993话')!.number, '9007199254740993');
      expect(matcher.match('第12话(上)'), isNull);
    },
  );

  test('overlapping groups and multiple captured numbers are ambiguous', () {
    final matcher = ChapterRuleMatcher([
      const ChapterRuleGroup(name: 'first', patterns: [r'(\d+)']),
      const ChapterRuleGroup(name: 'second', patterns: [r'^第(\d+)话$']),
    ]);
    expect(matcher.match('第12话'), isNull);
    expect(matcher.match('12-13'), isNull);
    expect(matcher.match('12'), isNotNull);
  });

  test('multiple patterns in one group may identify the same number', () {
    final matcher = ChapterRuleMatcher([
      const ChapterRuleGroup(
        name: 'chapter',
        patterns: [r'^第(\d+)话$', r'(\d+)'],
      ),
    ]);
    expect(matcher.match('第12话')!.number, '12');
  });

  test('empty groups and nonnumeric or missing captures do not match', () {
    final matcher = ChapterRuleMatcher([
      const ChapterRuleGroup(name: 'empty', patterns: []),
      const ChapterRuleGroup(
        name: 'text',
        patterns: [r'^(extra)$', r'^(\d+)?话$'],
      ),
    ]);
    expect(matcher.match('extra'), isNull);
    expect(matcher.match('话'), isNull);
    expect(ChapterRuleMatcher([]).match('第12话'), isNull);
  });

  test('pattern validation distinguishes captures from escaped or noncapturing groups', () {
    expect(validateChapterPattern(r'['), isNotNull);
    expect(validateChapterPattern(r'^\d+话$'), isNotNull);
    expect(validateChapterPattern(r'^(?:\d+)话$'), isNotNull);
    expect(validateChapterPattern(r'^\(\d+\)话$'), isNotNull);
    expect(validateChapterPattern(r'^[(]\d+[)]话$'), isNotNull);
    expect(validateChapterPattern(r'^第(\d+)话$'), isNull);
    expect(validateChapterPattern(r'^(?<number>\d+)话$'), isNull);
  });
}

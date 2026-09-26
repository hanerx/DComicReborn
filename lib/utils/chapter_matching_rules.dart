import 'package:pinyin/pinyin.dart';

class ChapterRuleGroup {
  final int? id;
  final String name;
  final List<String> patterns;

  const ChapterRuleGroup({this.id, required this.name, required this.patterns});
}

// Seed data only: matching always uses the groups read from the database.
const defaultChapterRuleGroups = <ChapterRuleGroup>[
  ChapterRuleGroup(
    name: '正篇',
    patterns: [
      r'^第(\d+(?:\.\d+)?)话$',
      r'^(\d+(?:\.\d+)?)话$',
      r'^Chapter\s*(\d+(?:\.\d+)?)$',
    ],
  ),
  ChapterRuleGroup(
    name: '单行本',
    patterns: [r'^第(\d+(?:\.\d+)?)卷$', r'^Vol\.\s*(\d+(?:\.\d+)?)$'],
  ),
];

final _whitespace = RegExp(r'\s+', unicode: true);
final _number = RegExp(r'^\d+(?:\.\d+)?$');
final _leadingZeros = RegExp(r'^0+(?=\d)');
final _trailingZeros = RegExp(r'0+$');

String normalizeChapterTitle(String title) {
  final widthFolded = String.fromCharCodes(
    title.runes.map((rune) {
      if (rune >= 0xff01 && rune <= 0xff5e) return rune - 0xfee0;
      return rune == 0x3000 ? 0x20 : rune;
    }),
  );
  return ChineseHelper.convertToSimplifiedChinese(widthFolded)
      .replaceAll(_whitespace, '');
}

String? validateChapterPattern(String pattern) {
  if (pattern.trim().isEmpty) return '请输入正则表达式';
  try {
    RegExp(pattern);
    // The empty alternative exposes capture count even when the user's pattern
    // cannot match an empty title; no hand-written regex syntax parser needed.
    if (RegExp('(?:$pattern)|').firstMatch('')!.groupCount == 0) {
      return '需要至少一个捕获组，例如 (\\d+)，第一个捕获组用于提取数字';
    }
  } on FormatException {
    return '正则表达式语法无效';
  }
  return null;
}

String? _canonicalNumber(String? value) {
  if (value == null || !_number.hasMatch(value)) return null;
  final parts = value.split('.');
  final integer = parts.first.replaceFirst(_leadingZeros, '');
  if (parts.length == 1) return integer;
  final fraction = parts[1].replaceFirst(_trailingZeros, '');
  return fraction.isEmpty ? integer : '$integer.$fraction';
}

class ChapterRuleMatch {
  final int groupIndex;
  final String number;

  const ChapterRuleMatch(this.groupIndex, this.number);
}

class ChapterRuleMatcher {
  final List<List<RegExp>> _groups;

  ChapterRuleMatcher(List<ChapterRuleGroup> groups)
    : _groups = [
        for (final group in groups)
          [for (final pattern in group.patterns) RegExp(pattern)],
      ];

  ChapterRuleMatch? match(String title) =>
      matchNormalized(normalizeChapterTitle(title));

  ChapterRuleMatch? matchNormalized(String normalized) {
    ChapterRuleMatch? result;
    for (var index = 0; index < _groups.length; index++) {
      for (final pattern in _groups[index]) {
        for (final match in pattern.allMatches(normalized)) {
          if (match.groupCount == 0) continue;
          final number = _canonicalNumber(match.group(1));
          if (number == null) continue;
          if (result != null) {
            if (result.groupIndex != index || result.number != number) {
              return null;
            }
          } else {
            result = ChapterRuleMatch(index, number);
          }
        }
      }
    }
    return result;
  }
}

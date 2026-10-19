import 'package:dcomic/providers/models/comic_topic_model.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dio/dio.dart';

class ZaiManHuaTopicModel extends BaseComicTopicModel {
  static const _topicPageSize = 24;

  @override
  Future<TopicPage<ComicTopic>> getTopics({int page = 0}) async {
    if (page < 0) {
      throw StateError('ZaiManHua topic page cannot be negative');
    }
    final response = await RequestHandlers.zaiManHuaMobileRequestHandler
        .getTopicList(page: page, size: _topicPageSize);
    final data = _zaiData(response, 'topic list');
    final currentPage = _requiredNonNegativeInt(
      data,
      'currentPage',
      'ZaiManHua topic list',
    );
    final size = _requiredNonNegativeInt(data, 'size', 'ZaiManHua topic list');
    final total = _requiredNonNegativeInt(
      data,
      'total',
      'ZaiManHua topic list',
    );
    if (currentPage != page + 1) {
      throw StateError(
        'Malformed ZaiManHua topic list: unexpected currentPage $currentPage',
      );
    }
    if (size == 0) {
      throw StateError('Malformed ZaiManHua topic list: size is zero');
    }
    final hasNextPage = currentPage * size < total;
    final rawSubjectList = data['subjectList'];
    if (rawSubjectList == null) {
      if (hasNextPage) {
        throw StateError(
          'Malformed ZaiManHua topic list: subjectList ended before total',
        );
      }
      return const TopicPage<ComicTopic>([]);
    }
    if (rawSubjectList is! List) {
      throw StateError(
        'Malformed ZaiManHua topic list: subjectList is not a list',
      );
    }
    if (rawSubjectList.isEmpty && hasNextPage) {
      throw StateError(
        'Malformed ZaiManHua topic list: subjectList ended before total',
      );
    }

    final topics = <ComicTopic>[];
    for (final rawItem in rawSubjectList) {
      final item = _requiredMap(rawItem, 'ZaiManHua topic');
      final redirectUrl = _optionalString(
        item,
        'redirectUrl',
        'ZaiManHua topic',
      );
      if (redirectUrl.trim().isNotEmpty) continue;
      final id = _usableId(item['id']);
      if (id == null) continue;
      topics.add(
        ComicTopic(
          id: id,
          title: _requiredString(item, 'title', 'ZaiManHua topic'),
          cover: ImageEntity(
            ImageType.network,
            _requiredString(item, 'cover', 'ZaiManHua topic'),
          ),
          description: _optionalString(item, 'short_title', 'ZaiManHua topic'),
          date: _optionalText(item, 'create_time', 'ZaiManHua topic'),
        ),
      );
    }
    return TopicPage(topics, nextPage: hasNextPage ? page + 1 : null);
  }

  @override
  Future<ComicTopicDetail> getDetail(String topicId) async {
    if (_usableId(topicId) == null) {
      throw StateError('ZaiManHua topic id cannot be empty');
    }
    final response = await RequestHandlers.zaiManHuaMobileRequestHandler
        .getTopicDetail(topicId);
    final data = _zaiData(response, 'topic detail');
    return ComicTopicDetail(
      topic: _parseTopic(data),
      comics: TopicPage(_parseComics(data)),
    );
  }

  @override
  Future<TopicPage<TopicComic>> getComics(
    String topicId, {
    required int page,
  }) async {
    if (_usableId(topicId) == null) {
      throw StateError('ZaiManHua topic id cannot be empty');
    }
    if (page != 0) {
      throw StateError('ZaiManHua topic comics do not support pagination');
    }
    final response = await RequestHandlers.zaiManHuaMobileRequestHandler
        .getTopicDetail(topicId);
    final data = _zaiData(response, 'topic detail');
    return TopicPage(_parseComics(data));
  }

  ComicTopic _parseTopic(Map<String, dynamic> data) {
    final subject = _requiredMap(
      data['subject'],
      'ZaiManHua topic detail subject',
    );
    final id = _usableId(subject['id']);
    if (id == null) {
      throw StateError('Malformed ZaiManHua topic detail: missing subject id');
    }
    return ComicTopic(
      id: id,
      title: _requiredString(
        subject,
        'title',
        'ZaiManHua topic detail subject',
      ),
      cover: ImageEntity(
        ImageType.network,
        _requiredString(subject, 'cover', 'ZaiManHua topic detail subject'),
      ),
      description: _optionalString(
        subject,
        'summary',
        'ZaiManHua topic detail subject',
      ),
    );
  }

  List<TopicComic> _parseComics(Map<String, dynamic> data) {
    final rawComics = data['comicList'];
    if (rawComics is! List) {
      throw StateError(
        'Malformed ZaiManHua topic detail: comicList is not a list',
      );
    }
    final comics = <TopicComic>[];
    final seenIds = <String>{};
    for (final rawComic in rawComics) {
      final comic = _requiredMap(rawComic, 'ZaiManHua topic comic');
      final id = _usableId(comic['comic_id']);
      final name = comic['name'];
      if (id == null || name is! String || name.trim().isEmpty) continue;
      if (!seenIds.add(id)) continue;
      final brief = _optionalString(
        comic,
        'recommend_brief',
        'ZaiManHua topic comic',
      );
      final reason = _optionalString(
        comic,
        'recommend_reason',
        'ZaiManHua topic comic',
      );
      comics.add(
        TopicComic(
          id: id,
          title: name,
          cover: ImageEntity(
            ImageType.network,
            _requiredString(comic, 'cover', 'ZaiManHua topic comic'),
          ),
          description: [
            if (brief.isNotEmpty) brief,
            if (reason.isNotEmpty) reason,
          ].join('\n'),
        ),
      );
    }
    return comics;
  }
}

Map<String, dynamic> _zaiData(Response<dynamic> response, String operation) {
  if (response.statusCode != 200 && response.statusCode != 304) {
    throw StateError(
      'ZaiManHua $operation failed: HTTP ${response.statusCode}',
    );
  }
  final body = _requiredMap(response.data, 'ZaiManHua $operation response');
  if (body['errno'] != 0) {
    final message = body['errmsg'];
    throw StateError(
      'ZaiManHua $operation failed: ${message is String && message.isNotEmpty ? message : 'errno ${body['errno']}'}',
    );
  }
  return _requiredMap(body['data'], 'ZaiManHua $operation data');
}

Map<String, dynamic> _requiredMap(Object? value, String context) {
  if (value is Map<String, dynamic>) return value;
  if (value is! Map) {
    throw StateError('Malformed $context: expected an object');
  }
  try {
    return Map<String, dynamic>.from(value);
  } on TypeError {
    throw StateError('Malformed $context: expected string keys');
  }
}

String _requiredString(Map<String, dynamic> map, String key, String context) {
  final value = map[key];
  if (value is! String) {
    throw StateError('Malformed $context: $key is not text');
  }
  return value;
}

String _optionalString(Map<String, dynamic> map, String key, String context) {
  final value = map[key];
  if (value == null) return '';
  if (value is! String) {
    throw StateError('Malformed $context: $key is not text');
  }
  return value;
}

String _optionalText(Map<String, dynamic> map, String key, String context) {
  final value = map[key];
  if (value == null) return '';
  if (value is String || value is num) return value.toString();
  throw StateError('Malformed $context: $key is not text');
}

int _requiredNonNegativeInt(
  Map<String, dynamic> map,
  String key,
  String context,
) {
  final value = map[key];
  if (value is! int || value < 0) {
    throw StateError('Malformed $context: $key is not a non-negative integer');
  }
  return value;
}

String? _usableId(Object? value) {
  if (value is String) return value.trim().isEmpty ? null : value;
  if (value is int) return value.toString();
  return null;
}

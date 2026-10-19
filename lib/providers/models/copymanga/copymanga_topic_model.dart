import 'package:dcomic/providers/models/comic_topic_model.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dio/dio.dart';

class CopyMangaTopicModel extends BaseComicTopicModel {
  static const _topicPageSize = 20;
  static const _comicPageSize = 30;

  @override
  Future<TopicPage<ComicTopic>> getTopics({int page = 0}) async {
    if (page < 0) {
      throw StateError('CopyManga topic page cannot be negative');
    }
    final response = await RequestHandlers.copyMangaRequestHandler
        .getSubjectList(page: page, limit: _topicPageSize);
    final results = _copyResults(response, 'topic list');
    final rawItems = _requiredList(results, 'list', 'CopyManga topic list');
    final items = <ComicTopic>[];
    for (final rawItem in rawItems) {
      final item = _requiredMap(rawItem, 'CopyManga topic');
      final id = _usableStringId(item['path_word']);
      if (id == null) continue;
      items.add(
        ComicTopic(
          id: id,
          title: _requiredString(item, 'title', 'CopyManga topic'),
          cover: ImageEntity(
            ImageType.network,
            _requiredString(item, 'cover', 'CopyManga topic'),
          ),
          description: _optionalString(item, 'brief', 'CopyManga topic'),
          date: _optionalText(item, 'datetime_created', 'CopyManga topic'),
        ),
      );
    }
    return TopicPage(
      items,
      nextPage: _copyNextPage(results, rawItems, page, 'topic list'),
    );
  }

  @override
  Future<ComicTopicDetail> getDetail(String topicId) async {
    if (_usableStringId(topicId) == null) {
      throw StateError('CopyManga topic id cannot be empty');
    }
    final responses = await Future.wait<Response<dynamic>>([
      RequestHandlers.copyMangaRequestHandler.getSubjectDetail(topicId),
      RequestHandlers.copyMangaRequestHandler.getSubjectDetailContent(
        topicId,
        page: 0,
        limit: _comicPageSize,
      ),
    ]);
    final metadata = _copyResults(responses[0], 'topic detail');
    final topic = _parseTopicDetail(metadata);
    final comics = _parseComicPage(responses[1], 0);
    return ComicTopicDetail(topic: topic, comics: comics);
  }

  @override
  Future<TopicPage<TopicComic>> getComics(
    String topicId, {
    required int page,
  }) async {
    if (_usableStringId(topicId) == null) {
      throw StateError('CopyManga topic id cannot be empty');
    }
    if (page < 0) {
      throw StateError('CopyManga topic comic page cannot be negative');
    }
    final response = await RequestHandlers.copyMangaRequestHandler
        .getSubjectDetailContent(topicId, page: page, limit: _comicPageSize);
    return _parseComicPage(response, page);
  }

  ComicTopic _parseTopicDetail(Map<String, dynamic> metadata) {
    final id = _usableStringId(metadata['path_word']);
    if (id == null) {
      throw StateError('Malformed CopyManga topic detail: missing path_word');
    }
    final intro = _optionalString(metadata, 'intro', 'CopyManga topic detail');
    final brief = _optionalString(metadata, 'brief', 'CopyManga topic detail');
    return ComicTopic(
      id: id,
      title: _requiredString(metadata, 'title', 'CopyManga topic detail'),
      cover: ImageEntity(
        ImageType.network,
        _requiredString(metadata, 'cover', 'CopyManga topic detail'),
      ),
      description: intro.isNotEmpty ? intro : brief,
      date: _optionalText(
        metadata,
        'datetime_created',
        'CopyManga topic detail',
      ),
    );
  }

  TopicPage<TopicComic> _parseComicPage(Response<dynamic> response, int page) {
    final results = _copyResults(response, 'topic contents');
    final rawItems = _requiredList(results, 'list', 'CopyManga topic contents');
    final seenIds = <String>{};
    final comics = <TopicComic>[];
    for (final rawItem in rawItems) {
      final item = _requiredMap(rawItem, 'CopyManga topic comic');
      final id = _usableStringId(item['path_word']);
      if (id == null || !seenIds.add(id)) continue;
      final authors = _namedValues(item, 'author', 'CopyManga topic comic');
      final themes = _namedValues(item, 'theme', 'CopyManga topic comic');
      final description = [
        if (authors.isNotEmpty) authors.join('/'),
        if (themes.isNotEmpty) themes.join('/'),
      ].join(' · ');
      comics.add(
        TopicComic(
          id: id,
          title: _requiredString(item, 'name', 'CopyManga topic comic'),
          cover: ImageEntity(
            ImageType.network,
            _requiredString(item, 'cover', 'CopyManga topic comic'),
          ),
          description: description,
        ),
      );
    }
    return TopicPage(
      comics,
      nextPage: _copyNextPage(results, rawItems, page, 'topic contents'),
    );
  }
}

Map<String, dynamic> _copyResults(
  Response<dynamic> response,
  String operation,
) {
  if (response.statusCode != 200 && response.statusCode != 304) {
    throw StateError(
      'CopyManga $operation failed: HTTP ${response.statusCode}',
    );
  }
  final body = _requiredMap(response.data, 'CopyManga $operation response');
  if (body['code'] != 200) {
    final message = body['message'];
    throw StateError(
      'CopyManga $operation failed: ${message is String ? message : 'code ${body['code']}'}',
    );
  }
  return _requiredMap(body['results'], 'CopyManga $operation results');
}

int? _copyNextPage(
  Map<String, dynamic> results,
  List<dynamic> rawItems,
  int page,
  String operation,
) {
  final total = _requiredNonNegativeInt(
    results,
    'total',
    'CopyManga $operation',
  );
  final limit = _requiredNonNegativeInt(
    results,
    'limit',
    'CopyManga $operation',
  );
  final offset = _requiredNonNegativeInt(
    results,
    'offset',
    'CopyManga $operation',
  );
  if (limit == 0) {
    throw StateError('Malformed CopyManga $operation: limit is zero');
  }
  return offset + rawItems.length < total ? page + 1 : null;
}

List<String> _namedValues(
  Map<String, dynamic> map,
  String key,
  String context,
) {
  final value = map[key];
  if (value == null) return const [];
  if (value is! List) {
    throw StateError('Malformed $context: $key is not a list');
  }
  return value
      .map<String>((rawValue) {
        final named = _requiredMap(rawValue, '$context $key entry');
        return _requiredString(named, 'name', '$context $key entry');
      })
      .toList(growable: false);
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

List<dynamic> _requiredList(
  Map<String, dynamic> map,
  String key,
  String context,
) {
  final value = map[key];
  if (value is! List) {
    throw StateError('Malformed $context: $key is not a list');
  }
  return value;
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

String? _usableStringId(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value;
}

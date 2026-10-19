import 'package:dcomic/utils/image_utils.dart';

/// Source identifiers and text remain unmodified until rendered by the source.
class ComicTopic {
  final String id;
  final String title;
  final ImageEntity cover;
  final String description;
  final String date;

  const ComicTopic({
    required this.id,
    required this.title,
    required this.cover,
    this.description = '',
    this.date = '',
  });
}

class TopicComic {
  final String id;
  final String title;
  final ImageEntity cover;
  final String description;

  const TopicComic({
    required this.id,
    required this.title,
    required this.cover,
    this.description = '',
  });
}

/// A null nextPage denotes exhaustion, independently of filtered item count.
class TopicPage<T> {
  final List<T> items;
  final int? nextPage;

  const TopicPage(this.items, {this.nextPage});
}

class ComicTopicDetail {
  final ComicTopic topic;
  final TopicPage<TopicComic> comics;

  const ComicTopicDetail({required this.topic, required this.comics});
}

abstract class BaseComicTopicModel {
  Future<TopicPage<ComicTopic>> getTopics({int page = 0});

  /// Loads metadata and the first comic page together for an atomic refresh.
  Future<ComicTopicDetail> getDetail(String topicId);

  /// Called only with a nextPage supplied by a previous comic page.
  Future<TopicPage<TopicComic>> getComics(String topicId, {required int page});
}

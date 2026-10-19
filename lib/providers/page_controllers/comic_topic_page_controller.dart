import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/models/comic_topic_model.dart';

List<T> _uniqueById<T>(
  Iterable<T> items,
  String Function(T item) idOf, {
  Iterable<T> existing = const [],
}) {
  final seen = existing.map(idOf).toSet();
  return [
    for (final item in items)
      if (seen.add(idOf(item))) item,
  ];
}

class ComicTopicListPageController extends BaseProvider {
  ComicTopicListPageController(this.sourceModel)
    : topicModel =
          sourceModel.topics ??
          (throw ArgumentError.value(
            sourceModel,
            'sourceModel',
            'The source does not provide topics',
          ));

  final BaseComicSourceModel sourceModel;
  final BaseComicTopicModel topicModel;

  List<ComicTopic> _topics = const [];
  int? _nextPage = 0;
  Object? _error;
  bool _hasLoaded = false;
  bool _isLoading = false;
  bool _failedToLoadMore = false;
  bool _requestIsAppend = false;
  bool _disposed = false;
  int _generation = 0;
  Future<void>? _request;

  List<ComicTopic> get topics => _topics;
  Object? get error => _error;
  bool get hasLoaded => _hasLoaded;
  bool get isLoading => _isLoading;
  bool get hasError => _error != null;
  bool get failedToLoadMore => _failedToLoadMore;
  bool get hasMore => _hasLoaded && _nextPage != null;

  Future<void> refresh() {
    if (_disposed) return Future.value();
    if (_isLoading && !_requestIsAppend) {
      return _request ?? Future.value();
    }

    final generation = ++_generation;
    _beginRequest(append: false);
    final request = _performRefresh(generation);
    _request = request;
    return request;
  }

  Future<void> loadMore() {
    if (_disposed || !_hasLoaded || _nextPage == null) {
      return Future.value();
    }
    if (_isLoading) return _request ?? Future.value();
    if (hasError && !_failedToLoadMore) return Future.value();

    final generation = ++_generation;
    final page = _nextPage!;
    _beginRequest(append: true);
    final request = _performLoad(generation, page);
    _request = request;
    return request;
  }

  void _beginRequest({required bool append}) {
    _isLoading = true;
    _requestIsAppend = append;
    _error = null;
    _failedToLoadMore = false;
    notifyListeners();
  }

  Future<void> _performRefresh(int generation) async {
    try {
      final result = await topicModel.getTopics(page: 0);
      if (!_isCurrent(generation)) return;
      _topics = _uniqueById(result.items, (item) => item.id);
      _nextPage = result.nextPage;
      _hasLoaded = true;
    } catch (error, stack) {
      if (!_isCurrent(generation)) return;
      _error = error;
      _failedToLoadMore = false;
      _hasLoaded = true;
      logger.e('Failed to refresh topics', error: error, stackTrace: stack);
    } finally {
      _finishRequest(generation);
    }
  }

  Future<void> _performLoad(int generation, int page) async {
    try {
      final result = await topicModel.getTopics(page: page);
      if (!_isCurrent(generation)) return;
      _topics = [
        ..._topics,
        ..._uniqueById(result.items, (item) => item.id, existing: _topics),
      ];
      _nextPage = result.nextPage;
    } catch (error, stack) {
      if (!_isCurrent(generation)) return;
      _error = error;
      _failedToLoadMore = true;
      logger.e('Failed to load more topics', error: error, stackTrace: stack);
    } finally {
      _finishRequest(generation);
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _finishRequest(int generation) {
    if (!_isCurrent(generation)) return;
    _isLoading = false;
    _request = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

class ComicTopicDetailPageController extends BaseProvider {
  ComicTopicDetailPageController(this.sourceModel, this.topicId)
    : topicModel =
          sourceModel.topics ??
          (throw ArgumentError.value(
            sourceModel,
            'sourceModel',
            'The source does not provide topics',
          ));

  final BaseComicSourceModel sourceModel;
  final BaseComicTopicModel topicModel;
  final String topicId;

  ComicTopic? _topic;
  List<TopicComic> _comics = const [];
  int? _nextPage;
  Object? _error;
  bool _hasLoaded = false;
  bool _isLoading = false;
  bool _failedToLoadMore = false;
  bool _requestIsAppend = false;
  bool _disposed = false;
  int _generation = 0;
  Future<void>? _request;

  ComicTopic? get topic => _topic;
  List<TopicComic> get comics => _comics;
  Object? get error => _error;
  bool get hasLoaded => _hasLoaded;
  bool get isLoading => _isLoading;
  bool get hasError => _error != null;
  bool get failedToLoadMore => _failedToLoadMore;
  bool get hasMore => _hasLoaded && _nextPage != null;

  Future<void> refresh() {
    if (_disposed) return Future.value();
    if (_isLoading && !_requestIsAppend) {
      return _request ?? Future.value();
    }

    final generation = ++_generation;
    _beginRequest(append: false);
    final request = _performRefresh(generation);
    _request = request;
    return request;
  }

  Future<void> loadMore() {
    if (_disposed || !_hasLoaded || _nextPage == null) {
      return Future.value();
    }
    if (_isLoading) return _request ?? Future.value();
    if (hasError && !_failedToLoadMore) return Future.value();

    final generation = ++_generation;
    final page = _nextPage!;
    _beginRequest(append: true);
    final request = _performLoad(generation, page);
    _request = request;
    return request;
  }

  void _beginRequest({required bool append}) {
    _isLoading = true;
    _requestIsAppend = append;
    _error = null;
    _failedToLoadMore = false;
    notifyListeners();
  }

  Future<void> _performRefresh(int generation) async {
    try {
      final result = await topicModel.getDetail(topicId);
      if (!_isCurrent(generation)) return;
      _topic = result.topic;
      _comics = _uniqueById(result.comics.items, (item) => item.id);
      _nextPage = result.comics.nextPage;
      _hasLoaded = true;
    } catch (error, stack) {
      if (!_isCurrent(generation)) return;
      _error = error;
      _failedToLoadMore = false;
      _hasLoaded = true;
      logger.e(
        'Failed to refresh topic detail',
        error: error,
        stackTrace: stack,
      );
    } finally {
      _finishRequest(generation);
    }
  }

  Future<void> _performLoad(int generation, int page) async {
    try {
      final result = await topicModel.getComics(topicId, page: page);
      if (!_isCurrent(generation)) return;
      _comics = [
        ..._comics,
        ..._uniqueById(result.items, (item) => item.id, existing: _comics),
      ];
      _nextPage = result.nextPage;
    } catch (error, stack) {
      if (!_isCurrent(generation)) return;
      _error = error;
      _failedToLoadMore = true;
      logger.e(
        'Failed to load more topic comics',
        error: error,
        stackTrace: stack,
      );
    } finally {
      _finishRequest(generation);
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _finishRequest(int generation) {
    if (!_isCurrent(generation)) return;
    _isLoading = false;
    _request = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

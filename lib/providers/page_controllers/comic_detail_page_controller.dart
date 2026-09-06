import 'package:date_format/date_format.dart';
import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

enum ComicDetailLoadState { loading, ready, error }

typedef _ComicDetailPayload = ({
  String comicId,
  String title,
  ImageEntity cover,
  String description,
  String status,
  DateTime lastUpdate,
  List<CategoryEntity> authors,
  List<CategoryEntity> categories,
  Map<String, List<BaseComicChapterEntityModel>> chapters,
});

class ComicDetailPageController extends BaseProvider {
  ComicDetailLoadState _loadState = ComicDetailLoadState.loading;
  Object? _loadError;
  String? _boundComicId;
  _ComicDetailPayload? _detail;
  String? _originComicId;
  String? _originTitle;
  int _requestGeneration = 0;
  bool _disposed = false;
  BaseComicDetailModel? detailModel;
  BaseComicSourceModel? comicSourceModel;
  BaseComicSourceModel? sourceModel;

  bool _nest = true;
  bool _reverse = true;

  ComicDetailLoadState get loadState => _loadState;

  Object? get loadError => _loadError;

  bool get isLoading => _loadState == ComicDetailLoadState.loading;

  String? get boundComicId => _boundComicId;

  bool get canUnbind => _boundComicId != null;

  List<ComicCommentEntity> _comments = [];
  int _commentPage = 0;

  List<ComicCommentEntity> get comments => _comments;

  ComicDetailPageController(this.comicSourceModel) {
    sourceModel = comicSourceModel;
  }

  @override
  void dispose() {
    _disposed = true;
    _requestGeneration++;
    super.dispose();
  }

  Future<void> refresh(
      BuildContext context, String comicId, String title) async {
    if (_disposed) {
      return;
    }
    // 处理sourceModel问题
    if (comicSourceModel == null) {
      comicSourceModel =
          Provider.of<ComicSourceProvider>(context, listen: false).activeModel;
    } else {
      Provider.of<ComicSourceProvider>(context, listen: false).activeModel =
          comicSourceModel!;
    }
    // 原始书目 ID/标题与原始来源只在首次加载时固定，之后切换源不改变 origin。
    sourceModel ??= comicSourceModel;
    _originComicId ??= comicId;
    if (_originTitle == null || _originTitle!.isEmpty) {
      _originTitle = title;
    }
    await _load();
  }

  Future<void> refreshComment() async {
    var model = detailModel;
    if (_disposed || model == null) {
      return;
    }
    _commentPage = 0;
    var comments = await model.getComments(page: _commentPage);
    if (_disposed || detailModel != model) {
      return;
    }
    _comments = comments;
    notifyListeners();
  }

  Future<void> loadComment() async {
    var model = detailModel;
    if (_disposed || model == null) {
      return;
    }
    _commentPage++;
    var comments = await model.getComments(page: _commentPage);
    if (_disposed || detailModel != model) {
      return;
    }
    _comments += comments;
    notifyListeners();
  }

  Future<void> addComicHistory(String chapterId, String chapterName) async {
    var model = detailModel;
    if (_disposed || model == null) {
      return;
    }
    await model.addComicHistory(chapterId, chapterName);
  }

  String? get latestChapterId => detailModel?.latestChapterId;

  String get title => _detail?.title ?? _originTitle ?? '';

  ImageEntity get cover => _detail?.cover ?? ImageEntity(ImageType.unknown, "");

  String get description => _detail?.description ?? "";

  String get status => _detail?.status ?? "";

  String get lastUpdate => _detail == null
      ? "1970-1-1"
      : formatDate(_detail!.lastUpdate, [yyyy, '-', mm, '-', dd]);

  String get comicId => _detail?.comicId ?? _boundComicId ?? '';

  List<CategoryEntity> get authors => _detail?.authors ?? [];

  List<CategoryEntity> get categories => _detail?.categories ?? [];

  Map<String, List<BaseComicChapterEntityModel>> get chapters =>
      _detail?.chapters ?? {};

  bool get subscribe => detailModel == null ? false : detailModel!.subscribe;

  set subscribe(bool subscribe) {
    if (detailModel != null) {
      detailModel!.subscribe = subscribe;
      notifyListeners();
    }
  }

  bool get reverse => _reverse;

  set reverse(bool value) {
    _reverse = value;
    notifyListeners();
  }

  bool get nest => _nest;

  set nest(bool value) {
    _nest = value;
    notifyListeners();
  }

  Future<void> bindComicId(String comicId, String? targetComicId) async {
    if (_disposed || targetComicId == null) {
      return;
    }
    var source = comicSourceModel;
    var origin = sourceModel;
    if (source == null || origin == null) {
      return;
    }
    final generation = ++_requestGeneration;
    _setLoading();
    try {
      await source.bindComicIdFromSourceModel(
          _originComicId ?? comicId, targetComicId, origin);
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
      if (!_isStale(generation)) {
        _publishError(e);
      }
      return;
    }
    if (_isStale(generation)) {
      return;
    }
    await _load();
  }

  Future<void> unbindComicId(String comicId) async {
    if (_disposed) {
      return;
    }
    var source = comicSourceModel;
    var origin = sourceModel;
    if (source == null || origin == null) {
      return;
    }
    final generation = ++_requestGeneration;
    _setLoading();
    try {
      await source.bindComicIdFromSourceModel(
          _originComicId ?? comicId, '', origin);
    } catch (e, s) {
      logger.e('$e', error: e, stackTrace: s);
      if (!_isStale(generation)) {
        _publishError(e);
      }
      return;
    }
    if (_isStale(generation)) {
      return;
    }
    _boundComicId = null;
    _publishError(StateError('绑定为空'));
  }

  Future<void> _load() async {
    if (_disposed) {
      return;
    }
    var source = comicSourceModel;
    var origin = sourceModel;
    if (source == null || origin == null) {
      _publishError(StateError('未选择漫画源'));
      return;
    }
    final generation = ++_requestGeneration;
    _setLoading();
    try {
      var resolvedComicId = await source.resolveComicId(
          _originComicId ?? '', _originTitle ?? '', origin);
      if (_isStale(generation)) {
        return;
      }
      _boundComicId = resolvedComicId;
      if (resolvedComicId == null) {
        _publishError(StateError('绑定为空'));
        return;
      }
      var model =
          await source.getComicDetail(resolvedComicId, _originTitle ?? '');
      if (_isStale(generation)) {
        return;
      }
      if (model == null) {
        _publishError(StateError('漫画源未返回漫画详情'));
        return;
      }
      await model.init();
      if (_isStale(generation)) {
        return;
      }
      var payload = _buildDetailPayload(model);
      try {
        if (source.accountModel != null) {
          await source.accountModel!.addSubscribeState(payload.comicId);
        }
      } catch (e, s) {
        logger.e('$e', error: e, stackTrace: s);
      }
      if (_isStale(generation)) {
        return;
      }
      detailModel = model;
      _detail = payload;
      _publish(ComicDetailLoadState.ready);
    } catch (e, s) {
      if (_isStale(generation)) {
        return;
      }
      logger.e('$e', error: e, stackTrace: s);
      _publishError(e);
    }
  }

  void _setLoading() {
    _loadError = null;
    detailModel = null;
    _detail = null;
    _boundComicId = null;
    _comments = [];
    _commentPage = 0;
    _loadState = ComicDetailLoadState.loading;
    notifyListeners();
  }

  void _publish(ComicDetailLoadState state) {
    _loadState = state;
    notifyListeners();
  }

  void _publishError(Object error) {
    _loadError = error;
    _publish(ComicDetailLoadState.error);
  }

  bool _isStale(int generation) =>
      _disposed || _requestGeneration != generation;

  _ComicDetailPayload _buildDetailPayload(BaseComicDetailModel model) {
    // 详情字段全部是懒解析：进入 ready 前一次性解析并缓存，
    // 畸形数据在此时暴露为 parseFailed，UI 读取也不再重复解析。
    return (
      comicId: model.comicId,
      title: model.title,
      cover: model.cover,
      description: model.description,
      status: model.status,
      lastUpdate: model.lastUpdate,
      authors: model.authors,
      categories: model.categories,
      chapters: model.chapters,
    );
  }
}

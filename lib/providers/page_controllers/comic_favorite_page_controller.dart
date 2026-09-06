import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';

class ComicFavoritePageController extends BaseProvider {
  BaseComicSourceModel sourceModel;
  int _page = 0;
  List<GridItemEntity> data = [];
  bool _disposed = false;

  ComicFavoritePageController(this.sourceModel);

  Future<void> refresh() async {
    _page = 0;
    data = await sourceModel.accountModel!.getSubscribeStateComics(page: _page);
    notifyListeners();
  }

  Future<void> load() async {
    _page++;
    data +=
        await sourceModel.accountModel!.getSubscribeStateComics(page: _page);
    notifyListeners();
  }

  Future<void> refreshBadges(String comicId) async {
    final items = data
        .where((item) =>
            item is GridItemEntityWithStatus && item.comicId == comicId)
        .toList();
    if (items.isEmpty) return;
    final changed =
        await sourceModel.accountModel!.refreshSubscribeBadges(items);
    if (!_disposed && changed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

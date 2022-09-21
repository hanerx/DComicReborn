import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';

class ComicViewerPageController extends BaseProvider{
  final BaseComicDetailModel detailModel;
  final List<BaseComicChapterEntityModel> chapters;
  final String initChapterId;
  BaseComicChapterEntityModel? currentChapter;
  BaseComicChapterDetailModel? chapterDetailModel;

  // viewer参数
  int _currentPage=0;
  bool _showToolBar=false;
  int _endDrawerPage=0;

  ComicViewerPageController(this.detailModel,this.chapters,this.initChapterId){
    if(chapters.indexWhere((element) => element.chapterId==initChapterId)>=0){
      currentChapter=chapters[chapters.indexWhere((element) => element.chapterId==initChapterId)];
    }
  }

  BaseComicChapterEntityModel? get preChapter=>currentChapter!=null&&chapters.indexOf(currentChapter!)>0?chapters[chapters.indexOf(currentChapter!)-1]:null;

  BaseComicChapterEntityModel? get nextChapter=>currentChapter!=null&&chapters.indexOf(currentChapter!)<chapters.length-1?chapters[chapters.indexOf(currentChapter!)+1]:null;


  Future<void> refresh()async{
    if(chapterDetailModel!=null&&preChapter!=null){
      currentChapter=preChapter;
    }
    chapterDetailModel=await detailModel.getChapter(currentChapter!.chapterId);
    _currentPage=0;
    notifyListeners();
  }

  Future<void> load() async{
    if(chapterDetailModel!=null&&nextChapter!=null){
      currentChapter=nextChapter;
    }
    chapterDetailModel=await detailModel.getChapter(currentChapter!.chapterId);
    _currentPage=0;
    notifyListeners();
  }

  int get currentPage => _currentPage;

  set currentPage(int value) {
    _currentPage = value;
    notifyListeners();
  }

  bool get showToolBar => _showToolBar;

  set showToolBar(bool value) {
    _showToolBar = value;
    notifyListeners();
  }

  String get title=>chapterDetailModel==null?"title":chapterDetailModel!.title;

  int get endDrawerPage => _endDrawerPage;

  set endDrawerPage(int value) {
    _endDrawerPage = value;
    notifyListeners();
  }
}
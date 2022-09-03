import 'package:dcomic/providers/models/base_model.dart';

abstract class BaseComicSourceModel extends BaseModel {
  BaseComicHomepageModel? get homepage => null;
}

abstract class BaseComicDetailModel extends BaseModel {}

abstract class BaseComicChapterEntityModel extends BaseModel {}

abstract class BaseComicChapterDetailModel extends BaseModel {}

abstract class BaseComicHomepageModel extends BaseModel {}

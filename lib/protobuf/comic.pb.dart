// This is a generated file - do not edit.
//
// Generated from comic.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class ComicDetailResponse extends $pb.GeneratedMessage {
  factory ComicDetailResponse({
    $core.int? errno,
    $core.String? errmsg,
    ComicDetailInfoResponse? data,
  }) {
    final result = create();
    if (errno != null) result.errno = errno;
    if (errmsg != null) result.errmsg = errmsg;
    if (data != null) result.data = data;
    return result;
  }

  ComicDetailResponse._();

  factory ComicDetailResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ComicDetailResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ComicDetailResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dmzj.comic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'Errno', protoName: 'Errno')
    ..aOS(2, _omitFieldNames ? '' : 'Errmsg', protoName: 'Errmsg')
    ..aOM<ComicDetailInfoResponse>(3, _omitFieldNames ? '' : 'Data',
        protoName: 'Data', subBuilder: ComicDetailInfoResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicDetailResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicDetailResponse copyWith(void Function(ComicDetailResponse) updates) =>
      super.copyWith((message) => updates(message as ComicDetailResponse))
          as ComicDetailResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ComicDetailResponse create() => ComicDetailResponse._();
  @$core.override
  ComicDetailResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ComicDetailResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ComicDetailResponse>(create);
  static ComicDetailResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get errno => $_getIZ(0);
  @$pb.TagNumber(1)
  set errno($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasErrno() => $_has(0);
  @$pb.TagNumber(1)
  void clearErrno() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get errmsg => $_getSZ(1);
  @$pb.TagNumber(2)
  set errmsg($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasErrmsg() => $_has(1);
  @$pb.TagNumber(2)
  void clearErrmsg() => $_clearField(2);

  @$pb.TagNumber(3)
  ComicDetailInfoResponse get data => $_getN(2);
  @$pb.TagNumber(3)
  set data(ComicDetailInfoResponse value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasData() => $_has(2);
  @$pb.TagNumber(3)
  void clearData() => $_clearField(3);
  @$pb.TagNumber(3)
  ComicDetailInfoResponse ensureData() => $_ensure(2);
}

class ComicDetailInfoResponse extends $pb.GeneratedMessage {
  factory ComicDetailInfoResponse({
    $core.int? id,
    $core.String? title,
    $core.int? direction,
    $core.int? islong,
    $core.int? isDmzj,
    $core.String? cover,
    $core.String? description,
    $fixnum.Int64? lastUpdatetime,
    $core.String? lastUpdateChapterName,
    $core.int? copyright,
    $core.String? firstLetter,
    $core.String? comicPy,
    $core.int? hidden,
    $core.int? hotNum,
    $core.int? hitNum,
    $core.int? uid,
    $core.int? isLock,
    $core.int? lastUpdateChapterId,
    $core.Iterable<ComicDetailTypeItemResponse>? types,
    $core.Iterable<ComicDetailTypeItemResponse>? status,
    $core.Iterable<ComicDetailTypeItemResponse>? authors,
    $core.int? subscribeNum,
    $core.Iterable<ComicDetailChapterResponse>? chapters,
    $core.int? isNeedLogin,
    $core.int? isHideChapter,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (title != null) result.title = title;
    if (direction != null) result.direction = direction;
    if (islong != null) result.islong = islong;
    if (isDmzj != null) result.isDmzj = isDmzj;
    if (cover != null) result.cover = cover;
    if (description != null) result.description = description;
    if (lastUpdatetime != null) result.lastUpdatetime = lastUpdatetime;
    if (lastUpdateChapterName != null)
      result.lastUpdateChapterName = lastUpdateChapterName;
    if (copyright != null) result.copyright = copyright;
    if (firstLetter != null) result.firstLetter = firstLetter;
    if (comicPy != null) result.comicPy = comicPy;
    if (hidden != null) result.hidden = hidden;
    if (hotNum != null) result.hotNum = hotNum;
    if (hitNum != null) result.hitNum = hitNum;
    if (uid != null) result.uid = uid;
    if (isLock != null) result.isLock = isLock;
    if (lastUpdateChapterId != null)
      result.lastUpdateChapterId = lastUpdateChapterId;
    if (types != null) result.types.addAll(types);
    if (status != null) result.status.addAll(status);
    if (authors != null) result.authors.addAll(authors);
    if (subscribeNum != null) result.subscribeNum = subscribeNum;
    if (chapters != null) result.chapters.addAll(chapters);
    if (isNeedLogin != null) result.isNeedLogin = isNeedLogin;
    if (isHideChapter != null) result.isHideChapter = isHideChapter;
    return result;
  }

  ComicDetailInfoResponse._();

  factory ComicDetailInfoResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ComicDetailInfoResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ComicDetailInfoResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dmzj.comic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'Id', protoName: 'Id')
    ..aOS(2, _omitFieldNames ? '' : 'Title', protoName: 'Title')
    ..aI(3, _omitFieldNames ? '' : 'Direction', protoName: 'Direction')
    ..aI(4, _omitFieldNames ? '' : 'Islong', protoName: 'Islong')
    ..aI(5, _omitFieldNames ? '' : 'IsDmzj', protoName: 'IsDmzj')
    ..aOS(6, _omitFieldNames ? '' : 'Cover', protoName: 'Cover')
    ..aOS(7, _omitFieldNames ? '' : 'Description', protoName: 'Description')
    ..aInt64(8, _omitFieldNames ? '' : 'LastUpdatetime',
        protoName: 'LastUpdatetime')
    ..aOS(9, _omitFieldNames ? '' : 'LastUpdateChapterName',
        protoName: 'LastUpdateChapterName')
    ..aI(10, _omitFieldNames ? '' : 'Copyright', protoName: 'Copyright')
    ..aOS(11, _omitFieldNames ? '' : 'FirstLetter', protoName: 'FirstLetter')
    ..aOS(12, _omitFieldNames ? '' : 'ComicPy', protoName: 'ComicPy')
    ..aI(13, _omitFieldNames ? '' : 'Hidden', protoName: 'Hidden')
    ..aI(14, _omitFieldNames ? '' : 'HotNum', protoName: 'HotNum')
    ..aI(15, _omitFieldNames ? '' : 'HitNum', protoName: 'HitNum')
    ..aI(16, _omitFieldNames ? '' : 'Uid', protoName: 'Uid')
    ..aI(17, _omitFieldNames ? '' : 'IsLock', protoName: 'IsLock')
    ..aI(18, _omitFieldNames ? '' : 'LastUpdateChapterId',
        protoName: 'LastUpdateChapterId')
    ..pPM<ComicDetailTypeItemResponse>(19, _omitFieldNames ? '' : 'Types',
        protoName: 'Types', subBuilder: ComicDetailTypeItemResponse.create)
    ..pPM<ComicDetailTypeItemResponse>(20, _omitFieldNames ? '' : 'Status',
        protoName: 'Status', subBuilder: ComicDetailTypeItemResponse.create)
    ..pPM<ComicDetailTypeItemResponse>(21, _omitFieldNames ? '' : 'Authors',
        protoName: 'Authors', subBuilder: ComicDetailTypeItemResponse.create)
    ..aI(22, _omitFieldNames ? '' : 'SubscribeNum', protoName: 'SubscribeNum')
    ..pPM<ComicDetailChapterResponse>(23, _omitFieldNames ? '' : 'Chapters',
        protoName: 'Chapters', subBuilder: ComicDetailChapterResponse.create)
    ..aI(24, _omitFieldNames ? '' : 'IsNeedLogin', protoName: 'IsNeedLogin')
    ..aI(26, _omitFieldNames ? '' : 'IsHideChapter', protoName: 'IsHideChapter')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicDetailInfoResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicDetailInfoResponse copyWith(
          void Function(ComicDetailInfoResponse) updates) =>
      super.copyWith((message) => updates(message as ComicDetailInfoResponse))
          as ComicDetailInfoResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ComicDetailInfoResponse create() => ComicDetailInfoResponse._();
  @$core.override
  ComicDetailInfoResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ComicDetailInfoResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ComicDetailInfoResponse>(create);
  static ComicDetailInfoResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get direction => $_getIZ(2);
  @$pb.TagNumber(3)
  set direction($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDirection() => $_has(2);
  @$pb.TagNumber(3)
  void clearDirection() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get islong => $_getIZ(3);
  @$pb.TagNumber(4)
  set islong($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIslong() => $_has(3);
  @$pb.TagNumber(4)
  void clearIslong() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get isDmzj => $_getIZ(4);
  @$pb.TagNumber(5)
  set isDmzj($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIsDmzj() => $_has(4);
  @$pb.TagNumber(5)
  void clearIsDmzj() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get cover => $_getSZ(5);
  @$pb.TagNumber(6)
  set cover($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCover() => $_has(5);
  @$pb.TagNumber(6)
  void clearCover() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get description => $_getSZ(6);
  @$pb.TagNumber(7)
  set description($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDescription() => $_has(6);
  @$pb.TagNumber(7)
  void clearDescription() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get lastUpdatetime => $_getI64(7);
  @$pb.TagNumber(8)
  set lastUpdatetime($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasLastUpdatetime() => $_has(7);
  @$pb.TagNumber(8)
  void clearLastUpdatetime() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get lastUpdateChapterName => $_getSZ(8);
  @$pb.TagNumber(9)
  set lastUpdateChapterName($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasLastUpdateChapterName() => $_has(8);
  @$pb.TagNumber(9)
  void clearLastUpdateChapterName() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get copyright => $_getIZ(9);
  @$pb.TagNumber(10)
  set copyright($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasCopyright() => $_has(9);
  @$pb.TagNumber(10)
  void clearCopyright() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get firstLetter => $_getSZ(10);
  @$pb.TagNumber(11)
  set firstLetter($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasFirstLetter() => $_has(10);
  @$pb.TagNumber(11)
  void clearFirstLetter() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get comicPy => $_getSZ(11);
  @$pb.TagNumber(12)
  set comicPy($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasComicPy() => $_has(11);
  @$pb.TagNumber(12)
  void clearComicPy() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get hidden => $_getIZ(12);
  @$pb.TagNumber(13)
  set hidden($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasHidden() => $_has(12);
  @$pb.TagNumber(13)
  void clearHidden() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.int get hotNum => $_getIZ(13);
  @$pb.TagNumber(14)
  set hotNum($core.int value) => $_setSignedInt32(13, value);
  @$pb.TagNumber(14)
  $core.bool hasHotNum() => $_has(13);
  @$pb.TagNumber(14)
  void clearHotNum() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.int get hitNum => $_getIZ(14);
  @$pb.TagNumber(15)
  set hitNum($core.int value) => $_setSignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasHitNum() => $_has(14);
  @$pb.TagNumber(15)
  void clearHitNum() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.int get uid => $_getIZ(15);
  @$pb.TagNumber(16)
  set uid($core.int value) => $_setSignedInt32(15, value);
  @$pb.TagNumber(16)
  $core.bool hasUid() => $_has(15);
  @$pb.TagNumber(16)
  void clearUid() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.int get isLock => $_getIZ(16);
  @$pb.TagNumber(17)
  set isLock($core.int value) => $_setSignedInt32(16, value);
  @$pb.TagNumber(17)
  $core.bool hasIsLock() => $_has(16);
  @$pb.TagNumber(17)
  void clearIsLock() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.int get lastUpdateChapterId => $_getIZ(17);
  @$pb.TagNumber(18)
  set lastUpdateChapterId($core.int value) => $_setSignedInt32(17, value);
  @$pb.TagNumber(18)
  $core.bool hasLastUpdateChapterId() => $_has(17);
  @$pb.TagNumber(18)
  void clearLastUpdateChapterId() => $_clearField(18);

  @$pb.TagNumber(19)
  $pb.PbList<ComicDetailTypeItemResponse> get types => $_getList(18);

  @$pb.TagNumber(20)
  $pb.PbList<ComicDetailTypeItemResponse> get status => $_getList(19);

  @$pb.TagNumber(21)
  $pb.PbList<ComicDetailTypeItemResponse> get authors => $_getList(20);

  @$pb.TagNumber(22)
  $core.int get subscribeNum => $_getIZ(21);
  @$pb.TagNumber(22)
  set subscribeNum($core.int value) => $_setSignedInt32(21, value);
  @$pb.TagNumber(22)
  $core.bool hasSubscribeNum() => $_has(21);
  @$pb.TagNumber(22)
  void clearSubscribeNum() => $_clearField(22);

  @$pb.TagNumber(23)
  $pb.PbList<ComicDetailChapterResponse> get chapters => $_getList(22);

  @$pb.TagNumber(24)
  $core.int get isNeedLogin => $_getIZ(23);
  @$pb.TagNumber(24)
  set isNeedLogin($core.int value) => $_setSignedInt32(23, value);
  @$pb.TagNumber(24)
  $core.bool hasIsNeedLogin() => $_has(23);
  @$pb.TagNumber(24)
  void clearIsNeedLogin() => $_clearField(24);

  /// object UrlLinks=25;
  @$pb.TagNumber(26)
  $core.int get isHideChapter => $_getIZ(24);
  @$pb.TagNumber(26)
  set isHideChapter($core.int value) => $_setSignedInt32(24, value);
  @$pb.TagNumber(26)
  $core.bool hasIsHideChapter() => $_has(24);
  @$pb.TagNumber(26)
  void clearIsHideChapter() => $_clearField(26);
}

class ComicDetailTypeItemResponse extends $pb.GeneratedMessage {
  factory ComicDetailTypeItemResponse({
    $core.int? tagId,
    $core.String? tagName,
  }) {
    final result = create();
    if (tagId != null) result.tagId = tagId;
    if (tagName != null) result.tagName = tagName;
    return result;
  }

  ComicDetailTypeItemResponse._();

  factory ComicDetailTypeItemResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ComicDetailTypeItemResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ComicDetailTypeItemResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dmzj.comic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'TagId', protoName: 'TagId')
    ..aOS(2, _omitFieldNames ? '' : 'TagName', protoName: 'TagName')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicDetailTypeItemResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicDetailTypeItemResponse copyWith(
          void Function(ComicDetailTypeItemResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ComicDetailTypeItemResponse))
          as ComicDetailTypeItemResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ComicDetailTypeItemResponse create() =>
      ComicDetailTypeItemResponse._();
  @$core.override
  ComicDetailTypeItemResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ComicDetailTypeItemResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ComicDetailTypeItemResponse>(create);
  static ComicDetailTypeItemResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get tagId => $_getIZ(0);
  @$pb.TagNumber(1)
  set tagId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTagId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTagId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get tagName => $_getSZ(1);
  @$pb.TagNumber(2)
  set tagName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTagName() => $_has(1);
  @$pb.TagNumber(2)
  void clearTagName() => $_clearField(2);
}

class ComicDetailChapterResponse extends $pb.GeneratedMessage {
  factory ComicDetailChapterResponse({
    $core.String? title,
    $core.Iterable<ComicDetailChapterInfoResponse>? data,
  }) {
    final result = create();
    if (title != null) result.title = title;
    if (data != null) result.data.addAll(data);
    return result;
  }

  ComicDetailChapterResponse._();

  factory ComicDetailChapterResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ComicDetailChapterResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ComicDetailChapterResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dmzj.comic'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'Title', protoName: 'Title')
    ..pPM<ComicDetailChapterInfoResponse>(2, _omitFieldNames ? '' : 'Data',
        protoName: 'Data', subBuilder: ComicDetailChapterInfoResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicDetailChapterResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicDetailChapterResponse copyWith(
          void Function(ComicDetailChapterResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ComicDetailChapterResponse))
          as ComicDetailChapterResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ComicDetailChapterResponse create() => ComicDetailChapterResponse._();
  @$core.override
  ComicDetailChapterResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ComicDetailChapterResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ComicDetailChapterResponse>(create);
  static ComicDetailChapterResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<ComicDetailChapterInfoResponse> get data => $_getList(1);
}

class ComicDetailChapterInfoResponse extends $pb.GeneratedMessage {
  factory ComicDetailChapterInfoResponse({
    $core.int? chapterId,
    $core.String? chapterTitle,
    $fixnum.Int64? updatetime,
    $core.int? filesize,
    $core.int? chapterOrder,
  }) {
    final result = create();
    if (chapterId != null) result.chapterId = chapterId;
    if (chapterTitle != null) result.chapterTitle = chapterTitle;
    if (updatetime != null) result.updatetime = updatetime;
    if (filesize != null) result.filesize = filesize;
    if (chapterOrder != null) result.chapterOrder = chapterOrder;
    return result;
  }

  ComicDetailChapterInfoResponse._();

  factory ComicDetailChapterInfoResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ComicDetailChapterInfoResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ComicDetailChapterInfoResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dmzj.comic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'ChapterId', protoName: 'ChapterId')
    ..aOS(2, _omitFieldNames ? '' : 'ChapterTitle', protoName: 'ChapterTitle')
    ..aInt64(3, _omitFieldNames ? '' : 'Updatetime', protoName: 'Updatetime')
    ..aI(4, _omitFieldNames ? '' : 'Filesize', protoName: 'Filesize')
    ..aI(5, _omitFieldNames ? '' : 'ChapterOrder', protoName: 'ChapterOrder')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicDetailChapterInfoResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicDetailChapterInfoResponse copyWith(
          void Function(ComicDetailChapterInfoResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ComicDetailChapterInfoResponse))
          as ComicDetailChapterInfoResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ComicDetailChapterInfoResponse create() =>
      ComicDetailChapterInfoResponse._();
  @$core.override
  ComicDetailChapterInfoResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ComicDetailChapterInfoResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ComicDetailChapterInfoResponse>(create);
  static ComicDetailChapterInfoResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get chapterId => $_getIZ(0);
  @$pb.TagNumber(1)
  set chapterId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChapterId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChapterId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get chapterTitle => $_getSZ(1);
  @$pb.TagNumber(2)
  set chapterTitle($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChapterTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearChapterTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get updatetime => $_getI64(2);
  @$pb.TagNumber(3)
  set updatetime($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUpdatetime() => $_has(2);
  @$pb.TagNumber(3)
  void clearUpdatetime() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get filesize => $_getIZ(3);
  @$pb.TagNumber(4)
  set filesize($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFilesize() => $_has(3);
  @$pb.TagNumber(4)
  void clearFilesize() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get chapterOrder => $_getIZ(4);
  @$pb.TagNumber(5)
  set chapterOrder($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasChapterOrder() => $_has(4);
  @$pb.TagNumber(5)
  void clearChapterOrder() => $_clearField(5);
}

class ComicChapterDetailResponse extends $pb.GeneratedMessage {
  factory ComicChapterDetailResponse({
    $core.int? errno,
    $core.String? errmsg,
    ComicChapterDetailInfoResponse? data,
  }) {
    final result = create();
    if (errno != null) result.errno = errno;
    if (errmsg != null) result.errmsg = errmsg;
    if (data != null) result.data = data;
    return result;
  }

  ComicChapterDetailResponse._();

  factory ComicChapterDetailResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ComicChapterDetailResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ComicChapterDetailResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dmzj.comic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'Errno', protoName: 'Errno')
    ..aOS(2, _omitFieldNames ? '' : 'Errmsg', protoName: 'Errmsg')
    ..aOM<ComicChapterDetailInfoResponse>(3, _omitFieldNames ? '' : 'Data',
        protoName: 'Data', subBuilder: ComicChapterDetailInfoResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicChapterDetailResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicChapterDetailResponse copyWith(
          void Function(ComicChapterDetailResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ComicChapterDetailResponse))
          as ComicChapterDetailResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ComicChapterDetailResponse create() => ComicChapterDetailResponse._();
  @$core.override
  ComicChapterDetailResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ComicChapterDetailResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ComicChapterDetailResponse>(create);
  static ComicChapterDetailResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get errno => $_getIZ(0);
  @$pb.TagNumber(1)
  set errno($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasErrno() => $_has(0);
  @$pb.TagNumber(1)
  void clearErrno() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get errmsg => $_getSZ(1);
  @$pb.TagNumber(2)
  set errmsg($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasErrmsg() => $_has(1);
  @$pb.TagNumber(2)
  void clearErrmsg() => $_clearField(2);

  @$pb.TagNumber(3)
  ComicChapterDetailInfoResponse get data => $_getN(2);
  @$pb.TagNumber(3)
  set data(ComicChapterDetailInfoResponse value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasData() => $_has(2);
  @$pb.TagNumber(3)
  void clearData() => $_clearField(3);
  @$pb.TagNumber(3)
  ComicChapterDetailInfoResponse ensureData() => $_ensure(2);
}

class ComicChapterDetailInfoResponse extends $pb.GeneratedMessage {
  factory ComicChapterDetailInfoResponse({
    $core.int? chapterId,
    $core.int? comicId,
    $core.String? title,
    $core.int? order,
    $core.int? status,
    $core.Iterable<$core.String>? smallPages,
    $core.int? length,
    $core.Iterable<$core.String>? rawPages,
    $core.int? fileSize,
  }) {
    final result = create();
    if (chapterId != null) result.chapterId = chapterId;
    if (comicId != null) result.comicId = comicId;
    if (title != null) result.title = title;
    if (order != null) result.order = order;
    if (status != null) result.status = status;
    if (smallPages != null) result.smallPages.addAll(smallPages);
    if (length != null) result.length = length;
    if (rawPages != null) result.rawPages.addAll(rawPages);
    if (fileSize != null) result.fileSize = fileSize;
    return result;
  }

  ComicChapterDetailInfoResponse._();

  factory ComicChapterDetailInfoResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ComicChapterDetailInfoResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ComicChapterDetailInfoResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dmzj.comic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'ChapterId', protoName: 'ChapterId')
    ..aI(2, _omitFieldNames ? '' : 'ComicId', protoName: 'ComicId')
    ..aOS(3, _omitFieldNames ? '' : 'Title', protoName: 'Title')
    ..aI(4, _omitFieldNames ? '' : 'Order', protoName: 'Order')
    ..aI(5, _omitFieldNames ? '' : 'Status', protoName: 'Status')
    ..pPS(6, _omitFieldNames ? '' : 'SmallPages', protoName: 'SmallPages')
    ..aI(7, _omitFieldNames ? '' : 'Length', protoName: 'Length')
    ..pPS(8, _omitFieldNames ? '' : 'RawPages', protoName: 'RawPages')
    ..aI(9, _omitFieldNames ? '' : 'FileSize', protoName: 'FileSize')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicChapterDetailInfoResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicChapterDetailInfoResponse copyWith(
          void Function(ComicChapterDetailInfoResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ComicChapterDetailInfoResponse))
          as ComicChapterDetailInfoResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ComicChapterDetailInfoResponse create() =>
      ComicChapterDetailInfoResponse._();
  @$core.override
  ComicChapterDetailInfoResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ComicChapterDetailInfoResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ComicChapterDetailInfoResponse>(create);
  static ComicChapterDetailInfoResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get chapterId => $_getIZ(0);
  @$pb.TagNumber(1)
  set chapterId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChapterId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChapterId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get comicId => $_getIZ(1);
  @$pb.TagNumber(2)
  set comicId($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasComicId() => $_has(1);
  @$pb.TagNumber(2)
  void clearComicId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get title => $_getSZ(2);
  @$pb.TagNumber(3)
  set title($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearTitle() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get order => $_getIZ(3);
  @$pb.TagNumber(4)
  set order($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOrder() => $_has(3);
  @$pb.TagNumber(4)
  void clearOrder() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get status => $_getIZ(4);
  @$pb.TagNumber(5)
  set status($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStatus() => $_has(4);
  @$pb.TagNumber(5)
  void clearStatus() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get smallPages => $_getList(5);

  @$pb.TagNumber(7)
  $core.int get length => $_getIZ(6);
  @$pb.TagNumber(7)
  set length($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLength() => $_has(6);
  @$pb.TagNumber(7)
  void clearLength() => $_clearField(7);

  @$pb.TagNumber(8)
  $pb.PbList<$core.String> get rawPages => $_getList(7);

  @$pb.TagNumber(9)
  $core.int get fileSize => $_getIZ(8);
  @$pb.TagNumber(9)
  set fileSize($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasFileSize() => $_has(8);
  @$pb.TagNumber(9)
  void clearFileSize() => $_clearField(9);
}

class ComicUpdateListResponse extends $pb.GeneratedMessage {
  factory ComicUpdateListResponse({
    $core.int? errno,
    $core.String? errmsg,
    $core.Iterable<ComicUpdateListItemResponse>? data,
  }) {
    final result = create();
    if (errno != null) result.errno = errno;
    if (errmsg != null) result.errmsg = errmsg;
    if (data != null) result.data.addAll(data);
    return result;
  }

  ComicUpdateListResponse._();

  factory ComicUpdateListResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ComicUpdateListResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ComicUpdateListResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dmzj.comic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'Errno', protoName: 'Errno')
    ..aOS(2, _omitFieldNames ? '' : 'Errmsg', protoName: 'Errmsg')
    ..pPM<ComicUpdateListItemResponse>(3, _omitFieldNames ? '' : 'Data',
        protoName: 'Data', subBuilder: ComicUpdateListItemResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicUpdateListResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicUpdateListResponse copyWith(
          void Function(ComicUpdateListResponse) updates) =>
      super.copyWith((message) => updates(message as ComicUpdateListResponse))
          as ComicUpdateListResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ComicUpdateListResponse create() => ComicUpdateListResponse._();
  @$core.override
  ComicUpdateListResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ComicUpdateListResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ComicUpdateListResponse>(create);
  static ComicUpdateListResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get errno => $_getIZ(0);
  @$pb.TagNumber(1)
  set errno($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasErrno() => $_has(0);
  @$pb.TagNumber(1)
  void clearErrno() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get errmsg => $_getSZ(1);
  @$pb.TagNumber(2)
  set errmsg($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasErrmsg() => $_has(1);
  @$pb.TagNumber(2)
  void clearErrmsg() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<ComicUpdateListItemResponse> get data => $_getList(2);
}

class ComicUpdateListItemResponse extends $pb.GeneratedMessage {
  factory ComicUpdateListItemResponse({
    $core.int? comicId,
    $core.String? title,
    $core.bool? islong,
    $core.String? authors,
    $core.String? types,
    $core.String? cover,
    $core.String? status,
    $core.String? lastUpdateChapterName,
    $core.int? lastUpdateChapterId,
    $fixnum.Int64? lastUpdatetime,
  }) {
    final result = create();
    if (comicId != null) result.comicId = comicId;
    if (title != null) result.title = title;
    if (islong != null) result.islong = islong;
    if (authors != null) result.authors = authors;
    if (types != null) result.types = types;
    if (cover != null) result.cover = cover;
    if (status != null) result.status = status;
    if (lastUpdateChapterName != null)
      result.lastUpdateChapterName = lastUpdateChapterName;
    if (lastUpdateChapterId != null)
      result.lastUpdateChapterId = lastUpdateChapterId;
    if (lastUpdatetime != null) result.lastUpdatetime = lastUpdatetime;
    return result;
  }

  ComicUpdateListItemResponse._();

  factory ComicUpdateListItemResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ComicUpdateListItemResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ComicUpdateListItemResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dmzj.comic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'ComicId', protoName: 'ComicId')
    ..aOS(2, _omitFieldNames ? '' : 'Title', protoName: 'Title')
    ..aOB(3, _omitFieldNames ? '' : 'Islong', protoName: 'Islong')
    ..aOS(4, _omitFieldNames ? '' : 'Authors', protoName: 'Authors')
    ..aOS(5, _omitFieldNames ? '' : 'Types', protoName: 'Types')
    ..aOS(6, _omitFieldNames ? '' : 'Cover', protoName: 'Cover')
    ..aOS(7, _omitFieldNames ? '' : 'Status', protoName: 'Status')
    ..aOS(8, _omitFieldNames ? '' : 'LastUpdateChapterName',
        protoName: 'LastUpdateChapterName')
    ..aI(9, _omitFieldNames ? '' : 'LastUpdateChapterId',
        protoName: 'LastUpdateChapterId')
    ..aInt64(10, _omitFieldNames ? '' : 'LastUpdatetime',
        protoName: 'LastUpdatetime')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicUpdateListItemResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicUpdateListItemResponse copyWith(
          void Function(ComicUpdateListItemResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ComicUpdateListItemResponse))
          as ComicUpdateListItemResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ComicUpdateListItemResponse create() =>
      ComicUpdateListItemResponse._();
  @$core.override
  ComicUpdateListItemResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ComicUpdateListItemResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ComicUpdateListItemResponse>(create);
  static ComicUpdateListItemResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get comicId => $_getIZ(0);
  @$pb.TagNumber(1)
  set comicId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasComicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearComicId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get islong => $_getBF(2);
  @$pb.TagNumber(3)
  set islong($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIslong() => $_has(2);
  @$pb.TagNumber(3)
  void clearIslong() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get authors => $_getSZ(3);
  @$pb.TagNumber(4)
  set authors($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAuthors() => $_has(3);
  @$pb.TagNumber(4)
  void clearAuthors() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get types => $_getSZ(4);
  @$pb.TagNumber(5)
  set types($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTypes() => $_has(4);
  @$pb.TagNumber(5)
  void clearTypes() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get cover => $_getSZ(5);
  @$pb.TagNumber(6)
  set cover($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCover() => $_has(5);
  @$pb.TagNumber(6)
  void clearCover() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get status => $_getSZ(6);
  @$pb.TagNumber(7)
  set status($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasStatus() => $_has(6);
  @$pb.TagNumber(7)
  void clearStatus() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get lastUpdateChapterName => $_getSZ(7);
  @$pb.TagNumber(8)
  set lastUpdateChapterName($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasLastUpdateChapterName() => $_has(7);
  @$pb.TagNumber(8)
  void clearLastUpdateChapterName() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get lastUpdateChapterId => $_getIZ(8);
  @$pb.TagNumber(9)
  set lastUpdateChapterId($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasLastUpdateChapterId() => $_has(8);
  @$pb.TagNumber(9)
  void clearLastUpdateChapterId() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get lastUpdatetime => $_getI64(9);
  @$pb.TagNumber(10)
  set lastUpdatetime($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasLastUpdatetime() => $_has(9);
  @$pb.TagNumber(10)
  void clearLastUpdatetime() => $_clearField(10);
}

class ComicRankListResponse extends $pb.GeneratedMessage {
  factory ComicRankListResponse({
    $core.int? errno,
    $core.String? errmsg,
    $core.Iterable<ComicRankListItemResponse>? data,
  }) {
    final result = create();
    if (errno != null) result.errno = errno;
    if (errmsg != null) result.errmsg = errmsg;
    if (data != null) result.data.addAll(data);
    return result;
  }

  ComicRankListResponse._();

  factory ComicRankListResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ComicRankListResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ComicRankListResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dmzj.comic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'Errno', protoName: 'Errno')
    ..aOS(2, _omitFieldNames ? '' : 'Errmsg', protoName: 'Errmsg')
    ..pPM<ComicRankListItemResponse>(3, _omitFieldNames ? '' : 'Data',
        protoName: 'Data', subBuilder: ComicRankListItemResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicRankListResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicRankListResponse copyWith(
          void Function(ComicRankListResponse) updates) =>
      super.copyWith((message) => updates(message as ComicRankListResponse))
          as ComicRankListResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ComicRankListResponse create() => ComicRankListResponse._();
  @$core.override
  ComicRankListResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ComicRankListResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ComicRankListResponse>(create);
  static ComicRankListResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get errno => $_getIZ(0);
  @$pb.TagNumber(1)
  set errno($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasErrno() => $_has(0);
  @$pb.TagNumber(1)
  void clearErrno() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get errmsg => $_getSZ(1);
  @$pb.TagNumber(2)
  set errmsg($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasErrmsg() => $_has(1);
  @$pb.TagNumber(2)
  void clearErrmsg() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<ComicRankListItemResponse> get data => $_getList(2);
}

class ComicRankListItemResponse extends $pb.GeneratedMessage {
  factory ComicRankListItemResponse({
    $core.int? comicId,
    $core.String? title,
    $core.String? authors,
    $core.String? status,
    $core.String? cover,
    $core.String? types,
    $fixnum.Int64? lastUpdatetime,
    $core.String? lastUpdateChapterName,
    $core.String? comicPy,
    $core.int? num,
    $core.int? tagId,
    $core.String? chapterName,
    $core.int? chapterId,
  }) {
    final result = create();
    if (comicId != null) result.comicId = comicId;
    if (title != null) result.title = title;
    if (authors != null) result.authors = authors;
    if (status != null) result.status = status;
    if (cover != null) result.cover = cover;
    if (types != null) result.types = types;
    if (lastUpdatetime != null) result.lastUpdatetime = lastUpdatetime;
    if (lastUpdateChapterName != null)
      result.lastUpdateChapterName = lastUpdateChapterName;
    if (comicPy != null) result.comicPy = comicPy;
    if (num != null) result.num = num;
    if (tagId != null) result.tagId = tagId;
    if (chapterName != null) result.chapterName = chapterName;
    if (chapterId != null) result.chapterId = chapterId;
    return result;
  }

  ComicRankListItemResponse._();

  factory ComicRankListItemResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ComicRankListItemResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ComicRankListItemResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dmzj.comic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'ComicId', protoName: 'ComicId')
    ..aOS(2, _omitFieldNames ? '' : 'Title', protoName: 'Title')
    ..aOS(3, _omitFieldNames ? '' : 'Authors', protoName: 'Authors')
    ..aOS(4, _omitFieldNames ? '' : 'Status', protoName: 'Status')
    ..aOS(5, _omitFieldNames ? '' : 'Cover', protoName: 'Cover')
    ..aOS(6, _omitFieldNames ? '' : 'Types', protoName: 'Types')
    ..aInt64(7, _omitFieldNames ? '' : 'LastUpdatetime',
        protoName: 'LastUpdatetime')
    ..aOS(8, _omitFieldNames ? '' : 'LastUpdateChapterName',
        protoName: 'LastUpdateChapterName')
    ..aOS(9, _omitFieldNames ? '' : 'ComicPy', protoName: 'ComicPy')
    ..aI(10, _omitFieldNames ? '' : 'Num', protoName: 'Num')
    ..aI(11, _omitFieldNames ? '' : 'TagId', protoName: 'TagId')
    ..aOS(12, _omitFieldNames ? '' : 'ChapterName', protoName: 'ChapterName')
    ..aI(13, _omitFieldNames ? '' : 'ChapterId', protoName: 'ChapterId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicRankListItemResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComicRankListItemResponse copyWith(
          void Function(ComicRankListItemResponse) updates) =>
      super.copyWith((message) => updates(message as ComicRankListItemResponse))
          as ComicRankListItemResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ComicRankListItemResponse create() => ComicRankListItemResponse._();
  @$core.override
  ComicRankListItemResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ComicRankListItemResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ComicRankListItemResponse>(create);
  static ComicRankListItemResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get comicId => $_getIZ(0);
  @$pb.TagNumber(1)
  set comicId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasComicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearComicId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get authors => $_getSZ(2);
  @$pb.TagNumber(3)
  set authors($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAuthors() => $_has(2);
  @$pb.TagNumber(3)
  void clearAuthors() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get status => $_getSZ(3);
  @$pb.TagNumber(4)
  set status($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatus() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get cover => $_getSZ(4);
  @$pb.TagNumber(5)
  set cover($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCover() => $_has(4);
  @$pb.TagNumber(5)
  void clearCover() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get types => $_getSZ(5);
  @$pb.TagNumber(6)
  set types($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTypes() => $_has(5);
  @$pb.TagNumber(6)
  void clearTypes() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get lastUpdatetime => $_getI64(6);
  @$pb.TagNumber(7)
  set lastUpdatetime($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLastUpdatetime() => $_has(6);
  @$pb.TagNumber(7)
  void clearLastUpdatetime() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get lastUpdateChapterName => $_getSZ(7);
  @$pb.TagNumber(8)
  set lastUpdateChapterName($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasLastUpdateChapterName() => $_has(7);
  @$pb.TagNumber(8)
  void clearLastUpdateChapterName() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get comicPy => $_getSZ(8);
  @$pb.TagNumber(9)
  set comicPy($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasComicPy() => $_has(8);
  @$pb.TagNumber(9)
  void clearComicPy() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get num => $_getIZ(9);
  @$pb.TagNumber(10)
  set num($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasNum() => $_has(9);
  @$pb.TagNumber(10)
  void clearNum() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get tagId => $_getIZ(10);
  @$pb.TagNumber(11)
  set tagId($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasTagId() => $_has(10);
  @$pb.TagNumber(11)
  void clearTagId() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get chapterName => $_getSZ(11);
  @$pb.TagNumber(12)
  set chapterName($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasChapterName() => $_has(11);
  @$pb.TagNumber(12)
  void clearChapterName() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get chapterId => $_getIZ(12);
  @$pb.TagNumber(13)
  set chapterId($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasChapterId() => $_has(12);
  @$pb.TagNumber(13)
  void clearChapterId() => $_clearField(13);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');

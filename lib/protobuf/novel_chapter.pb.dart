// This is a generated file - do not edit.
//
// Generated from novel_chapter.proto.

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

class NovelChapterResponse extends $pb.GeneratedMessage {
  factory NovelChapterResponse({
    $core.int? errno,
    $core.String? errmsg,
    $core.Iterable<NovelChapterVolumeResponse>? data,
  }) {
    final result = create();
    if (errno != null) result.errno = errno;
    if (errmsg != null) result.errmsg = errmsg;
    if (data != null) result.data.addAll(data);
    return result;
  }

  NovelChapterResponse._();

  factory NovelChapterResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NovelChapterResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NovelChapterResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dmzj.novel'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'Errno', protoName: 'Errno')
    ..aOS(2, _omitFieldNames ? '' : 'Errmsg', protoName: 'Errmsg')
    ..pPM<NovelChapterVolumeResponse>(3, _omitFieldNames ? '' : 'Data',
        protoName: 'Data', subBuilder: NovelChapterVolumeResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NovelChapterResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NovelChapterResponse copyWith(void Function(NovelChapterResponse) updates) =>
      super.copyWith((message) => updates(message as NovelChapterResponse))
          as NovelChapterResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NovelChapterResponse create() => NovelChapterResponse._();
  @$core.override
  NovelChapterResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NovelChapterResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NovelChapterResponse>(create);
  static NovelChapterResponse? _defaultInstance;

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
  $pb.PbList<NovelChapterVolumeResponse> get data => $_getList(2);
}

class NovelChapterVolumeResponse extends $pb.GeneratedMessage {
  factory NovelChapterVolumeResponse({
    $core.int? volumeId,
    $core.String? volumeName,
    $core.int? volumeOrder,
    $core.Iterable<NovelChapterItemResponse>? chapters,
  }) {
    final result = create();
    if (volumeId != null) result.volumeId = volumeId;
    if (volumeName != null) result.volumeName = volumeName;
    if (volumeOrder != null) result.volumeOrder = volumeOrder;
    if (chapters != null) result.chapters.addAll(chapters);
    return result;
  }

  NovelChapterVolumeResponse._();

  factory NovelChapterVolumeResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NovelChapterVolumeResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NovelChapterVolumeResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dmzj.novel'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'VolumeId', protoName: 'VolumeId')
    ..aOS(2, _omitFieldNames ? '' : 'VolumeName', protoName: 'VolumeName')
    ..aI(3, _omitFieldNames ? '' : 'VolumeOrder', protoName: 'VolumeOrder')
    ..pPM<NovelChapterItemResponse>(4, _omitFieldNames ? '' : 'Chapters',
        protoName: 'Chapters', subBuilder: NovelChapterItemResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NovelChapterVolumeResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NovelChapterVolumeResponse copyWith(
          void Function(NovelChapterVolumeResponse) updates) =>
      super.copyWith(
              (message) => updates(message as NovelChapterVolumeResponse))
          as NovelChapterVolumeResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NovelChapterVolumeResponse create() => NovelChapterVolumeResponse._();
  @$core.override
  NovelChapterVolumeResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NovelChapterVolumeResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NovelChapterVolumeResponse>(create);
  static NovelChapterVolumeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get volumeId => $_getIZ(0);
  @$pb.TagNumber(1)
  set volumeId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVolumeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearVolumeId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get volumeName => $_getSZ(1);
  @$pb.TagNumber(2)
  set volumeName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVolumeName() => $_has(1);
  @$pb.TagNumber(2)
  void clearVolumeName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get volumeOrder => $_getIZ(2);
  @$pb.TagNumber(3)
  set volumeOrder($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVolumeOrder() => $_has(2);
  @$pb.TagNumber(3)
  void clearVolumeOrder() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<NovelChapterItemResponse> get chapters => $_getList(3);
}

class NovelChapterItemResponse extends $pb.GeneratedMessage {
  factory NovelChapterItemResponse({
    $core.int? chapterId,
    $core.String? chapterName,
    $core.int? chapterOrder,
  }) {
    final result = create();
    if (chapterId != null) result.chapterId = chapterId;
    if (chapterName != null) result.chapterName = chapterName;
    if (chapterOrder != null) result.chapterOrder = chapterOrder;
    return result;
  }

  NovelChapterItemResponse._();

  factory NovelChapterItemResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NovelChapterItemResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NovelChapterItemResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dmzj.novel'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'ChapterId', protoName: 'ChapterId')
    ..aOS(2, _omitFieldNames ? '' : 'ChapterName', protoName: 'ChapterName')
    ..aI(3, _omitFieldNames ? '' : 'ChapterOrder', protoName: 'ChapterOrder')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NovelChapterItemResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NovelChapterItemResponse copyWith(
          void Function(NovelChapterItemResponse) updates) =>
      super.copyWith((message) => updates(message as NovelChapterItemResponse))
          as NovelChapterItemResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NovelChapterItemResponse create() => NovelChapterItemResponse._();
  @$core.override
  NovelChapterItemResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NovelChapterItemResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NovelChapterItemResponse>(create);
  static NovelChapterItemResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get chapterId => $_getIZ(0);
  @$pb.TagNumber(1)
  set chapterId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChapterId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChapterId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get chapterName => $_getSZ(1);
  @$pb.TagNumber(2)
  set chapterName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChapterName() => $_has(1);
  @$pb.TagNumber(2)
  void clearChapterName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get chapterOrder => $_getIZ(2);
  @$pb.TagNumber(3)
  set chapterOrder($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasChapterOrder() => $_has(2);
  @$pb.TagNumber(3)
  void clearChapterOrder() => $_clearField(3);
}

class NovelDetailResponse extends $pb.GeneratedMessage {
  factory NovelDetailResponse({
    $core.int? errno,
    $core.String? errmsg,
    NovelDetailInfoResponse? data,
  }) {
    final result = create();
    if (errno != null) result.errno = errno;
    if (errmsg != null) result.errmsg = errmsg;
    if (data != null) result.data = data;
    return result;
  }

  NovelDetailResponse._();

  factory NovelDetailResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NovelDetailResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NovelDetailResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dmzj.novel'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'Errno', protoName: 'Errno')
    ..aOS(2, _omitFieldNames ? '' : 'Errmsg', protoName: 'Errmsg')
    ..aOM<NovelDetailInfoResponse>(3, _omitFieldNames ? '' : 'Data',
        protoName: 'Data', subBuilder: NovelDetailInfoResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NovelDetailResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NovelDetailResponse copyWith(void Function(NovelDetailResponse) updates) =>
      super.copyWith((message) => updates(message as NovelDetailResponse))
          as NovelDetailResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NovelDetailResponse create() => NovelDetailResponse._();
  @$core.override
  NovelDetailResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NovelDetailResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NovelDetailResponse>(create);
  static NovelDetailResponse? _defaultInstance;

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
  NovelDetailInfoResponse get data => $_getN(2);
  @$pb.TagNumber(3)
  set data(NovelDetailInfoResponse value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasData() => $_has(2);
  @$pb.TagNumber(3)
  void clearData() => $_clearField(3);
  @$pb.TagNumber(3)
  NovelDetailInfoResponse ensureData() => $_ensure(2);
}

class NovelDetailInfoResponse extends $pb.GeneratedMessage {
  factory NovelDetailInfoResponse({
    $core.int? novelId,
    $core.String? name,
    $core.String? zone,
    $core.String? status,
    $core.String? lastUpdateVolumeName,
    $core.String? lastUpdateChapterName,
    $core.int? lastUpdateVolumeId,
    $core.int? lastUpdateChapterId,
    $fixnum.Int64? lastUpdateTime,
    $core.String? cover,
    $core.int? hotHits,
    $core.String? introduction,
    $core.Iterable<$core.String>? types,
    $core.String? authors,
    $core.String? firstLetter,
    $core.int? subscribeNum,
    $fixnum.Int64? redisUpdateTime,
    $core.Iterable<NovelDetailInfoVolumeResponse>? volume,
  }) {
    final result = create();
    if (novelId != null) result.novelId = novelId;
    if (name != null) result.name = name;
    if (zone != null) result.zone = zone;
    if (status != null) result.status = status;
    if (lastUpdateVolumeName != null)
      result.lastUpdateVolumeName = lastUpdateVolumeName;
    if (lastUpdateChapterName != null)
      result.lastUpdateChapterName = lastUpdateChapterName;
    if (lastUpdateVolumeId != null)
      result.lastUpdateVolumeId = lastUpdateVolumeId;
    if (lastUpdateChapterId != null)
      result.lastUpdateChapterId = lastUpdateChapterId;
    if (lastUpdateTime != null) result.lastUpdateTime = lastUpdateTime;
    if (cover != null) result.cover = cover;
    if (hotHits != null) result.hotHits = hotHits;
    if (introduction != null) result.introduction = introduction;
    if (types != null) result.types.addAll(types);
    if (authors != null) result.authors = authors;
    if (firstLetter != null) result.firstLetter = firstLetter;
    if (subscribeNum != null) result.subscribeNum = subscribeNum;
    if (redisUpdateTime != null) result.redisUpdateTime = redisUpdateTime;
    if (volume != null) result.volume.addAll(volume);
    return result;
  }

  NovelDetailInfoResponse._();

  factory NovelDetailInfoResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NovelDetailInfoResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NovelDetailInfoResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dmzj.novel'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'NovelId', protoName: 'NovelId')
    ..aOS(2, _omitFieldNames ? '' : 'Name', protoName: 'Name')
    ..aOS(3, _omitFieldNames ? '' : 'Zone', protoName: 'Zone')
    ..aOS(4, _omitFieldNames ? '' : 'Status', protoName: 'Status')
    ..aOS(5, _omitFieldNames ? '' : 'LastUpdateVolumeName',
        protoName: 'LastUpdateVolumeName')
    ..aOS(6, _omitFieldNames ? '' : 'LastUpdateChapterName',
        protoName: 'LastUpdateChapterName')
    ..aI(7, _omitFieldNames ? '' : 'LastUpdateVolumeId',
        protoName: 'LastUpdateVolumeId')
    ..aI(8, _omitFieldNames ? '' : 'LastUpdateChapterId',
        protoName: 'LastUpdateChapterId')
    ..aInt64(9, _omitFieldNames ? '' : 'LastUpdateTime',
        protoName: 'LastUpdateTime')
    ..aOS(10, _omitFieldNames ? '' : 'Cover', protoName: 'Cover')
    ..aI(11, _omitFieldNames ? '' : 'HotHits', protoName: 'HotHits')
    ..aOS(12, _omitFieldNames ? '' : 'Introduction', protoName: 'Introduction')
    ..pPS(13, _omitFieldNames ? '' : 'Types', protoName: 'Types')
    ..aOS(14, _omitFieldNames ? '' : 'Authors', protoName: 'Authors')
    ..aOS(15, _omitFieldNames ? '' : 'FirstLetter', protoName: 'FirstLetter')
    ..aI(16, _omitFieldNames ? '' : 'SubscribeNum', protoName: 'SubscribeNum')
    ..aInt64(17, _omitFieldNames ? '' : 'RedisUpdateTime',
        protoName: 'RedisUpdateTime')
    ..pPM<NovelDetailInfoVolumeResponse>(18, _omitFieldNames ? '' : 'Volume',
        protoName: 'Volume', subBuilder: NovelDetailInfoVolumeResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NovelDetailInfoResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NovelDetailInfoResponse copyWith(
          void Function(NovelDetailInfoResponse) updates) =>
      super.copyWith((message) => updates(message as NovelDetailInfoResponse))
          as NovelDetailInfoResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NovelDetailInfoResponse create() => NovelDetailInfoResponse._();
  @$core.override
  NovelDetailInfoResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NovelDetailInfoResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NovelDetailInfoResponse>(create);
  static NovelDetailInfoResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get novelId => $_getIZ(0);
  @$pb.TagNumber(1)
  set novelId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNovelId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNovelId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get zone => $_getSZ(2);
  @$pb.TagNumber(3)
  set zone($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasZone() => $_has(2);
  @$pb.TagNumber(3)
  void clearZone() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get status => $_getSZ(3);
  @$pb.TagNumber(4)
  set status($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatus() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get lastUpdateVolumeName => $_getSZ(4);
  @$pb.TagNumber(5)
  set lastUpdateVolumeName($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLastUpdateVolumeName() => $_has(4);
  @$pb.TagNumber(5)
  void clearLastUpdateVolumeName() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get lastUpdateChapterName => $_getSZ(5);
  @$pb.TagNumber(6)
  set lastUpdateChapterName($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasLastUpdateChapterName() => $_has(5);
  @$pb.TagNumber(6)
  void clearLastUpdateChapterName() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get lastUpdateVolumeId => $_getIZ(6);
  @$pb.TagNumber(7)
  set lastUpdateVolumeId($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLastUpdateVolumeId() => $_has(6);
  @$pb.TagNumber(7)
  void clearLastUpdateVolumeId() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get lastUpdateChapterId => $_getIZ(7);
  @$pb.TagNumber(8)
  set lastUpdateChapterId($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasLastUpdateChapterId() => $_has(7);
  @$pb.TagNumber(8)
  void clearLastUpdateChapterId() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get lastUpdateTime => $_getI64(8);
  @$pb.TagNumber(9)
  set lastUpdateTime($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasLastUpdateTime() => $_has(8);
  @$pb.TagNumber(9)
  void clearLastUpdateTime() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get cover => $_getSZ(9);
  @$pb.TagNumber(10)
  set cover($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasCover() => $_has(9);
  @$pb.TagNumber(10)
  void clearCover() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get hotHits => $_getIZ(10);
  @$pb.TagNumber(11)
  set hotHits($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasHotHits() => $_has(10);
  @$pb.TagNumber(11)
  void clearHotHits() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get introduction => $_getSZ(11);
  @$pb.TagNumber(12)
  set introduction($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasIntroduction() => $_has(11);
  @$pb.TagNumber(12)
  void clearIntroduction() => $_clearField(12);

  @$pb.TagNumber(13)
  $pb.PbList<$core.String> get types => $_getList(12);

  @$pb.TagNumber(14)
  $core.String get authors => $_getSZ(13);
  @$pb.TagNumber(14)
  set authors($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasAuthors() => $_has(13);
  @$pb.TagNumber(14)
  void clearAuthors() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get firstLetter => $_getSZ(14);
  @$pb.TagNumber(15)
  set firstLetter($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasFirstLetter() => $_has(14);
  @$pb.TagNumber(15)
  void clearFirstLetter() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.int get subscribeNum => $_getIZ(15);
  @$pb.TagNumber(16)
  set subscribeNum($core.int value) => $_setSignedInt32(15, value);
  @$pb.TagNumber(16)
  $core.bool hasSubscribeNum() => $_has(15);
  @$pb.TagNumber(16)
  void clearSubscribeNum() => $_clearField(16);

  @$pb.TagNumber(17)
  $fixnum.Int64 get redisUpdateTime => $_getI64(16);
  @$pb.TagNumber(17)
  set redisUpdateTime($fixnum.Int64 value) => $_setInt64(16, value);
  @$pb.TagNumber(17)
  $core.bool hasRedisUpdateTime() => $_has(16);
  @$pb.TagNumber(17)
  void clearRedisUpdateTime() => $_clearField(17);

  @$pb.TagNumber(18)
  $pb.PbList<NovelDetailInfoVolumeResponse> get volume => $_getList(17);
}

class NovelDetailInfoVolumeResponse extends $pb.GeneratedMessage {
  factory NovelDetailInfoVolumeResponse({
    $core.int? volumeId,
    $core.int? lnovelId,
    $core.String? volumeName,
    $core.int? volumeOrder,
    $fixnum.Int64? addtime,
    $core.int? sumChapters,
  }) {
    final result = create();
    if (volumeId != null) result.volumeId = volumeId;
    if (lnovelId != null) result.lnovelId = lnovelId;
    if (volumeName != null) result.volumeName = volumeName;
    if (volumeOrder != null) result.volumeOrder = volumeOrder;
    if (addtime != null) result.addtime = addtime;
    if (sumChapters != null) result.sumChapters = sumChapters;
    return result;
  }

  NovelDetailInfoVolumeResponse._();

  factory NovelDetailInfoVolumeResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NovelDetailInfoVolumeResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NovelDetailInfoVolumeResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dmzj.novel'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'VolumeId', protoName: 'VolumeId')
    ..aI(2, _omitFieldNames ? '' : 'LnovelId', protoName: 'LnovelId')
    ..aOS(3, _omitFieldNames ? '' : 'VolumeName', protoName: 'VolumeName')
    ..aI(4, _omitFieldNames ? '' : 'VolumeOrder', protoName: 'VolumeOrder')
    ..aInt64(5, _omitFieldNames ? '' : 'Addtime', protoName: 'Addtime')
    ..aI(6, _omitFieldNames ? '' : 'SumChapters', protoName: 'SumChapters')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NovelDetailInfoVolumeResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NovelDetailInfoVolumeResponse copyWith(
          void Function(NovelDetailInfoVolumeResponse) updates) =>
      super.copyWith(
              (message) => updates(message as NovelDetailInfoVolumeResponse))
          as NovelDetailInfoVolumeResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NovelDetailInfoVolumeResponse create() =>
      NovelDetailInfoVolumeResponse._();
  @$core.override
  NovelDetailInfoVolumeResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NovelDetailInfoVolumeResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NovelDetailInfoVolumeResponse>(create);
  static NovelDetailInfoVolumeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get volumeId => $_getIZ(0);
  @$pb.TagNumber(1)
  set volumeId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVolumeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearVolumeId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get lnovelId => $_getIZ(1);
  @$pb.TagNumber(2)
  set lnovelId($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLnovelId() => $_has(1);
  @$pb.TagNumber(2)
  void clearLnovelId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get volumeName => $_getSZ(2);
  @$pb.TagNumber(3)
  set volumeName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVolumeName() => $_has(2);
  @$pb.TagNumber(3)
  void clearVolumeName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get volumeOrder => $_getIZ(3);
  @$pb.TagNumber(4)
  set volumeOrder($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVolumeOrder() => $_has(3);
  @$pb.TagNumber(4)
  void clearVolumeOrder() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get addtime => $_getI64(4);
  @$pb.TagNumber(5)
  set addtime($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAddtime() => $_has(4);
  @$pb.TagNumber(5)
  void clearAddtime() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get sumChapters => $_getIZ(5);
  @$pb.TagNumber(6)
  set sumChapters($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSumChapters() => $_has(5);
  @$pb.TagNumber(6)
  void clearSumChapters() => $_clearField(6);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');

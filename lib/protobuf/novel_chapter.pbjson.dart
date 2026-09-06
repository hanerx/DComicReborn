// This is a generated file - do not edit.
//
// Generated from novel_chapter.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use novelChapterResponseDescriptor instead')
const NovelChapterResponse$json = {
  '1': 'NovelChapterResponse',
  '2': [
    {'1': 'Errno', '3': 1, '4': 1, '5': 5, '10': 'Errno'},
    {'1': 'Errmsg', '3': 2, '4': 1, '5': 9, '10': 'Errmsg'},
    {
      '1': 'Data',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.dmzj.novel.NovelChapterVolumeResponse',
      '10': 'Data'
    },
  ],
};

/// Descriptor for `NovelChapterResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List novelChapterResponseDescriptor = $convert.base64Decode(
    'ChROb3ZlbENoYXB0ZXJSZXNwb25zZRIUCgVFcnJubxgBIAEoBVIFRXJybm8SFgoGRXJybXNnGA'
    'IgASgJUgZFcnJtc2cSOgoERGF0YRgDIAMoCzImLmRtemoubm92ZWwuTm92ZWxDaGFwdGVyVm9s'
    'dW1lUmVzcG9uc2VSBERhdGE=');

@$core.Deprecated('Use novelChapterVolumeResponseDescriptor instead')
const NovelChapterVolumeResponse$json = {
  '1': 'NovelChapterVolumeResponse',
  '2': [
    {'1': 'VolumeId', '3': 1, '4': 1, '5': 5, '10': 'VolumeId'},
    {'1': 'VolumeName', '3': 2, '4': 1, '5': 9, '10': 'VolumeName'},
    {'1': 'VolumeOrder', '3': 3, '4': 1, '5': 5, '10': 'VolumeOrder'},
    {
      '1': 'Chapters',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.dmzj.novel.NovelChapterItemResponse',
      '10': 'Chapters'
    },
  ],
};

/// Descriptor for `NovelChapterVolumeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List novelChapterVolumeResponseDescriptor = $convert.base64Decode(
    'ChpOb3ZlbENoYXB0ZXJWb2x1bWVSZXNwb25zZRIaCghWb2x1bWVJZBgBIAEoBVIIVm9sdW1lSW'
    'QSHgoKVm9sdW1lTmFtZRgCIAEoCVIKVm9sdW1lTmFtZRIgCgtWb2x1bWVPcmRlchgDIAEoBVIL'
    'Vm9sdW1lT3JkZXISQAoIQ2hhcHRlcnMYBCADKAsyJC5kbXpqLm5vdmVsLk5vdmVsQ2hhcHRlck'
    'l0ZW1SZXNwb25zZVIIQ2hhcHRlcnM=');

@$core.Deprecated('Use novelChapterItemResponseDescriptor instead')
const NovelChapterItemResponse$json = {
  '1': 'NovelChapterItemResponse',
  '2': [
    {'1': 'ChapterId', '3': 1, '4': 1, '5': 5, '10': 'ChapterId'},
    {'1': 'ChapterName', '3': 2, '4': 1, '5': 9, '10': 'ChapterName'},
    {'1': 'ChapterOrder', '3': 3, '4': 1, '5': 5, '10': 'ChapterOrder'},
  ],
};

/// Descriptor for `NovelChapterItemResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List novelChapterItemResponseDescriptor = $convert.base64Decode(
    'ChhOb3ZlbENoYXB0ZXJJdGVtUmVzcG9uc2USHAoJQ2hhcHRlcklkGAEgASgFUglDaGFwdGVySW'
    'QSIAoLQ2hhcHRlck5hbWUYAiABKAlSC0NoYXB0ZXJOYW1lEiIKDENoYXB0ZXJPcmRlchgDIAEo'
    'BVIMQ2hhcHRlck9yZGVy');

@$core.Deprecated('Use novelDetailResponseDescriptor instead')
const NovelDetailResponse$json = {
  '1': 'NovelDetailResponse',
  '2': [
    {'1': 'Errno', '3': 1, '4': 1, '5': 5, '10': 'Errno'},
    {'1': 'Errmsg', '3': 2, '4': 1, '5': 9, '10': 'Errmsg'},
    {
      '1': 'Data',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.dmzj.novel.NovelDetailInfoResponse',
      '10': 'Data'
    },
  ],
};

/// Descriptor for `NovelDetailResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List novelDetailResponseDescriptor = $convert.base64Decode(
    'ChNOb3ZlbERldGFpbFJlc3BvbnNlEhQKBUVycm5vGAEgASgFUgVFcnJubxIWCgZFcnJtc2cYAi'
    'ABKAlSBkVycm1zZxI3CgREYXRhGAMgASgLMiMuZG16ai5ub3ZlbC5Ob3ZlbERldGFpbEluZm9S'
    'ZXNwb25zZVIERGF0YQ==');

@$core.Deprecated('Use novelDetailInfoResponseDescriptor instead')
const NovelDetailInfoResponse$json = {
  '1': 'NovelDetailInfoResponse',
  '2': [
    {'1': 'NovelId', '3': 1, '4': 1, '5': 5, '10': 'NovelId'},
    {'1': 'Name', '3': 2, '4': 1, '5': 9, '10': 'Name'},
    {'1': 'Zone', '3': 3, '4': 1, '5': 9, '10': 'Zone'},
    {'1': 'Status', '3': 4, '4': 1, '5': 9, '10': 'Status'},
    {
      '1': 'LastUpdateVolumeName',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'LastUpdateVolumeName'
    },
    {
      '1': 'LastUpdateChapterName',
      '3': 6,
      '4': 1,
      '5': 9,
      '10': 'LastUpdateChapterName'
    },
    {
      '1': 'LastUpdateVolumeId',
      '3': 7,
      '4': 1,
      '5': 5,
      '10': 'LastUpdateVolumeId'
    },
    {
      '1': 'LastUpdateChapterId',
      '3': 8,
      '4': 1,
      '5': 5,
      '10': 'LastUpdateChapterId'
    },
    {'1': 'LastUpdateTime', '3': 9, '4': 1, '5': 3, '10': 'LastUpdateTime'},
    {'1': 'Cover', '3': 10, '4': 1, '5': 9, '10': 'Cover'},
    {'1': 'HotHits', '3': 11, '4': 1, '5': 5, '10': 'HotHits'},
    {'1': 'Introduction', '3': 12, '4': 1, '5': 9, '10': 'Introduction'},
    {'1': 'Types', '3': 13, '4': 3, '5': 9, '10': 'Types'},
    {'1': 'Authors', '3': 14, '4': 1, '5': 9, '10': 'Authors'},
    {'1': 'FirstLetter', '3': 15, '4': 1, '5': 9, '10': 'FirstLetter'},
    {'1': 'SubscribeNum', '3': 16, '4': 1, '5': 5, '10': 'SubscribeNum'},
    {'1': 'RedisUpdateTime', '3': 17, '4': 1, '5': 3, '10': 'RedisUpdateTime'},
    {
      '1': 'Volume',
      '3': 18,
      '4': 3,
      '5': 11,
      '6': '.dmzj.novel.NovelDetailInfoVolumeResponse',
      '10': 'Volume'
    },
  ],
};

/// Descriptor for `NovelDetailInfoResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List novelDetailInfoResponseDescriptor = $convert.base64Decode(
    'ChdOb3ZlbERldGFpbEluZm9SZXNwb25zZRIYCgdOb3ZlbElkGAEgASgFUgdOb3ZlbElkEhIKBE'
    '5hbWUYAiABKAlSBE5hbWUSEgoEWm9uZRgDIAEoCVIEWm9uZRIWCgZTdGF0dXMYBCABKAlSBlN0'
    'YXR1cxIyChRMYXN0VXBkYXRlVm9sdW1lTmFtZRgFIAEoCVIUTGFzdFVwZGF0ZVZvbHVtZU5hbW'
    'USNAoVTGFzdFVwZGF0ZUNoYXB0ZXJOYW1lGAYgASgJUhVMYXN0VXBkYXRlQ2hhcHRlck5hbWUS'
    'LgoSTGFzdFVwZGF0ZVZvbHVtZUlkGAcgASgFUhJMYXN0VXBkYXRlVm9sdW1lSWQSMAoTTGFzdF'
    'VwZGF0ZUNoYXB0ZXJJZBgIIAEoBVITTGFzdFVwZGF0ZUNoYXB0ZXJJZBImCg5MYXN0VXBkYXRl'
    'VGltZRgJIAEoA1IOTGFzdFVwZGF0ZVRpbWUSFAoFQ292ZXIYCiABKAlSBUNvdmVyEhgKB0hvdE'
    'hpdHMYCyABKAVSB0hvdEhpdHMSIgoMSW50cm9kdWN0aW9uGAwgASgJUgxJbnRyb2R1Y3Rpb24S'
    'FAoFVHlwZXMYDSADKAlSBVR5cGVzEhgKB0F1dGhvcnMYDiABKAlSB0F1dGhvcnMSIAoLRmlyc3'
    'RMZXR0ZXIYDyABKAlSC0ZpcnN0TGV0dGVyEiIKDFN1YnNjcmliZU51bRgQIAEoBVIMU3Vic2Ny'
    'aWJlTnVtEigKD1JlZGlzVXBkYXRlVGltZRgRIAEoA1IPUmVkaXNVcGRhdGVUaW1lEkEKBlZvbH'
    'VtZRgSIAMoCzIpLmRtemoubm92ZWwuTm92ZWxEZXRhaWxJbmZvVm9sdW1lUmVzcG9uc2VSBlZv'
    'bHVtZQ==');

@$core.Deprecated('Use novelDetailInfoVolumeResponseDescriptor instead')
const NovelDetailInfoVolumeResponse$json = {
  '1': 'NovelDetailInfoVolumeResponse',
  '2': [
    {'1': 'VolumeId', '3': 1, '4': 1, '5': 5, '10': 'VolumeId'},
    {'1': 'LnovelId', '3': 2, '4': 1, '5': 5, '10': 'LnovelId'},
    {'1': 'VolumeName', '3': 3, '4': 1, '5': 9, '10': 'VolumeName'},
    {'1': 'VolumeOrder', '3': 4, '4': 1, '5': 5, '10': 'VolumeOrder'},
    {'1': 'Addtime', '3': 5, '4': 1, '5': 3, '10': 'Addtime'},
    {'1': 'SumChapters', '3': 6, '4': 1, '5': 5, '10': 'SumChapters'},
  ],
};

/// Descriptor for `NovelDetailInfoVolumeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List novelDetailInfoVolumeResponseDescriptor = $convert.base64Decode(
    'Ch1Ob3ZlbERldGFpbEluZm9Wb2x1bWVSZXNwb25zZRIaCghWb2x1bWVJZBgBIAEoBVIIVm9sdW'
    '1lSWQSGgoITG5vdmVsSWQYAiABKAVSCExub3ZlbElkEh4KClZvbHVtZU5hbWUYAyABKAlSClZv'
    'bHVtZU5hbWUSIAoLVm9sdW1lT3JkZXIYBCABKAVSC1ZvbHVtZU9yZGVyEhgKB0FkZHRpbWUYBS'
    'ABKANSB0FkZHRpbWUSIAoLU3VtQ2hhcHRlcnMYBiABKAVSC1N1bUNoYXB0ZXJz');

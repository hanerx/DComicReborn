// This is a generated file - do not edit.
//
// Generated from comic.proto.

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

@$core.Deprecated('Use comicDetailResponseDescriptor instead')
const ComicDetailResponse$json = {
  '1': 'ComicDetailResponse',
  '2': [
    {'1': 'Errno', '3': 1, '4': 1, '5': 5, '10': 'Errno'},
    {'1': 'Errmsg', '3': 2, '4': 1, '5': 9, '10': 'Errmsg'},
    {
      '1': 'Data',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.dmzj.comic.ComicDetailInfoResponse',
      '10': 'Data'
    },
  ],
};

/// Descriptor for `ComicDetailResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List comicDetailResponseDescriptor = $convert.base64Decode(
    'ChNDb21pY0RldGFpbFJlc3BvbnNlEhQKBUVycm5vGAEgASgFUgVFcnJubxIWCgZFcnJtc2cYAi'
    'ABKAlSBkVycm1zZxI3CgREYXRhGAMgASgLMiMuZG16ai5jb21pYy5Db21pY0RldGFpbEluZm9S'
    'ZXNwb25zZVIERGF0YQ==');

@$core.Deprecated('Use comicDetailInfoResponseDescriptor instead')
const ComicDetailInfoResponse$json = {
  '1': 'ComicDetailInfoResponse',
  '2': [
    {'1': 'Id', '3': 1, '4': 1, '5': 5, '10': 'Id'},
    {'1': 'Title', '3': 2, '4': 1, '5': 9, '10': 'Title'},
    {'1': 'Direction', '3': 3, '4': 1, '5': 5, '10': 'Direction'},
    {'1': 'Islong', '3': 4, '4': 1, '5': 5, '10': 'Islong'},
    {'1': 'IsDmzj', '3': 5, '4': 1, '5': 5, '10': 'IsDmzj'},
    {'1': 'Cover', '3': 6, '4': 1, '5': 9, '10': 'Cover'},
    {'1': 'Description', '3': 7, '4': 1, '5': 9, '10': 'Description'},
    {'1': 'LastUpdatetime', '3': 8, '4': 1, '5': 3, '10': 'LastUpdatetime'},
    {
      '1': 'LastUpdateChapterName',
      '3': 9,
      '4': 1,
      '5': 9,
      '10': 'LastUpdateChapterName'
    },
    {'1': 'Copyright', '3': 10, '4': 1, '5': 5, '10': 'Copyright'},
    {'1': 'FirstLetter', '3': 11, '4': 1, '5': 9, '10': 'FirstLetter'},
    {'1': 'ComicPy', '3': 12, '4': 1, '5': 9, '10': 'ComicPy'},
    {'1': 'Hidden', '3': 13, '4': 1, '5': 5, '10': 'Hidden'},
    {'1': 'HotNum', '3': 14, '4': 1, '5': 5, '10': 'HotNum'},
    {'1': 'HitNum', '3': 15, '4': 1, '5': 5, '10': 'HitNum'},
    {'1': 'Uid', '3': 16, '4': 1, '5': 5, '10': 'Uid'},
    {'1': 'IsLock', '3': 17, '4': 1, '5': 5, '10': 'IsLock'},
    {
      '1': 'LastUpdateChapterId',
      '3': 18,
      '4': 1,
      '5': 5,
      '10': 'LastUpdateChapterId'
    },
    {
      '1': 'Types',
      '3': 19,
      '4': 3,
      '5': 11,
      '6': '.dmzj.comic.ComicDetailTypeItemResponse',
      '10': 'Types'
    },
    {
      '1': 'Status',
      '3': 20,
      '4': 3,
      '5': 11,
      '6': '.dmzj.comic.ComicDetailTypeItemResponse',
      '10': 'Status'
    },
    {
      '1': 'Authors',
      '3': 21,
      '4': 3,
      '5': 11,
      '6': '.dmzj.comic.ComicDetailTypeItemResponse',
      '10': 'Authors'
    },
    {'1': 'SubscribeNum', '3': 22, '4': 1, '5': 5, '10': 'SubscribeNum'},
    {
      '1': 'Chapters',
      '3': 23,
      '4': 3,
      '5': 11,
      '6': '.dmzj.comic.ComicDetailChapterResponse',
      '10': 'Chapters'
    },
    {'1': 'IsNeedLogin', '3': 24, '4': 1, '5': 5, '10': 'IsNeedLogin'},
    {'1': 'IsHideChapter', '3': 26, '4': 1, '5': 5, '10': 'IsHideChapter'},
  ],
};

/// Descriptor for `ComicDetailInfoResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List comicDetailInfoResponseDescriptor = $convert.base64Decode(
    'ChdDb21pY0RldGFpbEluZm9SZXNwb25zZRIOCgJJZBgBIAEoBVICSWQSFAoFVGl0bGUYAiABKA'
    'lSBVRpdGxlEhwKCURpcmVjdGlvbhgDIAEoBVIJRGlyZWN0aW9uEhYKBklzbG9uZxgEIAEoBVIG'
    'SXNsb25nEhYKBklzRG16ahgFIAEoBVIGSXNEbXpqEhQKBUNvdmVyGAYgASgJUgVDb3ZlchIgCg'
    'tEZXNjcmlwdGlvbhgHIAEoCVILRGVzY3JpcHRpb24SJgoOTGFzdFVwZGF0ZXRpbWUYCCABKANS'
    'Dkxhc3RVcGRhdGV0aW1lEjQKFUxhc3RVcGRhdGVDaGFwdGVyTmFtZRgJIAEoCVIVTGFzdFVwZG'
    'F0ZUNoYXB0ZXJOYW1lEhwKCUNvcHlyaWdodBgKIAEoBVIJQ29weXJpZ2h0EiAKC0ZpcnN0TGV0'
    'dGVyGAsgASgJUgtGaXJzdExldHRlchIYCgdDb21pY1B5GAwgASgJUgdDb21pY1B5EhYKBkhpZG'
    'RlbhgNIAEoBVIGSGlkZGVuEhYKBkhvdE51bRgOIAEoBVIGSG90TnVtEhYKBkhpdE51bRgPIAEo'
    'BVIGSGl0TnVtEhAKA1VpZBgQIAEoBVIDVWlkEhYKBklzTG9jaxgRIAEoBVIGSXNMb2NrEjAKE0'
    'xhc3RVcGRhdGVDaGFwdGVySWQYEiABKAVSE0xhc3RVcGRhdGVDaGFwdGVySWQSPQoFVHlwZXMY'
    'EyADKAsyJy5kbXpqLmNvbWljLkNvbWljRGV0YWlsVHlwZUl0ZW1SZXNwb25zZVIFVHlwZXMSPw'
    'oGU3RhdHVzGBQgAygLMicuZG16ai5jb21pYy5Db21pY0RldGFpbFR5cGVJdGVtUmVzcG9uc2VS'
    'BlN0YXR1cxJBCgdBdXRob3JzGBUgAygLMicuZG16ai5jb21pYy5Db21pY0RldGFpbFR5cGVJdG'
    'VtUmVzcG9uc2VSB0F1dGhvcnMSIgoMU3Vic2NyaWJlTnVtGBYgASgFUgxTdWJzY3JpYmVOdW0S'
    'QgoIQ2hhcHRlcnMYFyADKAsyJi5kbXpqLmNvbWljLkNvbWljRGV0YWlsQ2hhcHRlclJlc3Bvbn'
    'NlUghDaGFwdGVycxIgCgtJc05lZWRMb2dpbhgYIAEoBVILSXNOZWVkTG9naW4SJAoNSXNIaWRl'
    'Q2hhcHRlchgaIAEoBVINSXNIaWRlQ2hhcHRlcg==');

@$core.Deprecated('Use comicDetailTypeItemResponseDescriptor instead')
const ComicDetailTypeItemResponse$json = {
  '1': 'ComicDetailTypeItemResponse',
  '2': [
    {'1': 'TagId', '3': 1, '4': 1, '5': 5, '10': 'TagId'},
    {'1': 'TagName', '3': 2, '4': 1, '5': 9, '10': 'TagName'},
  ],
};

/// Descriptor for `ComicDetailTypeItemResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List comicDetailTypeItemResponseDescriptor =
    $convert.base64Decode(
        'ChtDb21pY0RldGFpbFR5cGVJdGVtUmVzcG9uc2USFAoFVGFnSWQYASABKAVSBVRhZ0lkEhgKB1'
        'RhZ05hbWUYAiABKAlSB1RhZ05hbWU=');

@$core.Deprecated('Use comicDetailChapterResponseDescriptor instead')
const ComicDetailChapterResponse$json = {
  '1': 'ComicDetailChapterResponse',
  '2': [
    {'1': 'Title', '3': 1, '4': 1, '5': 9, '10': 'Title'},
    {
      '1': 'Data',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.dmzj.comic.ComicDetailChapterInfoResponse',
      '10': 'Data'
    },
  ],
};

/// Descriptor for `ComicDetailChapterResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List comicDetailChapterResponseDescriptor =
    $convert.base64Decode(
        'ChpDb21pY0RldGFpbENoYXB0ZXJSZXNwb25zZRIUCgVUaXRsZRgBIAEoCVIFVGl0bGUSPgoERG'
        'F0YRgCIAMoCzIqLmRtemouY29taWMuQ29taWNEZXRhaWxDaGFwdGVySW5mb1Jlc3BvbnNlUgRE'
        'YXRh');

@$core.Deprecated('Use comicDetailChapterInfoResponseDescriptor instead')
const ComicDetailChapterInfoResponse$json = {
  '1': 'ComicDetailChapterInfoResponse',
  '2': [
    {'1': 'ChapterId', '3': 1, '4': 1, '5': 5, '10': 'ChapterId'},
    {'1': 'ChapterTitle', '3': 2, '4': 1, '5': 9, '10': 'ChapterTitle'},
    {'1': 'Updatetime', '3': 3, '4': 1, '5': 3, '10': 'Updatetime'},
    {'1': 'Filesize', '3': 4, '4': 1, '5': 5, '10': 'Filesize'},
    {'1': 'ChapterOrder', '3': 5, '4': 1, '5': 5, '10': 'ChapterOrder'},
  ],
};

/// Descriptor for `ComicDetailChapterInfoResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List comicDetailChapterInfoResponseDescriptor =
    $convert.base64Decode(
        'Ch5Db21pY0RldGFpbENoYXB0ZXJJbmZvUmVzcG9uc2USHAoJQ2hhcHRlcklkGAEgASgFUglDaG'
        'FwdGVySWQSIgoMQ2hhcHRlclRpdGxlGAIgASgJUgxDaGFwdGVyVGl0bGUSHgoKVXBkYXRldGlt'
        'ZRgDIAEoA1IKVXBkYXRldGltZRIaCghGaWxlc2l6ZRgEIAEoBVIIRmlsZXNpemUSIgoMQ2hhcH'
        'Rlck9yZGVyGAUgASgFUgxDaGFwdGVyT3JkZXI=');

@$core.Deprecated('Use comicChapterDetailResponseDescriptor instead')
const ComicChapterDetailResponse$json = {
  '1': 'ComicChapterDetailResponse',
  '2': [
    {'1': 'Errno', '3': 1, '4': 1, '5': 5, '9': 0, '10': 'Errno', '17': true},
    {'1': 'Errmsg', '3': 2, '4': 1, '5': 9, '9': 1, '10': 'Errmsg', '17': true},
    {
      '1': 'Data',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.dmzj.comic.ComicChapterDetailInfoResponse',
      '10': 'Data'
    },
  ],
  '8': [
    {'1': '_Errno'},
    {'1': '_Errmsg'},
  ],
};

/// Descriptor for `ComicChapterDetailResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List comicChapterDetailResponseDescriptor = $convert.base64Decode(
    'ChpDb21pY0NoYXB0ZXJEZXRhaWxSZXNwb25zZRIZCgVFcnJubxgBIAEoBUgAUgVFcnJub4gBAR'
    'IbCgZFcnJtc2cYAiABKAlIAVIGRXJybXNniAEBEj4KBERhdGEYAyABKAsyKi5kbXpqLmNvbWlj'
    'LkNvbWljQ2hhcHRlckRldGFpbEluZm9SZXNwb25zZVIERGF0YUIICgZfRXJybm9CCQoHX0Vycm'
    '1zZw==');

@$core.Deprecated('Use comicChapterDetailInfoResponseDescriptor instead')
const ComicChapterDetailInfoResponse$json = {
  '1': 'ComicChapterDetailInfoResponse',
  '2': [
    {'1': 'ChapterId', '3': 1, '4': 1, '5': 5, '10': 'ChapterId'},
    {'1': 'ComicId', '3': 2, '4': 1, '5': 5, '10': 'ComicId'},
    {'1': 'Title', '3': 3, '4': 1, '5': 9, '10': 'Title'},
    {'1': 'Order', '3': 4, '4': 1, '5': 5, '10': 'Order'},
    {'1': 'Status', '3': 5, '4': 1, '5': 5, '10': 'Status'},
    {'1': 'SmallPages', '3': 6, '4': 3, '5': 9, '10': 'SmallPages'},
    {'1': 'Length', '3': 7, '4': 1, '5': 5, '10': 'Length'},
    {'1': 'RawPages', '3': 8, '4': 3, '5': 9, '10': 'RawPages'},
    {'1': 'FileSize', '3': 9, '4': 1, '5': 5, '10': 'FileSize'},
  ],
};

/// Descriptor for `ComicChapterDetailInfoResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List comicChapterDetailInfoResponseDescriptor = $convert.base64Decode(
    'Ch5Db21pY0NoYXB0ZXJEZXRhaWxJbmZvUmVzcG9uc2USHAoJQ2hhcHRlcklkGAEgASgFUglDaG'
    'FwdGVySWQSGAoHQ29taWNJZBgCIAEoBVIHQ29taWNJZBIUCgVUaXRsZRgDIAEoCVIFVGl0bGUS'
    'FAoFT3JkZXIYBCABKAVSBU9yZGVyEhYKBlN0YXR1cxgFIAEoBVIGU3RhdHVzEh4KClNtYWxsUG'
    'FnZXMYBiADKAlSClNtYWxsUGFnZXMSFgoGTGVuZ3RoGAcgASgFUgZMZW5ndGgSGgoIUmF3UGFn'
    'ZXMYCCADKAlSCFJhd1BhZ2VzEhoKCEZpbGVTaXplGAkgASgFUghGaWxlU2l6ZQ==');

@$core.Deprecated('Use comicUpdateListResponseDescriptor instead')
const ComicUpdateListResponse$json = {
  '1': 'ComicUpdateListResponse',
  '2': [
    {'1': 'Errno', '3': 1, '4': 1, '5': 5, '10': 'Errno'},
    {'1': 'Errmsg', '3': 2, '4': 1, '5': 9, '10': 'Errmsg'},
    {
      '1': 'Data',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.dmzj.comic.ComicUpdateListItemResponse',
      '10': 'Data'
    },
  ],
};

/// Descriptor for `ComicUpdateListResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List comicUpdateListResponseDescriptor = $convert.base64Decode(
    'ChdDb21pY1VwZGF0ZUxpc3RSZXNwb25zZRIUCgVFcnJubxgBIAEoBVIFRXJybm8SFgoGRXJybX'
    'NnGAIgASgJUgZFcnJtc2cSOwoERGF0YRgDIAMoCzInLmRtemouY29taWMuQ29taWNVcGRhdGVM'
    'aXN0SXRlbVJlc3BvbnNlUgREYXRh');

@$core.Deprecated('Use comicUpdateListItemResponseDescriptor instead')
const ComicUpdateListItemResponse$json = {
  '1': 'ComicUpdateListItemResponse',
  '2': [
    {'1': 'ComicId', '3': 1, '4': 1, '5': 5, '10': 'ComicId'},
    {'1': 'Title', '3': 2, '4': 1, '5': 9, '10': 'Title'},
    {'1': 'Islong', '3': 3, '4': 1, '5': 8, '10': 'Islong'},
    {'1': 'Authors', '3': 4, '4': 1, '5': 9, '10': 'Authors'},
    {'1': 'Types', '3': 5, '4': 1, '5': 9, '10': 'Types'},
    {'1': 'Cover', '3': 6, '4': 1, '5': 9, '10': 'Cover'},
    {'1': 'Status', '3': 7, '4': 1, '5': 9, '10': 'Status'},
    {
      '1': 'LastUpdateChapterName',
      '3': 8,
      '4': 1,
      '5': 9,
      '10': 'LastUpdateChapterName'
    },
    {
      '1': 'LastUpdateChapterId',
      '3': 9,
      '4': 1,
      '5': 5,
      '10': 'LastUpdateChapterId'
    },
    {'1': 'LastUpdatetime', '3': 10, '4': 1, '5': 3, '10': 'LastUpdatetime'},
  ],
};

/// Descriptor for `ComicUpdateListItemResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List comicUpdateListItemResponseDescriptor = $convert.base64Decode(
    'ChtDb21pY1VwZGF0ZUxpc3RJdGVtUmVzcG9uc2USGAoHQ29taWNJZBgBIAEoBVIHQ29taWNJZB'
    'IUCgVUaXRsZRgCIAEoCVIFVGl0bGUSFgoGSXNsb25nGAMgASgIUgZJc2xvbmcSGAoHQXV0aG9y'
    'cxgEIAEoCVIHQXV0aG9ycxIUCgVUeXBlcxgFIAEoCVIFVHlwZXMSFAoFQ292ZXIYBiABKAlSBU'
    'NvdmVyEhYKBlN0YXR1cxgHIAEoCVIGU3RhdHVzEjQKFUxhc3RVcGRhdGVDaGFwdGVyTmFtZRgI'
    'IAEoCVIVTGFzdFVwZGF0ZUNoYXB0ZXJOYW1lEjAKE0xhc3RVcGRhdGVDaGFwdGVySWQYCSABKA'
    'VSE0xhc3RVcGRhdGVDaGFwdGVySWQSJgoOTGFzdFVwZGF0ZXRpbWUYCiABKANSDkxhc3RVcGRh'
    'dGV0aW1l');

@$core.Deprecated('Use comicRankListResponseDescriptor instead')
const ComicRankListResponse$json = {
  '1': 'ComicRankListResponse',
  '2': [
    {'1': 'Errno', '3': 1, '4': 1, '5': 5, '10': 'Errno'},
    {'1': 'Errmsg', '3': 2, '4': 1, '5': 9, '10': 'Errmsg'},
    {
      '1': 'Data',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.dmzj.comic.ComicRankListItemResponse',
      '10': 'Data'
    },
  ],
};

/// Descriptor for `ComicRankListResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List comicRankListResponseDescriptor = $convert.base64Decode(
    'ChVDb21pY1JhbmtMaXN0UmVzcG9uc2USFAoFRXJybm8YASABKAVSBUVycm5vEhYKBkVycm1zZx'
    'gCIAEoCVIGRXJybXNnEjkKBERhdGEYAyADKAsyJS5kbXpqLmNvbWljLkNvbWljUmFua0xpc3RJ'
    'dGVtUmVzcG9uc2VSBERhdGE=');

@$core.Deprecated('Use comicRankListItemResponseDescriptor instead')
const ComicRankListItemResponse$json = {
  '1': 'ComicRankListItemResponse',
  '2': [
    {'1': 'ComicId', '3': 1, '4': 1, '5': 5, '10': 'ComicId'},
    {'1': 'Title', '3': 2, '4': 1, '5': 9, '10': 'Title'},
    {'1': 'Authors', '3': 3, '4': 1, '5': 9, '10': 'Authors'},
    {'1': 'Status', '3': 4, '4': 1, '5': 9, '10': 'Status'},
    {'1': 'Cover', '3': 5, '4': 1, '5': 9, '10': 'Cover'},
    {'1': 'Types', '3': 6, '4': 1, '5': 9, '10': 'Types'},
    {'1': 'LastUpdatetime', '3': 7, '4': 1, '5': 3, '10': 'LastUpdatetime'},
    {
      '1': 'LastUpdateChapterName',
      '3': 8,
      '4': 1,
      '5': 9,
      '10': 'LastUpdateChapterName'
    },
    {'1': 'ComicPy', '3': 9, '4': 1, '5': 9, '10': 'ComicPy'},
    {'1': 'Num', '3': 10, '4': 1, '5': 5, '10': 'Num'},
    {'1': 'TagId', '3': 11, '4': 1, '5': 5, '10': 'TagId'},
    {'1': 'ChapterName', '3': 12, '4': 1, '5': 9, '10': 'ChapterName'},
    {'1': 'ChapterId', '3': 13, '4': 1, '5': 5, '10': 'ChapterId'},
  ],
};

/// Descriptor for `ComicRankListItemResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List comicRankListItemResponseDescriptor = $convert.base64Decode(
    'ChlDb21pY1JhbmtMaXN0SXRlbVJlc3BvbnNlEhgKB0NvbWljSWQYASABKAVSB0NvbWljSWQSFA'
    'oFVGl0bGUYAiABKAlSBVRpdGxlEhgKB0F1dGhvcnMYAyABKAlSB0F1dGhvcnMSFgoGU3RhdHVz'
    'GAQgASgJUgZTdGF0dXMSFAoFQ292ZXIYBSABKAlSBUNvdmVyEhQKBVR5cGVzGAYgASgJUgVUeX'
    'BlcxImCg5MYXN0VXBkYXRldGltZRgHIAEoA1IOTGFzdFVwZGF0ZXRpbWUSNAoVTGFzdFVwZGF0'
    'ZUNoYXB0ZXJOYW1lGAggASgJUhVMYXN0VXBkYXRlQ2hhcHRlck5hbWUSGAoHQ29taWNQeRgJIA'
    'EoCVIHQ29taWNQeRIQCgNOdW0YCiABKAVSA051bRIUCgVUYWdJZBgLIAEoBVIFVGFnSWQSIAoL'
    'Q2hhcHRlck5hbWUYDCABKAlSC0NoYXB0ZXJOYW1lEhwKCUNoYXB0ZXJJZBgNIAEoBVIJQ2hhcH'
    'Rlcklk');

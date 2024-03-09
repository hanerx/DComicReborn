// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a zh locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'zh';

  static String m0(modes) => "${Intl.select(modes, {
            'release': '稳定版',
            'beta': '公测版',
            'develop': '开发版',
            'other': '未知',
          })}";

  static String m1(nickname) => "昵称: ${nickname}";

  static String m2(userId) => "UID: ${userId}";

  static String m3(username) => "用户名: ${username}";

  static String m4(uploadTime, chapterId) =>
      "上传时间: ${uploadTime} 章节ID: ${chapterId}";

  static String m5(Reason) => "登录失败: ${Reason}.";

  static String m8(modes) => "${Intl.select(modes, {
            'ranking': '热度',
            'latestUpdate': '更新',
            'other': '未知',
          })}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "AboutPageAbout": MessageLookupByLibrary.simpleMessage("关于"),
        "AboutPageAboutDialogueDescription":
            MessageLookupByLibrary.simpleMessage(
                "DComic 00Q[T]，使用了全新的Flutter3.0驱动的双核机"),
        "AboutPageAboutSubtitle":
            MessageLookupByLibrary.simpleMessage("关于 DComicReborn"),
        "AboutPageChangeLog": MessageLookupByLibrary.simpleMessage("修改日志"),
        "AboutPageChangeLogSubtitle":
            MessageLookupByLibrary.simpleMessage("各版本的修改日志"),
        "AboutPageCheckForUpdate": MessageLookupByLibrary.simpleMessage("检查更新"),
        "AboutPageGithub": MessageLookupByLibrary.simpleMessage("Github"),
        "AboutPageGithubUrl": MessageLookupByLibrary.simpleMessage(
            "https://github.com/hanerx/DComicReborn"),
        "AboutPageUpdateChannel": MessageLookupByLibrary.simpleMessage("更新渠道"),
        "AboutPageUpdateChannelModes": m0,
        "AboutSettings": MessageLookupByLibrary.simpleMessage("关于"),
        "AboutSettingsDescription":
            MessageLookupByLibrary.simpleMessage("关于 DComic"),
        "AccountManagePageSubtitleNickname": m1,
        "AccountManagePageSubtitleUID": m2,
        "AccountManagePageSubtitleUsername": m3,
        "AccountSettings": MessageLookupByLibrary.simpleMessage("账户设置"),
        "AccountSettingsDescription":
            MessageLookupByLibrary.simpleMessage("设置多账户漫画源"),
        "AppName": MessageLookupByLibrary.simpleMessage("DComic"),
        "ComicDetailPageAuthor": MessageLookupByLibrary.simpleMessage("作者: "),
        "ComicDetailPageBindComicId":
            MessageLookupByLibrary.simpleMessage("绑定漫画ID: "),
        "ComicDetailPageCategory": MessageLookupByLibrary.simpleMessage("分类: "),
        "ComicDetailPageChapterEntitySubtitle": m4,
        "ComicDetailPageComments": MessageLookupByLibrary.simpleMessage("评论"),
        "ComicDetailPageGridMode": MessageLookupByLibrary.simpleMessage("网格"),
        "ComicDetailPageListMode": MessageLookupByLibrary.simpleMessage("列表"),
        "ComicDetailPageOriginalComicId":
            MessageLookupByLibrary.simpleMessage("原始漫画ID: "),
        "ComicDetailPagePositiveMode":
            MessageLookupByLibrary.simpleMessage("正序"),
        "ComicDetailPageReverseMode":
            MessageLookupByLibrary.simpleMessage("倒序"),
        "ComicViewerPageComments": MessageLookupByLibrary.simpleMessage("评论"),
        "ComicViewerPageDirectory": MessageLookupByLibrary.simpleMessage("目录"),
        "CommonLoginLogin": MessageLookupByLibrary.simpleMessage("登录"),
        "CommonLoginLoginFailed": m5,
        "CommonLoginLogout": MessageLookupByLibrary.simpleMessage("登出"),
        "CopyMangaLoginPasswordHint":
            MessageLookupByLibrary.simpleMessage("你的拷贝漫画账号密码"),
        "CopyMangaLoginUsernameHint":
            MessageLookupByLibrary.simpleMessage("用户名"),
        "CopyMangaTitle": MessageLookupByLibrary.simpleMessage("拷贝漫画"),
        "DMZJLoginPassword": MessageLookupByLibrary.simpleMessage("密码"),
        "DMZJLoginPasswordHint":
            MessageLookupByLibrary.simpleMessage("你的大妈之家密码"),
        "DMZJLoginQQLogin": MessageLookupByLibrary.simpleMessage("QQ登录"),
        "DMZJLoginUsername": MessageLookupByLibrary.simpleMessage("用户名"),
        "DMZJLoginUsernameHint":
            MessageLookupByLibrary.simpleMessage("邮箱/用户名/手机号"),
        "DMZJTitle": MessageLookupByLibrary.simpleMessage("大妈之家"),
        "DatabaseDebugPageTitle":
            MessageLookupByLibrary.simpleMessage("本地数据库老巢"),
        "DebugPageNetworkCheck": MessageLookupByLibrary.simpleMessage("网络检查"),
        "DebugPageNetworkCheckDescription":
            MessageLookupByLibrary.simpleMessage("暂时没用"),
        "DebugPagePrintModelDatabase":
            MessageLookupByLibrary.simpleMessage("本地数据库解析"),
        "DebugPagePrintModelDatabaseDescription":
            MessageLookupByLibrary.simpleMessage(
                "尝试输出本地所有持久化数据（包括你的token，如果你不知道你在干啥就别点）"),
        "DebugPageTryCrash": MessageLookupByLibrary.simpleMessage("伪造崩溃日志"),
        "DebugPageTryCrashDescription":
            MessageLookupByLibrary.simpleMessage("向firebase传输一个伪造的崩溃日志"),
        "DebugSettings": MessageLookupByLibrary.simpleMessage("调试设置"),
        "DebugSettingsDescription":
            MessageLookupByLibrary.simpleMessage("作者的玩具箱，里面的东西大概率是坏的"),
        "DownloadSettings": MessageLookupByLibrary.simpleMessage("下载设置"),
        "DownloadSettingsDescription":
            MessageLookupByLibrary.simpleMessage("管理本地文件设置"),
        "DrawerDownloads": MessageLookupByLibrary.simpleMessage("下载"),
        "DrawerEmail": MessageLookupByLibrary.simpleMessage("DComic 00Q[T]"),
        "DrawerFavorite": MessageLookupByLibrary.simpleMessage("收藏"),
        "DrawerHistory": MessageLookupByLibrary.simpleMessage("历史"),
        "DrawerSetting": MessageLookupByLibrary.simpleMessage("设置"),
        "Empty": MessageLookupByLibrary.simpleMessage("这是一个没数据的空界面"),
        "ExperimentalSettings": MessageLookupByLibrary.simpleMessage(
            "刹那！DComic 00Q[T]还没整备好，记住别开三红！"),
        "ExperimentalSettingsDescription": MessageLookupByLibrary.simpleMessage(
            "了解，DComic 00Q[T] Trans-Arm, Quantum Burst!"),
        "ImageTypeNotSupport": MessageLookupByLibrary.simpleMessage("未知图片格式"),
        "JumpToLogin": MessageLookupByLibrary.simpleMessage("跳转至登录界面"),
        "Loading": MessageLookupByLibrary.simpleMessage("加载中..."),
        "LoginPageTitle": MessageLookupByLibrary.simpleMessage("登录"),
        "MainPageCategory": MessageLookupByLibrary.simpleMessage("分类"),
        "MainPageHome": MessageLookupByLibrary.simpleMessage("主页"),
        "MainPageLatest": MessageLookupByLibrary.simpleMessage("最近"),
        "MainPageRank": MessageLookupByLibrary.simpleMessage("排行"),
        "ReaderSettings": MessageLookupByLibrary.simpleMessage("阅读器设置"),
        "ReaderSettingsDescription":
            MessageLookupByLibrary.simpleMessage("漫画阅读器通用设置"),
        "RequireLogin": MessageLookupByLibrary.simpleMessage("本界面需要用户数据，请先登录"),
        "SourceSettings": MessageLookupByLibrary.simpleMessage("漫画源设置"),
        "SourceSettingsDescription":
            MessageLookupByLibrary.simpleMessage("管理漫画源"),
        "TimeOrRankFilterEntityModes": m8,
        "TimeOrRankFilterEntityName":
            MessageLookupByLibrary.simpleMessage("排序方式"),
        "UnknownScreen":
            MessageLookupByLibrary.simpleMessage("不支持的屏幕分辨率，提issue去")
      };
}

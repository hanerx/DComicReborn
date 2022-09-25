// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
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
  String get localeName => 'en';

  static String m0(modes) => "${Intl.select(modes, {
            'release': 'Release',
            'beta': 'Beta',
            'develop': 'Develop',
            'other': 'Unknown',
          })}";

  static String m1(nickname) => "Nickname: ${nickname}";

  static String m2(userId) => "UID: ${userId}";

  static String m3(username) => "Username: ${username}";

  static String m4(uploadTime, chapterId) =>
      "Upload Time: ${uploadTime} ChapterID: ${chapterId}";

  static String m5(modes) => "${Intl.select(modes, {
            'ranking': 'Ranking',
            'latestUpdate': 'Latest Update',
            'other': 'Unknown',
          })}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "AboutPageAbout": MessageLookupByLibrary.simpleMessage("About"),
        "AboutPageAboutDialogueDescription":
            MessageLookupByLibrary.simpleMessage(
                "DComic 00Q[T], reborn of the DComic."),
        "AboutPageAboutSubtitle":
            MessageLookupByLibrary.simpleMessage("About DComicReborn"),
        "AboutPageChangeLog":
            MessageLookupByLibrary.simpleMessage("Change Log"),
        "AboutPageChangeLogSubtitle":
            MessageLookupByLibrary.simpleMessage("Change Log For Each Version"),
        "AboutPageCheckForUpdate":
            MessageLookupByLibrary.simpleMessage("Check For Update"),
        "AboutPageGithub": MessageLookupByLibrary.simpleMessage("Github"),
        "AboutPageGithubUrl": MessageLookupByLibrary.simpleMessage(
            "https://github.com/hanerx/DComicReborn"),
        "AboutPageUpdateChannel":
            MessageLookupByLibrary.simpleMessage("Update Channel"),
        "AboutPageUpdateChannelModes": m0,
        "AboutSettings": MessageLookupByLibrary.simpleMessage("About"),
        "AboutSettingsDescription":
            MessageLookupByLibrary.simpleMessage("About DComic"),
        "AccountManagePageSubtitleNickname": m1,
        "AccountManagePageSubtitleUID": m2,
        "AccountManagePageSubtitleUsername": m3,
        "AccountSettings":
            MessageLookupByLibrary.simpleMessage("Account Settings"),
        "AccountSettingsDescription": MessageLookupByLibrary.simpleMessage(
            "Manage All Comic Source With Account"),
        "AppName": MessageLookupByLibrary.simpleMessage("DComic"),
        "ComicDetailPageAuthor":
            MessageLookupByLibrary.simpleMessage("Author: "),
        "ComicDetailPageBindComicId":
            MessageLookupByLibrary.simpleMessage("Bind ComicID: "),
        "ComicDetailPageCategory":
            MessageLookupByLibrary.simpleMessage("Category: "),
        "ComicDetailPageChapterEntitySubtitle": m4,
        "ComicDetailPageComments":
            MessageLookupByLibrary.simpleMessage("Comments"),
        "ComicDetailPageGridMode": MessageLookupByLibrary.simpleMessage("Grid"),
        "ComicDetailPageListMode": MessageLookupByLibrary.simpleMessage("List"),
        "ComicDetailPageOriginalComicId":
            MessageLookupByLibrary.simpleMessage("Origin ComicID: "),
        "ComicDetailPagePositiveMode":
            MessageLookupByLibrary.simpleMessage("Positive"),
        "ComicDetailPageReverseMode":
            MessageLookupByLibrary.simpleMessage("Reverse"),
        "ComicViewerPageComments":
            MessageLookupByLibrary.simpleMessage("Comments"),
        "ComicViewerPageDirectory":
            MessageLookupByLibrary.simpleMessage("Directory"),
        "DebugPageNetworkCheck":
            MessageLookupByLibrary.simpleMessage("Network Check"),
        "DebugPageNetworkCheckDescription": MessageLookupByLibrary.simpleMessage(
            "Just check network by ping baidu.com, maybe change to more useful page in future."),
        "DebugPageTryCrash": MessageLookupByLibrary.simpleMessage("Try Crash"),
        "DebugPageTryCrashDescription": MessageLookupByLibrary.simpleMessage(
            "Try call a crash to test firebase collection method."),
        "DebugSettings": MessageLookupByLibrary.simpleMessage("Debug Settings"),
        "DebugSettingsDescription": MessageLookupByLibrary.simpleMessage(
            "Debug Settings (Some may not work)"),
        "DownloadSettings":
            MessageLookupByLibrary.simpleMessage("Download Settings"),
        "DownloadSettingsDescription":
            MessageLookupByLibrary.simpleMessage("Manage Local File Settings"),
        "DrawerDownloads": MessageLookupByLibrary.simpleMessage("Downloads"),
        "DrawerEmail": MessageLookupByLibrary.simpleMessage("DComic 00Q[T]"),
        "DrawerFavorite": MessageLookupByLibrary.simpleMessage("Favorite"),
        "DrawerHistory": MessageLookupByLibrary.simpleMessage("History"),
        "DrawerSetting": MessageLookupByLibrary.simpleMessage("Setting"),
        "Empty": MessageLookupByLibrary.simpleMessage("No more Information"),
        "ExperimentalSettings":
            MessageLookupByLibrary.simpleMessage("Experimental Settings"),
        "ExperimentalSettingsDescription": MessageLookupByLibrary.simpleMessage(
            "DComic 00Q[T] Trans-Arm, Quantum Burst!"),
        "ImageTypeNotSupport":
            MessageLookupByLibrary.simpleMessage("Unknown Image Type"),
        "JumpToLogin":
            MessageLookupByLibrary.simpleMessage("Jump To Login Page"),
        "Loading": MessageLookupByLibrary.simpleMessage("Loading..."),
        "MainPageCategory": MessageLookupByLibrary.simpleMessage("Category"),
        "MainPageHome": MessageLookupByLibrary.simpleMessage("Home"),
        "MainPageLatest": MessageLookupByLibrary.simpleMessage("Latest"),
        "MainPageRank": MessageLookupByLibrary.simpleMessage("Rank"),
        "ReaderSettings":
            MessageLookupByLibrary.simpleMessage("Reader Settings"),
        "ReaderSettingsDescription":
            MessageLookupByLibrary.simpleMessage("Settings About Comic Reader"),
        "RequireLogin": MessageLookupByLibrary.simpleMessage(
            "This Page Needs User Info, Please Login"),
        "SourceSettings":
            MessageLookupByLibrary.simpleMessage("Source Settings"),
        "SourceSettingsDescription":
            MessageLookupByLibrary.simpleMessage("Manage Comic Source"),
        "TimeOrRankFilterEntityModes": m5,
        "TimeOrRankFilterEntityName":
            MessageLookupByLibrary.simpleMessage("SortType"),
        "UnknownScreen": MessageLookupByLibrary.simpleMessage(
            "Your Screen Size is not support, please connect author.")
      };
}

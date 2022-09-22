// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(_current != null,
        'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.');
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(instance != null,
        'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?');
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `DComic`
  String get AppName {
    return Intl.message(
      'DComic',
      name: 'AppName',
      desc: '',
      args: [],
    );
  }

  /// `DComic 00Q[T]`
  String get DrawerEmail {
    return Intl.message(
      'DComic 00Q[T]',
      name: 'DrawerEmail',
      desc: '',
      args: [],
    );
  }

  /// `Your Screen Size is not support, please connect author.`
  String get UnknownScreen {
    return Intl.message(
      'Your Screen Size is not support, please connect author.',
      name: 'UnknownScreen',
      desc: '',
      args: [],
    );
  }

  /// `Home`
  String get MainPageHome {
    return Intl.message(
      'Home',
      name: 'MainPageHome',
      desc: '',
      args: [],
    );
  }

  /// `Category`
  String get MainPageCategory {
    return Intl.message(
      'Category',
      name: 'MainPageCategory',
      desc: '',
      args: [],
    );
  }

  /// `Rank`
  String get MainPageRank {
    return Intl.message(
      'Rank',
      name: 'MainPageRank',
      desc: '',
      args: [],
    );
  }

  /// `Latest`
  String get MainPageLatest {
    return Intl.message(
      'Latest',
      name: 'MainPageLatest',
      desc: '',
      args: [],
    );
  }

  /// `Unknown Image Type`
  String get ImageTypeNotSupport {
    return Intl.message(
      'Unknown Image Type',
      name: 'ImageTypeNotSupport',
      desc: '',
      args: [],
    );
  }

  /// `Loading...`
  String get Loading {
    return Intl.message(
      'Loading...',
      name: 'Loading',
      desc: '',
      args: [],
    );
  }

  /// `No more Information`
  String get Empty {
    return Intl.message(
      'No more Information',
      name: 'Empty',
      desc: '',
      args: [],
    );
  }

  /// `This Page Needs User Info, Please Login`
  String get RequireLogin {
    return Intl.message(
      'This Page Needs User Info, Please Login',
      name: 'RequireLogin',
      desc: '',
      args: [],
    );
  }

  /// `Jump To Login Page`
  String get JumpToLogin {
    return Intl.message(
      'Jump To Login Page',
      name: 'JumpToLogin',
      desc: '',
      args: [],
    );
  }

  /// `Favorite`
  String get DrawerFavorite {
    return Intl.message(
      'Favorite',
      name: 'DrawerFavorite',
      desc: '',
      args: [],
    );
  }

  /// `History`
  String get DrawerHistory {
    return Intl.message(
      'History',
      name: 'DrawerHistory',
      desc: '',
      args: [],
    );
  }

  /// `Downloads`
  String get DrawerDownloads {
    return Intl.message(
      'Downloads',
      name: 'DrawerDownloads',
      desc: '',
      args: [],
    );
  }

  /// `Setting`
  String get DrawerSetting {
    return Intl.message(
      'Setting',
      name: 'DrawerSetting',
      desc: '',
      args: [],
    );
  }

  /// `Reader Settings`
  String get ReaderSettings {
    return Intl.message(
      'Reader Settings',
      name: 'ReaderSettings',
      desc: '',
      args: [],
    );
  }

  /// `Settings About Comic Reader`
  String get ReaderSettingsDescription {
    return Intl.message(
      'Settings About Comic Reader',
      name: 'ReaderSettingsDescription',
      desc: '',
      args: [],
    );
  }

  /// `Source Settings`
  String get SourceSettings {
    return Intl.message(
      'Source Settings',
      name: 'SourceSettings',
      desc: '',
      args: [],
    );
  }

  /// `Manage Comic Source`
  String get SourceSettingsDescription {
    return Intl.message(
      'Manage Comic Source',
      name: 'SourceSettingsDescription',
      desc: '',
      args: [],
    );
  }

  /// `Account Settings`
  String get AccountSettings {
    return Intl.message(
      'Account Settings',
      name: 'AccountSettings',
      desc: '',
      args: [],
    );
  }

  /// `Manage All Comic Source With Account`
  String get AccountSettingsDescription {
    return Intl.message(
      'Manage All Comic Source With Account',
      name: 'AccountSettingsDescription',
      desc: '',
      args: [],
    );
  }

  /// `About`
  String get AboutSettings {
    return Intl.message(
      'About',
      name: 'AboutSettings',
      desc: '',
      args: [],
    );
  }

  /// `About DComic`
  String get AboutSettingsDescription {
    return Intl.message(
      'About DComic',
      name: 'AboutSettingsDescription',
      desc: '',
      args: [],
    );
  }

  /// `Download Settings`
  String get DownloadSettings {
    return Intl.message(
      'Download Settings',
      name: 'DownloadSettings',
      desc: '',
      args: [],
    );
  }

  /// `Manage Local File Settings`
  String get DownloadSettingsDescription {
    return Intl.message(
      'Manage Local File Settings',
      name: 'DownloadSettingsDescription',
      desc: '',
      args: [],
    );
  }

  /// `Debug Settings`
  String get DebugSettings {
    return Intl.message(
      'Debug Settings',
      name: 'DebugSettings',
      desc: '',
      args: [],
    );
  }

  /// `Debug Settings (Some may not work)`
  String get DebugSettingsDescription {
    return Intl.message(
      'Debug Settings (Some may not work)',
      name: 'DebugSettingsDescription',
      desc: '',
      args: [],
    );
  }

  /// `Experimental Settings`
  String get ExperimentalSettings {
    return Intl.message(
      'Experimental Settings',
      name: 'ExperimentalSettings',
      desc: '',
      args: [],
    );
  }

  /// `DComic 00Q[T] Trans-Arm, Quantum Burst!`
  String get ExperimentalSettingsDescription {
    return Intl.message(
      'DComic 00Q[T] Trans-Arm, Quantum Burst!',
      name: 'ExperimentalSettingsDescription',
      desc: '',
      args: [],
    );
  }

  /// `Network Check`
  String get DebugPageNetworkCheck {
    return Intl.message(
      'Network Check',
      name: 'DebugPageNetworkCheck',
      desc: '',
      args: [],
    );
  }

  /// `Just check network by ping baidu.com, maybe change to more useful page in future.`
  String get DebugPageNetworkCheckDescription {
    return Intl.message(
      'Just check network by ping baidu.com, maybe change to more useful page in future.',
      name: 'DebugPageNetworkCheckDescription',
      desc: '',
      args: [],
    );
  }

  /// `Check For Update`
  String get AboutPageCheckForUpdate {
    return Intl.message(
      'Check For Update',
      name: 'AboutPageCheckForUpdate',
      desc: '',
      args: [],
    );
  }

  /// `Update Channel`
  String get AboutPageUpdateChannel {
    return Intl.message(
      'Update Channel',
      name: 'AboutPageUpdateChannel',
      desc: '',
      args: [],
    );
  }

  /// `{modes, select, release{Release} beta{Beta} develop{Develop} other{Unknown}}`
  String AboutPageUpdateChannelModes(Object modes) {
    return Intl.select(
      modes,
      {
        'release': 'Release',
        'beta': 'Beta',
        'develop': 'Develop',
        'other': 'Unknown',
      },
      name: 'AboutPageUpdateChannelModes',
      desc: '',
      args: [modes],
    );
  }

  /// `Github`
  String get AboutPageGithub {
    return Intl.message(
      'Github',
      name: 'AboutPageGithub',
      desc: '',
      args: [],
    );
  }

  /// `https://github.com/hanerx/DComicReborn`
  String get AboutPageGithubUrl {
    return Intl.message(
      'https://github.com/hanerx/DComicReborn',
      name: 'AboutPageGithubUrl',
      desc: '',
      args: [],
    );
  }

  /// `Change Log`
  String get AboutPageChangeLog {
    return Intl.message(
      'Change Log',
      name: 'AboutPageChangeLog',
      desc: '',
      args: [],
    );
  }

  /// `Change Log For Each Version`
  String get AboutPageChangeLogSubtitle {
    return Intl.message(
      'Change Log For Each Version',
      name: 'AboutPageChangeLogSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `About`
  String get AboutPageAbout {
    return Intl.message(
      'About',
      name: 'AboutPageAbout',
      desc: '',
      args: [],
    );
  }

  /// `About DComicReborn`
  String get AboutPageAboutSubtitle {
    return Intl.message(
      'About DComicReborn',
      name: 'AboutPageAboutSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `DComic 00Q[T], reborn of the DComic.`
  String get AboutPageAboutDialogueDescription {
    return Intl.message(
      'DComic 00Q[T], reborn of the DComic.',
      name: 'AboutPageAboutDialogueDescription',
      desc: '',
      args: [],
    );
  }

  /// `Author: `
  String get ComicDetailPageAuthor {
    return Intl.message(
      'Author: ',
      name: 'ComicDetailPageAuthor',
      desc: '',
      args: [],
    );
  }

  /// `Category: `
  String get ComicDetailPageCategory {
    return Intl.message(
      'Category: ',
      name: 'ComicDetailPageCategory',
      desc: '',
      args: [],
    );
  }

  /// `Origin ComicID: `
  String get ComicDetailPageOriginalComicId {
    return Intl.message(
      'Origin ComicID: ',
      name: 'ComicDetailPageOriginalComicId',
      desc: '',
      args: [],
    );
  }

  /// `Bind ComicID: `
  String get ComicDetailPageBindComicId {
    return Intl.message(
      'Bind ComicID: ',
      name: 'ComicDetailPageBindComicId',
      desc: '',
      args: [],
    );
  }

  /// `Grid`
  String get ComicDetailPageGridMode {
    return Intl.message(
      'Grid',
      name: 'ComicDetailPageGridMode',
      desc: '',
      args: [],
    );
  }

  /// `List`
  String get ComicDetailPageListMode {
    return Intl.message(
      'List',
      name: 'ComicDetailPageListMode',
      desc: '',
      args: [],
    );
  }

  /// `Upload Time: {uploadTime} ChapterID: {chapterId}`
  String ComicDetailPageChapterEntitySubtitle(
      Object uploadTime, Object chapterId) {
    return Intl.message(
      'Upload Time: $uploadTime ChapterID: $chapterId',
      name: 'ComicDetailPageChapterEntitySubtitle',
      desc: '',
      args: [uploadTime, chapterId],
    );
  }

  /// `Positive`
  String get ComicDetailPagePositiveMode {
    return Intl.message(
      'Positive',
      name: 'ComicDetailPagePositiveMode',
      desc: '',
      args: [],
    );
  }

  /// `Reverse`
  String get ComicDetailPageReverseMode {
    return Intl.message(
      'Reverse',
      name: 'ComicDetailPageReverseMode',
      desc: '',
      args: [],
    );
  }

  /// `Nickname: {nickname}`
  String AccountManagePageSubtitleNickname(Object nickname) {
    return Intl.message(
      'Nickname: $nickname',
      name: 'AccountManagePageSubtitleNickname',
      desc: '',
      args: [nickname],
    );
  }

  /// `UID: {userId}`
  String AccountManagePageSubtitleUID(Object userId) {
    return Intl.message(
      'UID: $userId',
      name: 'AccountManagePageSubtitleUID',
      desc: '',
      args: [userId],
    );
  }

  /// `Username: {username}`
  String AccountManagePageSubtitleUsername(Object username) {
    return Intl.message(
      'Username: $username',
      name: 'AccountManagePageSubtitleUsername',
      desc: '',
      args: [username],
    );
  }

  /// `Comments`
  String get ComicViewerPageComments {
    return Intl.message(
      'Comments',
      name: 'ComicViewerPageComments',
      desc: '',
      args: [],
    );
  }

  /// `Directory`
  String get ComicViewerPageDirectory {
    return Intl.message(
      'Directory',
      name: 'ComicViewerPageDirectory',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}

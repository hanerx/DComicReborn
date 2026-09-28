import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/providers/comic_reading_progress.dart';
import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/subscribe_badge_state.dart';
import 'package:dcomic/utils/reader_image_fit.dart';
import 'package:dcomic/utils/reader_info_settings.dart';
import 'package:dcomic/utils/theme_utils.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

enum ReadDirectionType { left, right, vertical }

enum ReaderEndAction { nextChapter, comments }

class ConfigProvider extends BaseProvider {
  ConfigEntity? _themeMode;
  ConfigEntity? _readDirection;
  bool _drawDebugWidget = false;
  ConfigEntity? _horizontalClickAreaPercent;
  ConfigEntity? _verticalClickAreaPercent;
  ConfigEntity? _themeColor;
  ConfigEntity? _useMaterial3Design;
  ConfigEntity? _readerTheme;
  ConfigEntity? _aggregateSubscribeBadges;
  ConfigEntity? _aggregateReadingProgress;
  ConfigEntity? _resumeLastReadPage;
  ConfigEntity? _advancedSettingsUnlocked;
  ConfigEntity? _autoMapMissingComics;
  ConfigEntity? _autoMapIntervalSeconds;
  ConfigEntity? _autoMapRetryEveryLaunch;
  ConfigEntity? _autoMapMaxAttempts;
  ConfigEntity? _readerPrecacheCount;
  ConfigEntity? _readerEndAction;
  ConfigEntity? _horizontalImageFit;
  ConfigEntity? _verticalImageFit;
  ConfigEntity? _readerInfoEnabled;
  ConfigEntity? _readerInfoPosition;
  ConfigEntity? _readerBatteryFormat;
  ConfigEntity? _readerPageFormat;
  ConfigEntity? _readerInfoChapter;
  ConfigEntity? _readerInfoTime;

  @override
  Future<void> init() async {
    final database = await DatabaseInstance.instance;
    final settings = <String, ConfigEntity>{};
    for (final setting in await database.configDao.getAllConfig()) {
      settings.putIfAbsent(setting.key, () => setting);
    }
    // Old settings did not store a viewport. Use a fixed phone reference so
    // the former 80/150 defaults both become 20%, consistently across devices.
    Future<void> migrateTapArea(
      String oldKey,
      String newKey,
      double referenceExtent,
    ) async {
      final legacy = settings[oldKey];
      if (legacy == null) return;
      await (database.database as sqflite.Database).transaction((transaction) async {
        final existing = await transaction.query(
          'ConfigEntity', where: 'key = ?', whereArgs: [newKey], limit: 1,
        );
        if (existing.isEmpty) {
          final pixels = double.tryParse(legacy.value ?? '');
          final percent = pixels != null && pixels.isFinite
              ? (pixels / referenceExtent * 100).clamp(5.0, 40.0)
              : 20.0;
          await transaction.insert('ConfigEntity', {
            'key': newKey,
            'value': percent.toString(),
          });
        }
        await transaction.delete(
          'ConfigEntity', where: 'key = ?', whereArgs: [oldKey],
        );
      });
      settings[newKey] = (await database.configDao.getConfigByKey(newKey))!;
      settings.remove(oldKey);
    }

    await migrateTapArea('HorizontalClickAreaSize', 'HorizontalClickAreaPercent', 400);
    await migrateTapArea('VerticalClickAreaSize', 'VerticalClickAreaPercent', 750);
    ConfigEntity read(String key, dynamic fallback) =>
        settings[key] ?? ConfigEntity.createConfigEntity(key, fallback);

    // Defaults remain in memory: refreshing a remote deletion must not
    // recreate the row and publish it as a new local modification.
    _themeMode = read('ThemeMode', ThemeMode.system);
    _readDirection = read('ReadDirection', ReadDirectionType.left);
    _horizontalClickAreaPercent = read('HorizontalClickAreaPercent', 20.0);
    _verticalClickAreaPercent = read('VerticalClickAreaPercent', 20.0);
    _themeColor = read('ThemeColor', 'Blue');
    _useMaterial3Design = read('UseMaterial3Design', true);
    _readerTheme = read('ReaderTheme', ReaderTheme.app.name);
    _aggregateSubscribeBadges = read(SubscribeBadgeState.configKey, false);
    _aggregateReadingProgress = read(ComicReadingProgress.configKey, false);
    _resumeLastReadPage = read('ResumeLastReadPage', false);
    // Retain the persisted key for already-unlocked installations.
    _advancedSettingsUnlocked = read('ExperimentalFeaturesUnlocked', false);
    _autoMapMissingComics = read('AutoMapMissingComics', false);
    _autoMapIntervalSeconds = read('AutoMapIntervalSeconds', 1);
    _autoMapRetryEveryLaunch = read('AutoMapRetryEveryLaunch', true);
    _autoMapMaxAttempts = read('AutoMapMaxAttempts', 3);
    _readerPrecacheCount = read('ReaderPrecacheCount', 3);
    _readerEndAction = read('ReaderEndAction', ReaderEndAction.comments.name);
    _horizontalImageFit = read(
      'HorizontalImageFit',
      ReaderImageFit.original.name,
    );
    _verticalImageFit = read('VerticalImageFit', ReaderImageFit.original.name);
    _readerInfoEnabled = read('ReaderInfoEnabled', false);
    _readerInfoPosition = read(
      'ReaderInfoPosition',
      ReaderInfoPosition.bottomRight.name,
    );
    _readerBatteryFormat = read(
      'ReaderBatteryFormat',
      ReaderBatteryFormat.iconAndNumber.name,
    );
    _readerPageFormat = read(
      'ReaderPageFormat',
      ReaderPageFormat.currentAndTotal.name,
    );
    _readerInfoChapter = read('ReaderInfoChapter', true);
    _readerInfoTime = read('ReaderInfoTime', true);
    notifyListeners();
  }

  void _persistSetting(ConfigEntity setting) {
    final key = setting.key;
    final value = setting.value;
    DatabaseInstance.instance.then(
      (database) => database.configDao.setConfigByKey(key, value),
    );
  }

  ThemeMode get themeMode {
    if (_themeMode == null) {
      return ThemeMode.system;
    }
    return ThemeMode.values[(_themeMode?.get<int>()) as int];
  }

  set themeMode(ThemeMode? value) {
    if (_themeMode != null && value != null) {
      _themeMode?.set(value);
      _persistSetting(_themeMode!);
    }
    notifyListeners();
  }

  ReadDirectionType get readDirection {
    if (_readDirection == null) {
      return ReadDirectionType.left;
    }
    return ReadDirectionType.values[(_readDirection?.get<int>()) as int];
  }

  set readDirection(ReadDirectionType value) {
    if (_readDirection != null) {
      _readDirection?.set(value);
      _persistSetting(_readDirection!);
    }
    notifyListeners();
  }

  ReaderTheme get readerTheme {
    final name = _readerTheme?.get<String>();
    return ReaderTheme.values.firstWhere(
      (theme) => theme.name == name,
      orElse: () => ReaderTheme.app,
    );
  }

  set readerTheme(ReaderTheme value) {
    if (_readerTheme != null) {
      _readerTheme!.set(value.name);
      _persistSetting(_readerTheme!);
    }
    notifyListeners();
  }

  ReaderEndAction get readerEndAction {
    final name = _readerEndAction?.get<String>();
    return ReaderEndAction.values.firstWhere(
      (action) => action.name == name,
      orElse: () => ReaderEndAction.comments,
    );
  }

  set readerEndAction(ReaderEndAction value) {
    if (_readerEndAction != null) {
      _readerEndAction!.set(value.name);
      _persistSetting(_readerEndAction!);
    }
    notifyListeners();
  }

  ReaderImageFit get horizontalImageFit =>
      _imageFit(_horizontalImageFit, vertical: false);

  set horizontalImageFit(ReaderImageFit value) {
    final fit = value == ReaderImageFit.fitWidth
        ? ReaderImageFit.original
        : value;
    if (_horizontalImageFit != null) {
      _horizontalImageFit!.set(fit.name);
      _persistSetting(_horizontalImageFit!);
    }
    notifyListeners();
  }

  ReaderImageFit get verticalImageFit =>
      _imageFit(_verticalImageFit, vertical: true);

  set verticalImageFit(ReaderImageFit value) {
    final fit = value == ReaderImageFit.fitHeight
        ? ReaderImageFit.original
        : value;
    if (_verticalImageFit != null) {
      _verticalImageFit!.set(fit.name);
      _persistSetting(_verticalImageFit!);
    }
    notifyListeners();
  }

  ReaderImageFit _imageFit(ConfigEntity? setting, {required bool vertical}) {
    final fit = switch (setting?.get<String>()) {
      'actualSize' => ReaderImageFit.actualSize,
      'contain' => ReaderImageFit.contain,
      'cover' => ReaderImageFit.cover,
      'stretch' => ReaderImageFit.stretch,
      'fitWidth' => ReaderImageFit.fitWidth,
      'fitHeight' => ReaderImageFit.fitHeight,
      _ => ReaderImageFit.original,
    };
    if (vertical && fit == ReaderImageFit.fitHeight ||
        !vertical && fit == ReaderImageFit.fitWidth) {
      return ReaderImageFit.original;
    }
    return fit;
  }

  bool get readerInfoEnabled => _readerInfoEnabled?.get<bool>() == true;

  set readerInfoEnabled(bool value) {
    if (_readerInfoEnabled != null) {
      _readerInfoEnabled!.set(value);
      _persistSetting(_readerInfoEnabled!);
    }
    notifyListeners();
  }

  ReaderInfoPosition get readerInfoPosition {
    final name = _readerInfoPosition?.get<String>();
    return ReaderInfoPosition.values.firstWhere(
      (position) => position.name == name,
      orElse: () => ReaderInfoPosition.bottomRight,
    );
  }

  set readerInfoPosition(ReaderInfoPosition value) {
    if (_readerInfoPosition != null) {
      _readerInfoPosition!.set(value.name);
      _persistSetting(_readerInfoPosition!);
    }
    notifyListeners();
  }

  ReaderBatteryFormat get readerBatteryFormat {
    final name = _readerBatteryFormat?.get<String>();
    return ReaderBatteryFormat.values.firstWhere(
      (format) => format.name == name,
      orElse: () => ReaderBatteryFormat.iconAndNumber,
    );
  }

  set readerBatteryFormat(ReaderBatteryFormat value) {
    if (_readerBatteryFormat != null) {
      _readerBatteryFormat!.set(value.name);
      _persistSetting(_readerBatteryFormat!);
    }
    notifyListeners();
  }

  ReaderPageFormat get readerPageFormat {
    final name = _readerPageFormat?.get<String>();
    return ReaderPageFormat.values.firstWhere(
      (format) => format.name == name,
      orElse: () => ReaderPageFormat.currentAndTotal,
    );
  }

  set readerPageFormat(ReaderPageFormat value) {
    if (_readerPageFormat != null) {
      _readerPageFormat!.set(value.name);
      _persistSetting(_readerPageFormat!);
    }
    notifyListeners();
  }

  bool get readerInfoChapter => _readerInfoChapter?.get<bool>() != false;

  set readerInfoChapter(bool value) {
    if (_readerInfoChapter != null) {
      _readerInfoChapter!.set(value);
      _persistSetting(_readerInfoChapter!);
    }
    notifyListeners();
  }

  bool get readerInfoTime => _readerInfoTime?.get<bool>() != false;

  set readerInfoTime(bool value) {
    if (_readerInfoTime != null) {
      _readerInfoTime!.set(value);
      _persistSetting(_readerInfoTime!);
    }
    notifyListeners();
  }

  int get readerPrecacheCount {
    final value = _readerPrecacheCount?.get<int>() as int?;
    if (value == null || value < 0 || value > 9) {
      return 3;
    }
    return value;
  }

  Future<void> setReaderPrecacheCount(int value) async {
    if (value < 0 || value > 9) {
      throw RangeError.range(value, 0, 9, 'value');
    }
    if (_readerPrecacheCount?.get<int>() == value) return;
    final database = await DatabaseInstance.instance;
    final setting = await database.configDao.getOrCreateConfigByKey(
      'ReaderPrecacheCount',
      value: 3,
    );
    setting.set(value);
    await database.configDao.updateConfig(setting);
    _readerPrecacheCount = setting;
    notifyListeners();
  }

  bool get drawDebugWidget => _drawDebugWidget;

  set drawDebugWidget(bool debug) {
    _drawDebugWidget = debug;
    notifyListeners();
  }

  double _tapAreaPercent(ConfigEntity? setting) {
    final value = double.tryParse(setting?.value ?? '');
    return value != null && value.isFinite && value >= 5 && value <= 40
        ? value
        : 20;
  }

  double get horizontalClickAreaPercent =>
      _tapAreaPercent(_horizontalClickAreaPercent);

  set horizontalClickAreaPercent(double value) {
    if (!value.isFinite || value < 5 || value > 40) {
      throw ArgumentError.value(value, 'value', 'Expected 5–40% per side');
    }
    if (_horizontalClickAreaPercent != null) {
      _horizontalClickAreaPercent?.set(value);
      _persistSetting(_horizontalClickAreaPercent!);
    }
    notifyListeners();
  }

  double get verticalClickAreaPercent =>
      _tapAreaPercent(_verticalClickAreaPercent);

  set verticalClickAreaPercent(double value) {
    if (!value.isFinite || value < 5 || value > 40) {
      throw ArgumentError.value(value, 'value', 'Expected 5–40% per side');
    }
    if (_verticalClickAreaPercent != null) {
      _verticalClickAreaPercent?.set(value);
      _persistSetting(_verticalClickAreaPercent!);
    }
    notifyListeners();
  }

  ThemeModel get themeColor {
    if (_themeColor == null) {
      return ThemeModel.themes['Blue']!;
    }
    return ThemeModel.themes[_themeColor?.get<String>()]!;
  }

  set themeColor(ThemeModel value) {
    if (_themeColor != null) {
      _themeColor?.set(value.name);
      _persistSetting(_themeColor!);
    }
    notifyListeners();
  }

  bool get useMaterial3Design {
    if (_useMaterial3Design == null) {
      return true;
    }
    return _useMaterial3Design?.get<bool>();
  }

  set useMaterial3Design(bool value) {
    if (_useMaterial3Design != null) {
      _useMaterial3Design?.set(value);
      _persistSetting(_useMaterial3Design!);
    }
    notifyListeners();
  }

  bool get aggregateSubscribeBadges =>
      _aggregateSubscribeBadges?.get<bool>() == true;

  Future<void> setAggregateSubscribeBadges(bool value) async {
    final database = await DatabaseInstance.instance;
    final setting = await database.configDao.getOrCreateConfigByKey(
      SubscribeBadgeState.configKey,
      value: false,
    );
    setting.set(value);
    await database.configDao.updateConfig(setting);
    _aggregateSubscribeBadges = setting;
    notifyListeners();
    SubscribeBadgeState.changes.value++;
  }

  bool get aggregateReadingProgress =>
      _aggregateReadingProgress?.get<bool>() == true;

  Future<void> setAggregateReadingProgress(bool value) async {
    final database = await DatabaseInstance.instance;
    final setting = await database.configDao.getOrCreateConfigByKey(
      ComicReadingProgress.configKey,
      value: false,
    );
    setting.set(value);
    await database.configDao.updateConfig(setting);
    _aggregateReadingProgress = setting;
    notifyListeners();
    ComicReadingProgress.changes.value++;
  }

  bool get resumeLastReadPage => _resumeLastReadPage?.get<bool>() == true;

  Future<void> setResumeLastReadPage(bool value) async {
    if (resumeLastReadPage == value) return;
    final database = await DatabaseInstance.instance;
    final setting = await database.configDao.getOrCreateConfigByKey(
      'ResumeLastReadPage',
      value: false,
    );
    setting.set(value);
    await database.configDao.updateConfig(setting);
    _resumeLastReadPage = setting;
    notifyListeners();
  }

  bool get advancedSettingsUnlocked =>
      _advancedSettingsUnlocked?.get<bool>() == true;

  Future<void> setAdvancedSettingsUnlocked(bool value) async {
    if (advancedSettingsUnlocked == value) return;
    final database = await DatabaseInstance.instance;
    final setting = await database.configDao.getOrCreateConfigByKey(
      'ExperimentalFeaturesUnlocked',
      value: false,
    );
    setting.set(value);
    await database.configDao.updateConfig(setting);
    _advancedSettingsUnlocked = setting;
    notifyListeners();
  }

  bool get autoMapMissingComics => _autoMapMissingComics?.get<bool>() == true;

  Future<void> setAutoMapMissingComics(bool value) async {
    if (autoMapMissingComics == value) return;
    final database = await DatabaseInstance.instance;
    final setting = await database.configDao.getOrCreateConfigByKey(
      'AutoMapMissingComics',
      value: false,
    );
    setting.set(value);
    await database.configDao.updateConfig(setting);
    _autoMapMissingComics = setting;
    notifyListeners();
  }

  int get autoMapIntervalSeconds {
    final value = _autoMapIntervalSeconds?.get<int>() as int?;
    if (value == null || value < 1) {
      return 1;
    }
    return value;
  }

  Future<void> setAutoMapIntervalSeconds(int value) async {
    final clamped = value < 1 ? 1 : value;
    if (autoMapIntervalSeconds == clamped) return;
    final database = await DatabaseInstance.instance;
    final setting = await database.configDao.getOrCreateConfigByKey(
      'AutoMapIntervalSeconds',
      value: 1,
    );
    setting.set(clamped);
    await database.configDao.updateConfig(setting);
    _autoMapIntervalSeconds = setting;
    notifyListeners();
  }

  bool get autoMapRetryEveryLaunch =>
      _autoMapRetryEveryLaunch?.get<bool>() != false;

  Future<void> setAutoMapRetryEveryLaunch(bool value) async {
    if (autoMapRetryEveryLaunch == value) return;
    final database = await DatabaseInstance.instance;
    final setting = await database.configDao.getOrCreateConfigByKey(
      'AutoMapRetryEveryLaunch',
      value: true,
    );
    setting.set(value);
    await database.configDao.updateConfig(setting);
    _autoMapRetryEveryLaunch = setting;
    notifyListeners();
  }

  int get autoMapMaxAttempts {
    final value = _autoMapMaxAttempts?.get<int>() as int?;
    if (value == null || value < 1) {
      return 3;
    }
    return value;
  }

  Future<void> setAutoMapMaxAttempts(int value) async {
    final clamped = value < 1 ? 1 : value;
    if (autoMapMaxAttempts == clamped) return;
    final database = await DatabaseInstance.instance;
    final setting = await database.configDao.getOrCreateConfigByKey(
      'AutoMapMaxAttempts',
      value: 3,
    );
    setting.set(clamped);
    await database.configDao.updateConfig(setting);
    _autoMapMaxAttempts = setting;
    notifyListeners();
  }
}

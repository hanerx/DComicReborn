import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/providers/comic_reading_progress.dart';
import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/subscribe_badge_state.dart';
import 'package:dcomic/utils/theme_utils.dart';
import 'package:flutter/material.dart';

enum ReadDirectionType { left, right, vertical }

class ConfigProvider extends BaseProvider {
  ConfigEntity? _themeMode;
  ConfigEntity? _readDirection;
  bool _drawDebugWidget = false;
  ConfigEntity? _horizontalClickAreaSize;
  ConfigEntity? _verticalClickAreaSize;
  ConfigEntity? _themeColor;
  ConfigEntity? _useMaterial3Design;
  ConfigEntity? _readerTheme;
  ConfigEntity? _aggregateSubscribeBadges;
  ConfigEntity? _aggregateReadingProgress;
  ConfigEntity? _advancedSettingsUnlocked;
  ConfigEntity? _autoMapMissingComics;
  ConfigEntity? _autoMapIntervalSeconds;
  ConfigEntity? _autoMapRetryEveryLaunch;
  ConfigEntity? _autoMapMaxAttempts;
  ConfigEntity? _readerPrecacheCount;

  @override
  Future<void> init() async {
    final database = await DatabaseInstance.instance;
    final settings = <String, ConfigEntity>{};
    for (final setting in await database.configDao.getAllConfig()) {
      settings.putIfAbsent(setting.key, () => setting);
    }
    ConfigEntity read(String key, dynamic fallback) =>
        settings[key] ?? ConfigEntity.createConfigEntity(key, fallback);

    // Defaults remain in memory: refreshing a remote deletion must not
    // recreate the row and publish it as a new local modification.
    _themeMode = read('ThemeMode', ThemeMode.system);
    _readDirection = read('ReadDirection', ReadDirectionType.left);
    _horizontalClickAreaSize = read('HorizontalClickAreaSize', 80);
    _verticalClickAreaSize = read('VerticalClickAreaSize', 150);
    _themeColor = read('ThemeColor', 'Blue');
    _useMaterial3Design = read('UseMaterial3Design', true);
    _readerTheme = read('ReaderTheme', ReaderTheme.app.name);
    _aggregateSubscribeBadges = read(SubscribeBadgeState.configKey, false);
    _aggregateReadingProgress = read(ComicReadingProgress.configKey, false);
    // Retain the persisted key for already-unlocked installations.
    _advancedSettingsUnlocked = read('ExperimentalFeaturesUnlocked', false);
    _autoMapMissingComics = read('AutoMapMissingComics', false);
    _autoMapIntervalSeconds = read('AutoMapIntervalSeconds', 1);
    _autoMapRetryEveryLaunch = read('AutoMapRetryEveryLaunch', true);
    _autoMapMaxAttempts = read('AutoMapMaxAttempts', 3);
    _readerPrecacheCount = read('ReaderPrecacheCount', 3);
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

  double get horizontalClickAreaSize {
    if (_horizontalClickAreaSize == null) {
      return 80;
    }
    return _horizontalClickAreaSize?.get<double>();
  }

  set horizontalClickAreaSize(double value) {
    if (_horizontalClickAreaSize != null) {
      _horizontalClickAreaSize?.set(value);
      _persistSetting(_horizontalClickAreaSize!);
    }
    notifyListeners();
  }

  double get verticalClickAreaSize {
    if (_verticalClickAreaSize == null) {
      return 150;
    }
    return _verticalClickAreaSize?.get<double>();
  }

  set verticalClickAreaSize(double value) {
    if (_verticalClickAreaSize != null) {
      _verticalClickAreaSize?.set(value);
      _persistSetting(_verticalClickAreaSize!);
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

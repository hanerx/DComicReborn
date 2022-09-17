import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/providers/base_provider.dart';
import 'package:flutter/material.dart';

class ConfigProvider extends BaseProvider {
  ConfigEntity? _themeMode;

  @override
  Future<void> init() async {
    final database = await DatabaseInstance.instance;
    _themeMode = (await database.configDao
        .getOrCreateConfigByKey('ThemeMode', value: ThemeMode.system));
  }

  ThemeMode? get themeMode {
    if (_themeMode == null) {
      return null;
    }
    return ThemeMode.values[(_themeMode?.get<int>()) as int];
  }

  set themeMode(ThemeMode? value) {
    if(_themeMode!=null&&value!=null){
      _themeMode?.set(value);
      DatabaseInstance.instance.then((value) => value.configDao.updateConfig(_themeMode!));
    }
  }
}

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/providers/base_provider.dart';
import 'package:flutter/material.dart';

enum ReadDirectionType {left, right, vertical}

class ConfigProvider extends BaseProvider {
  ConfigEntity? _themeMode;
  ConfigEntity? _readDirection;

  @override
  Future<void> init() async {
    final database = await DatabaseInstance.instance;
    _themeMode = (await database.configDao
        .getOrCreateConfigByKey('ThemeMode', value: ThemeMode.system));
    _readDirection = (await database.configDao
        .getOrCreateConfigByKey('ReadDirection', value: ReadDirectionType.left));
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
    notifyListeners();
  }

  ReadDirectionType get readDirection {
    if(_readDirection == null){
      return ReadDirectionType.left;
    }
    return ReadDirectionType.values[(_readDirection?.get<int>()) as int];
  }

  set readDirection(ReadDirectionType value){
    if(_readDirection!=null){
      _readDirection?.set(value);
      DatabaseInstance.instance.then((value) => value.configDao.updateConfig(_readDirection!));
    }
    notifyListeners();
  }
}

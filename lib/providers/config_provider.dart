import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/utils/theme_utils.dart';
import 'package:flutter/material.dart';

enum ReadDirectionType {left, right, vertical}

class ConfigProvider extends BaseProvider {
  ConfigEntity? _themeMode;
  ConfigEntity? _readDirection;
  bool _drawDebugWidget = false;
  ConfigEntity? _horizontalClickAreaSize;
  ConfigEntity? _verticalClickAreaSize;
  ConfigEntity? _themeColor;
  ConfigEntity? _useMaterial3Design;

  @override
  Future<void> init() async {
    final database = await DatabaseInstance.instance;
    _themeMode = (await database.configDao
        .getOrCreateConfigByKey('ThemeMode', value: ThemeMode.system));
    _readDirection = (await database.configDao
        .getOrCreateConfigByKey('ReadDirection', value: ReadDirectionType.left));
    _horizontalClickAreaSize = await database.configDao.getOrCreateConfigByKey('HorizontalClickAreaSize', value: 80);
    _verticalClickAreaSize = await database.configDao.getOrCreateConfigByKey('VerticalClickAreaSize', value: 150);
    _themeColor = await database.configDao.getOrCreateConfigByKey('ThemeColor', value: 'Blue');
    _useMaterial3Design = await database.configDao.getOrCreateConfigByKey('UseMaterial3Design', value: true);
    notifyListeners();
  }

  ThemeMode get themeMode {
    if (_themeMode == null) {
      return ThemeMode.system;
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

  bool get drawDebugWidget => _drawDebugWidget;

  set drawDebugWidget(bool debug) {
    _drawDebugWidget = debug;
    notifyListeners();
  }

  double get horizontalClickAreaSize{
    if(_horizontalClickAreaSize == null){
      return 80;
    }
    return _horizontalClickAreaSize?.get<double>();
  }

  set horizontalClickAreaSize(double value){
    if(_horizontalClickAreaSize!=null){
      _horizontalClickAreaSize?.set(value);
      DatabaseInstance.instance.then((value) => value.configDao.updateConfig(_horizontalClickAreaSize!));
    }
    notifyListeners();
  }

  double get verticalClickAreaSize{
    if(_verticalClickAreaSize == null){
      return 150;
    }
    return _verticalClickAreaSize?.get<double>();
  }

  set verticalClickAreaSize(double value){
    if(_verticalClickAreaSize!=null){
      _verticalClickAreaSize?.set(value);
      DatabaseInstance.instance.then((value) => value.configDao.updateConfig(_verticalClickAreaSize!));
    }
    notifyListeners();
  }

  ThemeModel get themeColor{
    if(_themeColor==null){
      return ThemeModel.themes['Blue']!;
    }
    return ThemeModel.themes[_themeColor?.get<String>()]!;
  }

  set themeColor(ThemeModel value){
    if(_themeColor!=null){
      _themeColor?.set(value.name);
      DatabaseInstance.instance.then((value) => value.configDao.updateConfig(_themeColor!));
    }
    notifyListeners();
  }

  bool get useMaterial3Design{
    if(_useMaterial3Design == null){
      return true;
    }
    return _useMaterial3Design?.get<bool>();
  }

  set useMaterial3Design(bool value){
    if(_useMaterial3Design!=null){
      _useMaterial3Design?.set(value);
      DatabaseInstance.instance.then((value) => value.configDao.updateConfig(_useMaterial3Design!));
    }
    notifyListeners();
  }
}

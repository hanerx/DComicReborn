
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/providers/base_provider.dart';
import 'package:flutter/material.dart';

class DatabaseDebugPageController extends BaseProvider {
  final List<String> tabNames = [
    'ComicHistoryEntity',
    'ConfigEntity',
    'CookieEntity',
    'ModelConfigEntity'
  ];

  List<Tab> get tabs => tabNames
      .map((e) => Tab(
            text: e,
          ))
      .toList();

  int get tableLength => tabNames.length;

  Map tableData = {};
  Map columnData = {};

  DatabaseDebugPageController() {
    for (var element in tabNames) {
      tableData[element] = [];
      columnData[element] = [];
    }
  }

  Future<void> refreshDatabase(String tableName) async {
    var databaseInstance = await DatabaseInstance.instance;
    tableData[tableName] = await databaseInstance.database.query(tableName);
    columnData[tableName] = tableData[tableName].keys;
    notifyListeners();
  }

  Future<void> delete(Map row, String tableName) async {
    var databaseInstance = await DatabaseInstance.instance;
    var where = row.keys.map<String>((e) => '`$e` = ?').join(' AND ');
    await databaseInstance.database.delete(tableName, where: where, whereArgs: row.values.toList());
    await refreshDatabase(tableName);
    notifyListeners();
  }
}

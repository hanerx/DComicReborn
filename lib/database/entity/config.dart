import 'package:dcomic/database/entity/entity_base.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:floor/floor.dart';

@entity
class ConfigEntity extends EntityBase {
  @PrimaryKey(autoGenerate: true)
  final int? id;

  final String key;

  String? value;

  ConfigEntity(this.id, this.key, this.value);

  ConfigEntity.createConfigEntity(this.key, dynamic value, {this.id}) {
    this.value = convertFromValue(value);
  }

  dynamic get<T>() => convertValue<T>(value);

  void set(dynamic value) {
    this.value = convertFromValue(value);
  }

  @override
  String toString() {
    return 'ConfigEntity{id: $id, key: $key, value: $value}';
  }
}

@dao
abstract class ConfigDao {
  @Query('SELECT * FROM ConfigEntity')
  Future<List<ConfigEntity>> getAllConfig();

  @Query('SELECT * FROM ConfigEntity WHERE `key` = :key')
  Future<ConfigEntity?> getConfigByKey(String key);

  @insert
  Future<void> insertConfig(ConfigEntity configEntity);

  @Update(onConflict: OnConflictStrategy.replace)
  Future<void> updateConfig(ConfigEntity configEntity);

  Future<ConfigEntity> getOrCreateConfigByKey(String key,
      {dynamic value = ''}) async {
    var result = await getConfigByKey(key);
    if (result == null) {
      result ??= ConfigEntity.createConfigEntity(key, value);
      await insertConfig(result);
    }
    return result;
  }
}

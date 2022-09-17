import 'package:dcomic/database/entity/entity_base.dart';
import 'package:floor/floor.dart';

@entity
class ModelConfigEntity extends EntityBase {
  @PrimaryKey(autoGenerate: true)
  final int? id;

  final String key;

  String? value;

  String? sourceModel;

  ModelConfigEntity(this.id, this.key, this.value, this.sourceModel);

  ModelConfigEntity.createConfigEntity(
      this.key, dynamic value, this.sourceModel,
      {this.id}) {
    this.value = convertFromValue(value);
  }

  dynamic get<T>() => convertValue<T>(value);

  void set(dynamic value) {
    this.value = convertFromValue(value);
  }

  @override
  String toString() {
    return 'ModelConfigEntity{id: $id, key: $key, value: $value, sourceModel: $sourceModel}';
  }
}


@dao
abstract class ModelConfigDao {
  @Query('SELECT * FROM ModelConfigEntity')
  Future<List<ModelConfigEntity>> getAllConfig();

  @Query('SELECT * FROM ModelConfigEntity WHERE key = :key AND sourceModel = :sourceModel LIMIT 1')
  Future<ModelConfigEntity?> getConfigByKeyAndModel(String key,String sourceModel);

  @insert
  Future<void> insertConfig(ModelConfigEntity configEntity);

  @update
  Future<void> updateConfig(ModelConfigEntity configEntity);

  Future<ModelConfigEntity> getOrCreateConfigByKey(String key,String sourceModel,
      {dynamic value = ''}) async {
    var result = await getConfigByKeyAndModel(key,sourceModel);
    if (result == null) {
      result ??= ModelConfigEntity.createConfigEntity(key, value,sourceModel);
      await insertConfig(result);
    }
    return result;
  }
}
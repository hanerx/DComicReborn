import 'package:dcomic/database/entity/entity_base.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:floor/floor.dart';

@entity
class ModelConfigEntity {
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

  dynamic convertValue<T>(dynamic value){
    try {
      switch(T){
        case String:
          return value.toString();
        case bool:
          return value=='1';
        case int:
          return int.parse(value);
        case double:
          return double.parse(value);
        default:
          return value;
      }
    }catch (e, s) {
      FirebaseCrashlytics.instance.recordError(e, s,reason: 'ValueConvert Failed: (Value= $value, Type= $T)');
    }
    return null;
  }

  String? convertFromValue(dynamic value){
    try{
      switch(value.runtimeType){
        case bool:
          return value?'1':'0';
        default:
          if(value is Enum){
            return value.index.toString();
          }
          return value.toString();
      }
    }catch(e,s){
      FirebaseCrashlytics.instance.recordError(e, s,reason: 'ValueConvert Failed: (Value= $value, Type= ${value.runtimeType})');
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelConfigEntity &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          sourceModel == other.sourceModel;

  @override
  int get hashCode => value.hashCode ^ sourceModel.hashCode;
}


@dao
abstract class ModelConfigDao {
  @Query('SELECT * FROM ModelConfigEntity')
  Future<List<ModelConfigEntity>> getAllConfig();

  @Query('SELECT * FROM ModelConfigEntity WHERE `key` = :key AND `sourceModel` = :sourceModel LIMIT 1')
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
import 'package:dcomic/database/entity/entity_base.dart';
import 'package:floor/floor.dart';

@Entity()
class ComicMappingEntity extends EntityBase {
  @PrimaryKey(autoGenerate: true)
  final int? id;

  final String comicId;

  final String sourceProviderName;

  final String targetProviderName;

  String resultComicId;

  ComicMappingEntity(
      this.id,
      this.comicId,
      this.sourceProviderName,
      this.targetProviderName,
      this.resultComicId);

  ComicMappingEntity.createComicMappingEntity(
      this.comicId,
      this.sourceProviderName,
      this.targetProviderName,
      {this.id,
        this.resultComicId = ''});
}

@dao
abstract class ComicMappingDao {
  @Query('SELECT * FROM ComicMappingEntity')
  Future<List<ComicMappingEntity>> getAllComicMappingEntity();

  @Query(
      'SELECT * FROM ComicMappingEntity WHERE `comicId`= :comicId AND `sourceProviderName`= :sourceProviderName AND `targetProviderName`= :targetProviderName')
  Future<ComicMappingEntity?> getComicMappingByComicId(
      String comicId, String sourceProviderName, String targetProviderName);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertComicMapping(ComicMappingEntity comicMappingEntity);

  @Update(onConflict: OnConflictStrategy.replace)
  Future<void> updateComicMapping(ComicMappingEntity comicMappingEntity);

  Future<ComicMappingEntity> getOrCreateConfigByComicId(
      String comicId, String sourceProviderName, String targetProviderName,
      {dynamic value = ''}) async {
    var result = await getComicMappingByComicId(comicId, sourceProviderName, targetProviderName);
    if (result == null) {
      result ??= ComicMappingEntity.createComicMappingEntity(comicId, sourceProviderName, targetProviderName);
      await insertComicMapping(result);
    }
    return result;
  }
}

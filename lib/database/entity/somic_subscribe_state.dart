import 'package:dcomic/database/entity/entity_base.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:floor/floor.dart';

@Entity()
class ComicSubscribeStateEntity extends EntityBase {
  @PrimaryKey(autoGenerate: true)
  final int? id;

  final String comicId;

  DateTime? timestamp;

  String providerName = 'Unknown';

  ComicSubscribeStateEntity(
      this.id,
      this.comicId,
      this.timestamp,
      this.providerName);

  ComicSubscribeStateEntity.createComicSubscribeStateEntity(
      this.comicId, {
        this.timestamp,
        this.providerName = 'Unknown',
        this.id,
      });

}

@dao
abstract class ComicSubscribeStateDao {
  @Query('SELECT * FROM ComicSubscribeStateEntity')
  Future<List<ComicSubscribeStateEntity>> getAllComicSubscribeStateEntity();

  @Query('SELECT * FROM ComicSubscribeStateEntity WHERE `comicId`= :comicId AND `providerName`= :providerName')
  Future<ComicSubscribeStateEntity?> getComicSubscribeStateByComicId(String comicId, String providerName);

  @Query('SELECT * FROM ComicSubscribeStateEntity WHERE `providerName`= :providerName GROUP BY comicId')
  Future<List<ComicSubscribeStateEntity>> getComicSubscribeStateByProvider(
      String providerName);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertComicSubscribeState(ComicSubscribeStateEntity comicSubscribeStateEntity);

  @Update(onConflict: OnConflictStrategy.replace)
  Future<void> updateComicSubscribeState(ComicSubscribeStateEntity comicSubscribeStateEntity);

  Future<ComicSubscribeStateEntity> getOrCreateConfigByComicId(String comicId,String sourceModel,
      {dynamic value = ''}) async {
    var result = await getComicSubscribeStateByComicId(comicId,sourceModel);
    if (result == null) {
      result ??= ComicSubscribeStateEntity.createComicSubscribeStateEntity(comicId, providerName: sourceModel);
      await insertComicSubscribeState(result);
      result = await getComicSubscribeStateByComicId(comicId,sourceModel)??result;
    }
    return result;
  }
}

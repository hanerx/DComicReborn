import 'package:dcomic/database/entity/entity_base.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:floor/floor.dart';

@Entity()
class ComicHistoryEntity extends EntityBase {
  @PrimaryKey(autoGenerate: true)
  final int? id;

  final String comicId;

  String? title;

  String? cover;

  ImageType? coverType;

  String? lastChapterTitle;

  String? lastChapterId;

  DateTime? timestamp;

  String? providerName;

  ComicHistoryEntity(
      this.id,
      this.comicId,
      this.title,
      this.cover,
      this.coverType,
      this.lastChapterTitle,
      this.lastChapterId,
      this.timestamp,
      this.providerName);

  ComicHistoryEntity.createComicHistoryEntity(
    this.comicId, {
    this.title,
    this.cover,
    this.coverType,
    this.lastChapterTitle,
    this.lastChapterId,
    this.timestamp,
    this.providerName,
    this.id,
  });

  @override
  String toString() {
    return 'ComicHistoryEntity{id: $id, comicId: $comicId, title: $title, cover: $cover, coverType: $coverType, lastChapterTitle: $lastChapterTitle, lastChapterId: $lastChapterId, timestamp: $timestamp, providerName: $providerName}';
  }
}

@dao
abstract class ComicHistoryDao {
  @Query('SELECT * FROM ComicHistoryEntity')
  Future<List<ComicHistoryEntity>> getAllComicHistoryEntity();

  @Query('SELECT * FROM ComicHistoryEntity WHERE comicId= :comicId')
  Future<ComicHistoryEntity?> getComicHistoryByComicId(String comicId);

  @Query('SELECT * FROM ComicHistoryEntity WHERE providerName= :providerName')
  Future<List<ComicHistoryEntity>> getComicHistoryByProvider(
      String providerName);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertComicHistory(ComicHistoryEntity comicHistoryEntity);

  @Update(onConflict: OnConflictStrategy.replace)
  Future<void> updateComicHistory(ComicHistoryEntity comicHistoryEntity);
}

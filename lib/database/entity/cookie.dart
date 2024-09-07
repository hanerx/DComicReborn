import 'package:dcomic/database/entity/entity_base.dart';
import 'package:floor/floor.dart';

@entity
class CookieEntity extends EntityBase {
  @PrimaryKey(autoGenerate: true)
  int? id;

  @PrimaryKey()
  String key;

  String value;

  CookieEntity(this.id, this.key, this.value);

  CookieEntity.createNew(this.key, this.value);

  @override
  String toString() {
    return 'CookieEntity{id: $id, key: $key, value: $value}';
  }
}

@dao
abstract class CookieDao {
  @Query('SELECT * FROM CookieEntity')
  Future<List<CookieEntity>> getAllCookies();

  @Query('SELECT * FROM CookieEntity WHERE `key` = :key LIMIT 1')
  Future<CookieEntity?> getCookieByKey(String key);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertCookie(CookieEntity cookieEntity);

  @Update(onConflict: OnConflictStrategy.replace)
  Future<void> updateCookie(CookieEntity cookieEntity);

  Future<void> setCookie(String key, String value) async {
    CookieEntity? cookie = await getCookieByKey(key);
    if (cookie != null) {
      cookie.value = value;
      await updateCookie(cookie);
      return;
    }
    cookie ??= CookieEntity.createNew(key, value);
    await insertCookie(cookie);
  }

  @Query('DELETE FROM CookieEntity WHERE `key` = :key')
  Future<void> deleteCookie(String key);
}

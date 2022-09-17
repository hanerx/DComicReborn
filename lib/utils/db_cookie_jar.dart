import 'package:cookie_jar/cookie_jar.dart';
import 'package:dcomic/database/database_common.dart';
import 'package:dcomic/database/database_instance.dart';

class DatabaseCookieJarStorage extends Storage {
  @override
  Future<void> delete(String key) async {
    DComicDatabase database = await DatabaseInstance.instance;
    database.cookieDao.deleteCookie(key);
  }

  @override
  Future<void> deleteAll(List<String> keys) async {
    DComicDatabase database = await DatabaseInstance.instance;
    for (var key in keys) {
      database.cookieDao.deleteCookie(key);
    }
  }

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) async {
    DComicDatabase database = await DatabaseInstance.instance;
    return (await database.cookieDao.getCookieByKey(key))?.value;
  }

  @override
  Future<void> write(String key, String value) async {
    DComicDatabase database = await DatabaseInstance.instance;
    database.cookieDao.setCookie(key, value);
  }
}

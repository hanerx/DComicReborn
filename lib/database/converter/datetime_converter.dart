import 'package:floor/floor.dart';

class DateTimeConverter extends TypeConverter<DateTime, int> {
  @override
  DateTime decode(int databaseValue) {
    return DateTime.fromMillisecondsSinceEpoch(databaseValue);
  }

  @override
  int encode(DateTime value) {
    return value.millisecondsSinceEpoch;
  }
}

class DateTimeNullableConverter extends TypeConverter<DateTime?, int?> {
  @override
  DateTime? decode(int? databaseValue) {
    if(databaseValue==null){
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(databaseValue);
  }

  @override
  int? encode(DateTime? value) {
    if(value==null){
      return null;
    }
    return value.millisecondsSinceEpoch;
  }
}
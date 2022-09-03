import 'package:dcomic/utils/image_utils.dart';
import 'package:floor/floor.dart';

class ImageTypeConverter extends TypeConverter<ImageType, int> {
  @override
  ImageType decode(int databaseValue) {
    return ImageType.values[databaseValue];
  }

  @override
  int encode(ImageType value) {
    return ImageType.values.indexOf(value);
  }
}

class ImageTypeNullableConverter extends TypeConverter<ImageType?, int?> {
  @override
  ImageType? decode(int? databaseValue) {
    if (databaseValue == null) {
      return null;
    }
    return ImageType.values[databaseValue];
  }

  @override
  int? encode(ImageType? value) {
    if (value == null) {
      return null;
    }
    return ImageType.values.indexOf(value);
  }
}

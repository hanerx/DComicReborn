import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class BaseProvider extends ChangeNotifier {
  Logger logger = Logger(
    printer: PrettyPrinter(),
  );
}

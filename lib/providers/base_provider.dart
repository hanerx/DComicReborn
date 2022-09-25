import 'package:dcomic/utils/firbaselogoutput.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

abstract class BaseProvider extends ChangeNotifier {
  Logger logger = Logger(
      printer: PrettyPrinter(noBoxingByDefault: true,methodCount:2),
      filter: ProductionFilter(),
      output: CrashConsoleOutput());

  BaseProvider() {
    init();
  }

  Future<void> init() async {}
}

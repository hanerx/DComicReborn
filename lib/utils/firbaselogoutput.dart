import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

// Crashlytics is configured only for the mobile applications.
Future<void> recordAppError(
  Object error,
  StackTrace stack, {
  String? reason,
  bool fatal = false,
  bool printDetails = false,
}) async {
  if ((defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) &&
      Firebase.apps.isNotEmpty) {
    await FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: reason,
      fatal: fatal,
      printDetails: printDetails,
    );
  } else {
    debugPrint('${reason ?? 'Application error'}: $error\n$stack');
  }
}

class CrashConsoleOutput extends ConsoleOutput {
  @override
  void output(OutputEvent event) {
    super.output(event);
    if (event.level == Level.error) {
      recordAppError(
        event.lines.join('\n'),
        StackTrace.fromString(event.lines.join('\n')),
        printDetails: true,
        fatal: false,
      );
    }
  }
}

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:logger/logger.dart';

class CrashConsoleOutput extends ConsoleOutput{

  @override
  void output(OutputEvent event) {
    super.output(event);
    if(event.level==Level.error){
      FirebaseCrashlytics.instance.recordError(event.lines.join('\n'), StackTrace.fromString(event.lines.join('\n')),printDetails: true,fatal: false);
    }
  }
}
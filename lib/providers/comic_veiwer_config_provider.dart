import 'package:dcomic/providers/base_provider.dart';

class ComicViewerConfigProvider extends BaseProvider {
  bool _drawDebugWidget = false;

  bool get drawDebugWidget => _drawDebugWidget;

  set drawDebugWidget(bool debug) {
    _drawDebugWidget = debug;
    notifyListeners();
  }
}

import 'package:dcomic/providers/base_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum UpdateChannel { release, beta, develop }

class VersionProvider extends BaseProvider {
  String _currentVersion = '2.0.0';
  UpdateChannel _channel = UpdateChannel.develop;

  @override
  Future<void> init() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    _currentVersion = packageInfo.version;
    notifyListeners();
  }

  String get currentVersion => _currentVersion;

  UpdateChannel get channel => _channel;
}

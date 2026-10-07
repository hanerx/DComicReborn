import 'dart:isolate';
import 'dart:ui';
import 'dart:io';

import 'package:flutter_downloader/flutter_downloader.dart';

import 'base_provider.dart';

typedef ProviderDownloadCallback = Future<void> Function(
    String id,
    DownloadTaskStatus status,
    int progress);

@pragma('vm:entry-point')
void onDownloadCallback(String id, int status, int progress) async {
  final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
  send?.send([id, status, progress]);
}

class DownloadProvider extends BaseProvider {
  ReceivePort? _port;
  final Map<String, ProviderDownloadCallback> _downloadCallbacks = {};

  @override
  Future<void> init() async{
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await FlutterDownloader.initialize();
    final port = _port = ReceivePort();
    IsolateNameServer.registerPortWithName(port.sendPort, 'downloader_send_port');
    port.listen((dynamic data) {
      String id = data[0];
      DownloadTaskStatus status = DownloadTaskStatus.fromInt(data[1]);
      int progress = data[2];
      onDownload(id, status, progress);
    });
    FlutterDownloader.registerCallback(onDownloadCallback);
  }

  Future<void> onDownload(String id, DownloadTaskStatus status, int progress) async {
    // Handle the download callback here
    logger.d('Download ID: $id, Status: $status, Progress: $progress');
    if (_downloadCallbacks.containsKey(id)) {
      _downloadCallbacks[id]!(id, status, progress);
      if(status == DownloadTaskStatus.complete) {
        _downloadCallbacks.remove(id);
      }
    }
    notifyListeners();
  }

  void registerDownloadCallback(String id, ProviderDownloadCallback callback) {
    _downloadCallbacks[id] = callback;
  }

  @override
  void dispose() {
    if (_port != null) {
      IsolateNameServer.removePortNameMapping('downloader_send_port');
      _port!.close();
    }
    super.dispose();
  }
}
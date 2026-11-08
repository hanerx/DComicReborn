import 'dart:async';

import 'package:dcomic/downloads/download_models.dart';
import 'package:dcomic/downloads/download_service.dart';
import 'package:flutter/foundation.dart';

class DownloadProvider extends ChangeNotifier {
  final DownloadService service;
  late final Future<void> ready;
  StreamSubscription<List<DownloadRecord>>? _subscription;
  List<DownloadRecord> _records = const [];
  Object? _error;
  bool _disposed = false;

  DownloadProvider({DownloadService? service})
    : service = service ?? DownloadService.instance {
    ready = _initialize();
  }

  List<DownloadRecord> get records => _records;

  Object? get error => _error;

  Future<void> _initialize() async {
    try {
      await service.initialize();
      _records = await service.list();
      _error = service.notificationWarning;
      if (!_disposed) notifyListeners();
      if (_disposed) return;
      _subscription = service.watch().listen(
        (records) {
          if (_disposed) return;
          _records = records;
          _error = service.notificationWarning;
          notifyListeners();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (_disposed) return;
          _error = error;
          notifyListeners();
        },
      );
    } on Object catch (error) {
      _error = error;
      if (!_disposed) notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}

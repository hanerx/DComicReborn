import 'dart:async';
import 'dart:typed_data';

import 'package:dcomic/utils/performance_monitor.dart';
import 'package:dcomic/utils/request_performance.dart';
import 'package:dio/dio.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_test/flutter_test.dart';

class _Trace implements Trace {
  final attributes = <String, String>{};
  final metrics = <String, int>{};
  final started = Completer<void>();
  int stops = 0;
  bool failStop = false;

  @override
  Future<void> start() => started.future;
  @override
  Future<void> stop() async {
    stops++;
    if (failStop) throw StateError('SDK unavailable');
  }

  @override
  void putAttribute(String name, String value) => attributes[name] = value;
  @override
  void setMetric(String name, int value) => metrics[name] = value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Adapter implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      '{"value":7}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'cache short-circuit is one completed request without SDK blocking',
    () async {
      final native = _Trace();
      final client = RequestPerformanceDio(
        monitor: PerformanceMonitor(traceFactory: (_) => native),
      );
      final adapter = _Adapter();
      client.httpClientAdapter = adapter;
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'cached': true},
              ),
            );
          },
        ),
      );
      final response = await client.get<Map<String, dynamic>>(
        'https://example.com/private-title',
        queryParameters: {'token': 'secret'},
      );
      expect(response.data, {'cached': true});
      expect(adapter.calls, 0);
      expect(native.stops, 0);
      native.started.complete();
      await Future<void>.delayed(Duration.zero);
      expect(native.stops, 1);
      expect(native.attributes, {'method': 'GET', 'outcome': 'success'});
      expect(native.metrics['status_code'], 200);
      client.close();
    },
  );

  test('error-interceptor recovery reports the final cached result', () async {
    final native = _Trace()..started.complete();
    final client = RequestPerformanceDio(
      monitor: PerformanceMonitor(traceFactory: (_) => native),
    );
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
          true,
        ),
        onError: (error, handler) => handler.resolve(
          Response(
            requestOptions: error.requestOptions,
            statusCode: 200,
            data: 'cached',
          ),
        ),
      ),
    );
    expect((await client.get<String>('https://example.com')).data, 'cached');
    await Future<void>.delayed(Duration.zero);
    expect(native.attributes['outcome'], 'success');
    expect(native.stops, 1);
    client.close();
  });

  test(
    'cancellation is preserved and a completed trace cannot become success',
    () async {
      final native = _Trace()..started.complete();
      final client = RequestPerformanceDio(
        monitor: PerformanceMonitor(traceFactory: (_) => native),
      );
      final cancel = CancelToken();
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            cancel.cancel('cancelled by caller');
            handler.next(options);
          },
        ),
      );
      await expectLater(
        client.get('https://example.com', cancelToken: cancel),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(native.attributes['outcome'], 'cancelled');
      expect(native.stops, 1);
      client.close();
    },
  );

  test('SDK startup failure preserves a decoded response', () async {
    final client = RequestPerformanceDio(
      monitor: PerformanceMonitor(
        traceFactory: (_) => throw StateError('SDK unavailable'),
      ),
    );
    client.httpClientAdapter = _Adapter();
    final response = await client.get<Map<String, dynamic>>(
      'https://example.com',
    );
    expect(response.data, {'value': 7});
    client.close();
  });

  test('SDK stop failure preserves the original request exception', () async {
    final native = _Trace()..failStop = true;
    native.started.complete();
    final client = RequestPerformanceDio(
      monitor: PerformanceMonitor(traceFactory: (_) => native),
    );
    final error = DioException(
      requestOptions: RequestOptions(path: 'https://example.com'),
      type: DioExceptionType.connectionError,
    );
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(error),
      ),
    );
    await expectLater(client.get('https://example.com'), throwsA(same(error)));
    await Future<void>.delayed(Duration.zero);
    expect(native.attributes['outcome'], 'error');
    expect(native.stops, 1);
    client.close();
  });

  test(
    'streaming response is not misreported as a completed download',
    () async {
      var traces = 0;
      final client = RequestPerformanceDio(
        monitor: PerformanceMonitor(
          traceFactory: (_) {
            traces++;
            return _Trace()..started.complete();
          },
        ),
      );
      client.httpClientAdapter = _Adapter();
      final response = await client.get<ResponseBody>(
        'https://example.com',
        options: Options(responseType: ResponseType.stream),
      );
      expect(
        await response.data!.stream.fold<int>(
          0,
          (size, chunk) => size + chunk.length,
        ),
        11,
      );
      expect(traces, 0);
      client.close();
    },
  );
}

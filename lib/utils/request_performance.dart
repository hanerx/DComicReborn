import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'performance_monitor.dart';

/// Observes the complete Dio pipeline, including cache short-circuits and error
/// recovery. An interceptor cannot reliably see both of those completion paths.
class RequestPerformanceDio extends DioForNative {
  RequestPerformanceDio({PerformanceMonitor? monitor})
    : _monitor = monitor ?? PerformanceMonitor.instance;

  final PerformanceMonitor _monitor;

  @override
  Future<Response<T>> fetch<T>(RequestOptions requestOptions) async {
    // A streaming response only makes headers available here, not the body.
    // Do not report that as the duration of a download.
    if (requestOptions.responseType == ResponseType.stream) {
      return super.fetch<T>(requestOptions);
    }
    final method = requestOptions.method.toUpperCase();
    final trace = _monitor.startTrace(
      'request_response',
      attributes: {
        'method':
            const {
              'GET',
              'HEAD',
              'POST',
              'PUT',
              'DELETE',
              'PATCH',
              'OPTIONS',
            }.contains(method)
            ? method
            : 'OTHER',
      },
    );
    var outcome = 'error';
    int? status;
    try {
      final response = await super.fetch<T>(requestOptions);
      status = response.statusCode;
      outcome = status != null && status >= 400 ? 'http_error' : 'success';
      return response;
    } on DioException catch (error) {
      status = error.response?.statusCode;
      outcome = error.type == DioExceptionType.cancel ? 'cancelled' : 'error';
      rethrow;
    } finally {
      unawaited(
        trace.stop(
          outcome: outcome,
          metrics: status == null ? const {} : {'status_code': status},
        ),
      );
    }
  }
}

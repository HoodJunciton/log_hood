import 'dart:convert';
import 'package:dio/dio.dart';
import '../logger.dart';
import '../core/log_level.dart';

class LogHoodDioInterceptor extends Interceptor {
  final Logger _logger;
  final bool logRequestBody;
  final bool logResponseBody;
  final bool logHeaders;
  final int maxBodyLength;

  LogHoodDioInterceptor({
    Logger? logger,
    this.logRequestBody = true,
    this.logResponseBody = true,
    this.logHeaders = true,
    this.maxBodyLength = 1000,
  }) : _logger = logger ?? Logger.getLogger('DIO');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    options.extra['requestId'] = requestId;
    options.extra['startTime'] = DateTime.now();

    final metadata = <String, dynamic>{
      'type': 'request',
      'id': requestId,
      'method': options.method,
      'url': options.uri.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'timeout': options.connectTimeout?.inMilliseconds,
    };

    if (logHeaders && options.headers.isNotEmpty) {
      metadata['headers'] = _sanitizeHeaders(options.headers);
    }

    if (options.queryParameters.isNotEmpty) {
      metadata['queryParams'] = options.queryParameters;
    }

    if (logRequestBody && options.data != null) {
      final body = _formatBody(options.data);
      metadata['body'] = _truncateBody(body);
      metadata['bodySize'] = body.length;
    }

    _logger.info(
      '🌐 → ${options.method} ${_truncateUrl(options.uri.toString())}',
      metadata: metadata,
      tags: ['network', 'dio', 'request', options.method.toLowerCase()],
    );

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final requestId = response.requestOptions.extra['requestId'] as String?;
    final startTime = response.requestOptions.extra['startTime'] as DateTime?;
    final duration = startTime != null 
        ? DateTime.now().difference(startTime) 
        : Duration.zero;

    final metadata = <String, dynamic>{
      'type': 'response',
      'id': requestId,
      'statusCode': response.statusCode,
      'duration': duration.inMilliseconds,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (response.statusMessage != null) {
      metadata['statusMessage'] = response.statusMessage;
    }

    if (logHeaders && response.headers.map.isNotEmpty) {
      metadata['headers'] = response.headers.map.map(
        (k, v) => MapEntry(k, v.join(', '))
      );
    }

    if (logResponseBody && response.data != null) {
      final body = _formatBody(response.data);
      metadata['body'] = _truncateBody(body);
      metadata['bodySize'] = body.length;
      
      // Include actual data if it's already parsed
      if (response.data is Map || response.data is List) {
        metadata['bodyJson'] = response.data;
      }
    }

    final level = _getLogLevelForStatus(response.statusCode ?? 0);
    final emoji = _getEmojiForStatus(response.statusCode ?? 0);
    
    _logger.log(
      level,
      '$emoji ← ${response.statusCode} (${duration.inMilliseconds}ms)',
      metadata: metadata,
      tags: ['network', 'dio', 'response', 'status_${response.statusCode}'],
    );

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final requestId = err.requestOptions.extra['requestId'] as String?;
    final startTime = err.requestOptions.extra['startTime'] as DateTime?;
    final duration = startTime != null 
        ? DateTime.now().difference(startTime) 
        : Duration.zero;

    final metadata = <String, dynamic>{
      'type': 'error',
      'id': requestId,
      'method': err.requestOptions.method,
      'url': err.requestOptions.uri.toString(),
      'duration': duration.inMilliseconds,
      'errorType': err.type.toString(),
      'errorMessage': err.message,
    };

    if (err.response != null) {
      metadata['statusCode'] = err.response!.statusCode;
      metadata['statusMessage'] = err.response!.statusMessage;
      
      if (logResponseBody && err.response!.data != null) {
        final body = _formatBody(err.response!.data);
        metadata['responseBody'] = _truncateBody(body);
      }
    }

    _logger.error(
      '❌ ${err.requestOptions.method} ${_truncateUrl(err.requestOptions.uri.toString())} failed',
      error: err.error,
      stackTrace: err.stackTrace,
      metadata: metadata,
      tags: ['network', 'dio', 'error', err.type.toString()],
    );

    handler.next(err);
  }

  String _formatBody(dynamic data) {
    if (data == null) return '';
    
    if (data is String) {
      return data;
    } else if (data is Map || data is List) {
      try {
        return const JsonEncoder.withIndent('  ').convert(data);
      } catch (_) {
        return data.toString();
      }
    } else if (data is FormData) {
      final parts = <String>[];
      parts.add('FormData:');
      parts.add('Fields: ${data.fields}');
      parts.add('Files: ${data.files.map((f) => f.key).join(', ')}');
      return parts.join('\n');
    } else {
      return data.toString();
    }
  }

  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = <String, dynamic>{};
    for (final entry in headers.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains('authorization') || 
          key.contains('cookie') || 
          key.contains('token') ||
          key.contains('api-key')) {
        sanitized[entry.key] = '***REDACTED***';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  String _truncateBody(String body) {
    if (body.length <= maxBodyLength) {
      return body;
    }
    return '${body.substring(0, maxBodyLength)}... (truncated)';
  }

  String _truncateUrl(String url) {
    if (url.length <= 100) {
      return url;
    }
    return '${url.substring(0, 100)}...';
  }

  LogLevel _getLogLevelForStatus(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return LogLevel.info;
    } else if (statusCode >= 300 && statusCode < 400) {
      return LogLevel.info;
    } else if (statusCode >= 400 && statusCode < 500) {
      return LogLevel.warning;
    } else {
      return LogLevel.error;
    }
  }

  String _getEmojiForStatus(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return '✅';
    } else if (statusCode >= 300 && statusCode < 400) {
      return '↩️';
    } else if (statusCode >= 400 && statusCode < 500) {
      return '⚠️';
    } else {
      return '❌';
    }
  }
}

// Extension to make it easy to use
extension LogHoodDioExtension on Dio {
  void addLogHoodInterceptor({
    Logger? logger,
    bool logRequestBody = true,
    bool logResponseBody = true,
    bool logHeaders = true,
    int maxBodyLength = 1000,
  }) {
    interceptors.add(LogHoodDioInterceptor(
      logger: logger,
      logRequestBody: logRequestBody,
      logResponseBody: logResponseBody,
      logHeaders: logHeaders,
      maxBodyLength: maxBodyLength,
    ));
  }
}
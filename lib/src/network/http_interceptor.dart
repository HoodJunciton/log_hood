import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../logger.dart';
import '../core/log_level.dart';

class LogHoodHttpClient extends http.BaseClient {
  final http.Client _inner;
  final Logger _logger;
  final bool logRequestBody;
  final bool logResponseBody;
  final bool logHeaders;
  final int maxBodyLength;

  LogHoodHttpClient({
    http.Client? inner,
    Logger? logger,
    this.logRequestBody = true,
    this.logResponseBody = true,
    this.logHeaders = true,
    this.maxBodyLength = 1000,
  })  : _inner = inner ?? http.Client(),
        _logger = logger ?? Logger.getLogger('HTTP');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final startTime = DateTime.now();
    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    
    // Log request
    await _logRequest(request, requestId);

    try {
      final response = await _inner.send(request);
      final duration = DateTime.now().difference(startTime);
      
      // We need to buffer the response to log it
      final bytes = await response.stream.toBytes();
      final bufferedResponse = http.StreamedResponse(
        Stream.fromIterable([bytes]),
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );

      // Log response
      await _logResponse(bufferedResponse, bytes, duration, requestId);

      return bufferedResponse;
    } catch (error, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      _logError(request, error, stackTrace, duration, requestId);
      rethrow;
    }
  }

  Future<void> _logRequest(http.BaseRequest request, String requestId) async {
    final metadata = <String, dynamic>{
      'type': 'request',
      'id': requestId,
      'method': request.method,
      'url': request.url.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (logHeaders && request.headers.isNotEmpty) {
      metadata['headers'] = _sanitizeHeaders(request.headers);
    }

    String? body;
    if (logRequestBody && request is http.Request) {
      body = _truncateBody(request.body);
      if (body.isNotEmpty) {
        metadata['body'] = body;
        metadata['bodySize'] = request.body.length;
      }
    } else if (request is http.MultipartRequest) {
      metadata['contentType'] = 'multipart/form-data';
      metadata['fields'] = request.fields;
      metadata['files'] = request.files.map((f) => {
        'field': f.field,
        'filename': f.filename,
        'length': f.length,
      }).toList();
    }

    _logger.info(
      '🌐 → ${request.method} ${_truncateUrl(request.url.toString())}',
      metadata: metadata,
      tags: ['network', 'request', request.method.toLowerCase()],
    );
  }

  Future<void> _logResponse(
    http.StreamedResponse response,
    List<int> bytes,
    Duration duration,
    String requestId,
  ) async {
    final metadata = <String, dynamic>{
      'type': 'response',
      'id': requestId,
      'statusCode': response.statusCode,
      'duration': duration.inMilliseconds,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (response.reasonPhrase != null) {
      metadata['reasonPhrase'] = response.reasonPhrase;
    }

    if (logHeaders && response.headers.isNotEmpty) {
      metadata['headers'] = _sanitizeHeaders(response.headers);
    }

    if (logResponseBody && bytes.isNotEmpty) {
      try {
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('json')) {
          final body = utf8.decode(bytes);
          metadata['body'] = _truncateBody(body);
          metadata['bodySize'] = bytes.length;
          
          // Try to parse JSON for better formatting
          try {
            metadata['bodyJson'] = jsonDecode(body);
          } catch (_) {
            // Keep string body if JSON parsing fails
          }
        } else if (contentType.contains('text')) {
          metadata['body'] = _truncateBody(utf8.decode(bytes));
          metadata['bodySize'] = bytes.length;
        } else {
          metadata['bodyType'] = 'binary';
          metadata['bodySize'] = bytes.length;
        }
      } catch (e) {
        metadata['bodyError'] = 'Failed to decode body: $e';
      }
    }

    final level = _getLogLevelForStatus(response.statusCode);
    final emoji = _getEmojiForStatus(response.statusCode);
    
    _logger.log(
      level,
      '$emoji ← ${response.statusCode} (${duration.inMilliseconds}ms)',
      metadata: metadata,
      tags: ['network', 'response', 'status_${response.statusCode}'],
    );
  }

  void _logError(
    http.BaseRequest request,
    Object error,
    StackTrace stackTrace,
    Duration duration,
    String requestId,
  ) {
    _logger.error(
      '❌ ${request.method} ${_truncateUrl(request.url.toString())} failed',
      error: error,
      stackTrace: stackTrace,
      metadata: {
        'type': 'error',
        'id': requestId,
        'method': request.method,
        'url': request.url.toString(),
        'duration': duration.inMilliseconds,
        'errorType': error.runtimeType.toString(),
      },
      tags: ['network', 'error'],
    );
  }

  Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    final sanitized = <String, String>{};
    for (final entry in headers.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains('authorization') || 
          key.contains('cookie') || 
          key.contains('token')) {
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

  @override
  void close() {
    _inner.close();
  }
}

// Extension to make it easy to use
extension LogHoodHttpExtension on http.Client {
  LogHoodHttpClient withLogging({
    Logger? logger,
    bool logRequestBody = true,
    bool logResponseBody = true,
    bool logHeaders = true,
    int maxBodyLength = 1000,
  }) {
    return LogHoodHttpClient(
      inner: this,
      logger: logger,
      logRequestBody: logRequestBody,
      logResponseBody: logResponseBody,
      logHeaders: logHeaders,
      maxBodyLength: maxBodyLength,
    );
  }
}
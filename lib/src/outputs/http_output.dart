import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/log_entry.dart';
import 'log_output.dart';

class HttpOutput implements LogOutput {
  final String endpoint;
  final Map<String, String>? headers;
  final Duration batchInterval;
  final int batchSize;
  final int maxRetries;
  final Duration retryDelay;
  final bool compress;
  final void Function(Object error, StackTrace stackTrace)? onError;
  
  final List<LogEntry> _buffer = [];
  Timer? _batchTimer;
  bool _isSending = false;

  HttpOutput({
    required this.endpoint,
    this.headers,
    this.batchInterval = const Duration(seconds: 5),
    this.batchSize = 50,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.compress = true,
    this.onError,
  }) {
    _startBatchTimer();
  }

  void _startBatchTimer() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(batchInterval, (_) => _sendBatch());
  }

  @override
  Future<void> write(LogEntry entry) async {
    _buffer.add(entry);
    
    if (_buffer.length >= batchSize && !_isSending) {
      await _sendBatch();
    }
  }

  @override
  Future<void> writeBatch(List<LogEntry> entries) async {
    _buffer.addAll(entries);
    
    if (_buffer.length >= batchSize && !_isSending) {
      await _sendBatch();
    }
  }

  Future<void> _sendBatch() async {
    if (_buffer.isEmpty || _isSending) return;
    
    _isSending = true;
    final entriesToSend = List<LogEntry>.from(_buffer);
    _buffer.clear();

    try {
      await _sendWithRetry(entriesToSend);
    } catch (e, stackTrace) {
      // Add entries back to buffer on failure
      _buffer.insertAll(0, entriesToSend);
      onError?.call(e, stackTrace);
    } finally {
      _isSending = false;
    }
  }

  Future<void> _sendWithRetry(List<LogEntry> entries) async {
    final payload = {
      'logs': entries.map((e) => e.toJson()).toList(),
      'timestamp': DateTime.now().toIso8601String(),
      'count': entries.length,
    };

    final body = jsonEncode(payload);
    final finalBody = compress ? gzip.encode(utf8.encode(body)) : utf8.encode(body);

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            if (compress) 'Content-Encoding': 'gzip',
            ...?headers,
          },
          body: finalBody,
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return; // Success
        }

        // Server error, might be temporary
        if (response.statusCode >= 500 && attempt < maxRetries) {
          await Future.delayed(retryDelay * (attempt + 1));
          continue;
        }

        throw HttpException(
          'Failed to send logs: ${response.statusCode} ${response.body}',
          response.statusCode,
        );
      } catch (e) {
        if (attempt == maxRetries) {
          rethrow;
        }
        await Future.delayed(retryDelay * (attempt + 1));
      }
    }
  }

  @override
  Future<void> flush() async {
    if (_buffer.isNotEmpty) {
      await _sendBatch();
    }
  }

  @override
  Future<void> close() async {
    _batchTimer?.cancel();
    await flush();
  }
}

class HttpException implements Exception {
  final String message;
  final int statusCode;

  HttpException(this.message, this.statusCode);

  @override
  String toString() => 'HttpException: $message (Status: $statusCode)';
}

class HttpBatchConfig {
  final String endpoint;
  final Map<String, String>? headers;
  final Map<String, String>? queryParams;
  final Duration timeout;
  final bool enableCompression;
  final String? apiKey;
  final String? bearerToken;

  const HttpBatchConfig({
    required this.endpoint,
    this.headers,
    this.queryParams,
    this.timeout = const Duration(seconds: 30),
    this.enableCompression = true,
    this.apiKey,
    this.bearerToken,
  });

  Map<String, String> buildHeaders() {
    final built = <String, String>{
      'Content-Type': 'application/json',
      if (enableCompression) 'Content-Encoding': 'gzip',
      ...?headers,
    };

    if (apiKey != null) {
      built['X-API-Key'] = apiKey!;
    }

    if (bearerToken != null) {
      built['Authorization'] = 'Bearer $bearerToken';
    }

    return built;
  }

  Uri buildUri() {
    final uri = Uri.parse(endpoint);
    if (queryParams != null && queryParams!.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    return uri;
  }
}
import 'dart:async' as async;
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'logger.dart';
import 'core/log_level.dart';

typedef ErrorCallback = void Function(Object error, StackTrace stackTrace);

class CrashHandler {
  static Logger? _logger;
  static ErrorCallback? _onError;
  static bool _isInitialized = false;
  static final List<Map<String, dynamic>> _errorHistory = [];
  static const int _maxErrorHistory = 100;

  static void initialize({
    Logger? logger,
    ErrorCallback? onError,
    bool handleFlutterErrors = true,
    bool handleIsolateErrors = true,
    bool handlePlatformErrors = true,
  }) {
    if (_isInitialized) return;
    
    _logger = logger ?? Logger.getLogger('CrashHandler');
    _onError = onError;
    _isInitialized = true;

    if (handleFlutterErrors) {
      _setupFlutterErrorHandler();
    }

    if (handleIsolateErrors) {
      _setupIsolateErrorHandler();
    }

    if (handlePlatformErrors && !kIsWeb) {
      _setupPlatformErrorHandler();
    }
  }

  static void _setupFlutterErrorHandler() {
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleError(
        details.exception,
        details.stack ?? StackTrace.current,
        additionalInfo: {
          'library': details.library,
          'context': details.context?.toString(),
          'informationCollector': details.informationCollector != null
              ? _collectInformation(details.informationCollector!)
              : null,
          'silent': details.silent,
        },
      );

      // Call the original handler if needed
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };
  }

  static String _collectInformation(InformationCollector collector) {
    final information = <DiagnosticsNode>[];
    collector();
    return information.map((node) => node.toString()).join('\n');
  }

  static void _setupIsolateErrorHandler() {
    Isolate.current.addErrorListener(RawReceivePort((pair) async {
      final List<dynamic> errorAndStacktrace = pair as List<dynamic>;
      _handleError(
        errorAndStacktrace.first,
        errorAndStacktrace.last as StackTrace,
        additionalInfo: {
          'isolate': Isolate.current.debugName ?? 'unnamed',
          'type': 'isolate_error',
        },
      );
    }).sendPort);
  }

  static void _setupPlatformErrorHandler() {
    // Platform errors are handled through PlatformDispatcher in newer Flutter versions
    PlatformDispatcher.instance.onError = (error, stack) {
      _handleError(
        error,
        stack,
        additionalInfo: {
          'type': 'platform_error',
        },
      );
      return true; // Handled
    };
  }

  static void _handleError(
    Object error,
    StackTrace stackTrace, {
    Map<String, dynamic>? additionalInfo,
  }) {
    final errorInfo = {
      'timestamp': DateTime.now().toIso8601String(),
      'error': error.toString(),
      'stackTrace': stackTrace.toString(),
      'errorType': error.runtimeType.toString(),
      ...?additionalInfo,
    };

    // Add to error history
    _errorHistory.add(errorInfo);
    if (_errorHistory.length > _maxErrorHistory) {
      _errorHistory.removeAt(0);
    }

    // Log the error
    _logger?.log(
      LogLevel.error,
      'Unhandled error: ${error.toString()}',
      error: error,
      stackTrace: stackTrace,
      metadata: {
        'crash_handler': true,
        'error_type': error.runtimeType.toString(),
        ...?additionalInfo,
      },
      tags: ['crash', 'unhandled_error'],
    );

    // Call custom error handler
    _onError?.call(error, stackTrace);
  }

  static void recordError(
    Object error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? metadata,
    bool fatal = false,
  }) {
    _handleError(
      error,
      stackTrace ?? StackTrace.current,
      additionalInfo: {
        'recorded': true,
        'fatal': fatal,
        ...?metadata,
      },
    );

    if (fatal) {
      _logger?.fatal(
        'Fatal error recorded: ${error.toString()}',
        error: error,
        stackTrace: stackTrace,
        metadata: metadata,
        tags: ['crash', 'fatal_error'],
      );
    }
  }

  static List<Map<String, dynamic>> getErrorHistory() {
    return List.unmodifiable(_errorHistory);
  }

  static void clearErrorHistory() {
    _errorHistory.clear();
  }

  static Future<T> runGuarded<T>(
    Future<T> Function() body, {
    ErrorCallback? onError,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      return await body();
    } catch (error, stackTrace) {
      _handleError(
        error,
        stackTrace,
        additionalInfo: {
          'guarded_execution': true,
          ...?metadata,
        },
      );
      onError?.call(error, stackTrace);
      rethrow;
    }
  }

  static T runGuardedSync<T>(
    T Function() body, {
    ErrorCallback? onError,
    Map<String, dynamic>? metadata,
  }) {
    try {
      return body();
    } catch (error, stackTrace) {
      _handleError(
        error,
        stackTrace,
        additionalInfo: {
          'guarded_sync_execution': true,
          ...?metadata,
        },
      );
      onError?.call(error, stackTrace);
      rethrow;
    }
  }

  static void runZonedGuarded(
    void Function() body, {
    ErrorCallback? onError,
    Map<String, dynamic>? zoneValues,
  }) {
    async.runZonedGuarded<void>(
      body,
      (error, stack) {
        _handleError(
          error,
          stack,
          additionalInfo: {
            'zoned_guarded': true,
            'zone_values': zoneValues,
          },
        );
        onError?.call(error, stack);
      },
      zoneValues: zoneValues,
    );
  }
}
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:stack_trace/stack_trace.dart';
import 'core/log_entry.dart';
import 'core/log_level.dart';
import 'core/log_filter.dart';
import 'outputs/log_output.dart';
import 'outputs/console_output.dart';
import 'utils/device_info_provider.dart';

class Logger {
  final String name;
  final List<LogOutput> outputs;
  final List<LogFilter> filters;
  final LogLevel minimumLevel;
  final Map<String, dynamic>? defaultMetadata;
  final List<String>? defaultTags;
  final bool captureStackTrace;
  final int stackTraceLevel;
  
  static final Map<String, Logger> _loggers = {};
  static DeviceInfoProvider? _deviceInfoProvider;
  static String? _sessionId;
  static String? _userId;
  static final Map<String, dynamic> _globalContext = {};

  Logger._({
    required this.name,
    required this.outputs,
    required this.filters,
    required this.minimumLevel,
    this.defaultMetadata,
    this.defaultTags,
    this.captureStackTrace = true,
    this.stackTraceLevel = 3,
  });

  factory Logger({
    String name = 'default',
    List<LogOutput>? outputs,
    List<LogFilter>? filters,
    LogLevel minimumLevel = LogLevel.verbose,
    Map<String, dynamic>? defaultMetadata,
    List<String>? defaultTags,
    bool captureStackTrace = true,
    int stackTraceLevel = 3,
  }) {
    if (_loggers.containsKey(name)) {
      return _loggers[name]!;
    }

    final logger = Logger._(
      name: name,
      outputs: outputs ?? [ConsoleOutput()],
      filters: filters ?? [],
      minimumLevel: minimumLevel,
      defaultMetadata: defaultMetadata,
      defaultTags: defaultTags,
      captureStackTrace: captureStackTrace,
      stackTraceLevel: stackTraceLevel,
    );

    _loggers[name] = logger;
    return logger;
  }

  static Future<void> initialize({
    DeviceInfoProvider? deviceInfoProvider,
    String? sessionId,
  }) async {
    _deviceInfoProvider = deviceInfoProvider ?? DeviceInfoProvider();
    await _deviceInfoProvider!.initialize();
    _sessionId = sessionId ?? DateTime.now().millisecondsSinceEpoch.toString();
  }

  static void setUserId(String? userId) {
    _userId = userId;
  }

  static void setGlobalContext(Map<String, dynamic> context) {
    _globalContext.clear();
    _globalContext.addAll(context);
  }

  static void addGlobalContext(String key, dynamic value) {
    _globalContext[key] = value;
  }

  static void removeGlobalContext(String key) {
    _globalContext.remove(key);
  }

  static Logger getLogger(String name) {
    return _loggers[name] ?? Logger(name: name);
  }

  static Future<void> closeAll() async {
    for (final logger in _loggers.values) {
      await logger.close();
    }
    _loggers.clear();
  }

  void verbose(
    dynamic message, {
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
    List<String>? tags,
  }) {
    log(LogLevel.verbose, message, 
        metadata: metadata, error: error, stackTrace: stackTrace, tags: tags);
  }

  void debug(
    dynamic message, {
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
    List<String>? tags,
  }) {
    log(LogLevel.debug, message, 
        metadata: metadata, error: error, stackTrace: stackTrace, tags: tags);
  }

  void info(
    dynamic message, {
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
    List<String>? tags,
  }) {
    log(LogLevel.info, message, 
        metadata: metadata, error: error, stackTrace: stackTrace, tags: tags);
  }

  void warning(
    dynamic message, {
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
    List<String>? tags,
  }) {
    log(LogLevel.warning, message, 
        metadata: metadata, error: error, stackTrace: stackTrace, tags: tags);
  }

  void error(
    dynamic message, {
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
    List<String>? tags,
  }) {
    log(LogLevel.error, message, 
        metadata: metadata, error: error, stackTrace: stackTrace, tags: tags);
  }

  void critical(
    dynamic message, {
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
    List<String>? tags,
  }) {
    log(LogLevel.critical, message, 
        metadata: metadata, error: error, stackTrace: stackTrace, tags: tags);
  }

  void fatal(
    dynamic message, {
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
    List<String>? tags,
  }) {
    log(LogLevel.fatal, message, 
        metadata: metadata, error: error, stackTrace: stackTrace, tags: tags);
  }

  void log(
    LogLevel level,
    dynamic message, {
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
    List<String>? tags,
  }) {
    if (level < minimumLevel) return;

    final entry = _createLogEntry(
      level: level,
      message: message.toString(),
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
      tags: tags,
    );

    // Apply filters
    for (final filter in filters) {
      if (!filter.shouldLog(entry)) return;
    }

    // Write to outputs
    for (final output in outputs) {
      output.write(entry).catchError((e, stack) {
        if (kDebugMode) {
          print('Error writing to output: $e\n$stack');
        }
      });
    }
  }

  LogEntry _createLogEntry({
    required LogLevel level,
    required String message,
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
    List<String>? tags,
  }) {
    final combinedMetadata = <String, dynamic>{};
    if (defaultMetadata != null) {
      combinedMetadata.addAll(defaultMetadata!);
    }
    if (metadata != null) {
      combinedMetadata.addAll(metadata);
    }

    final combinedTags = <String>{};
    if (defaultTags != null) {
      combinedTags.addAll(defaultTags!);
    }
    if (tags != null) {
      combinedTags.addAll(tags);
    }

    String? capturedStackTrace;
    if (captureStackTrace && level.value >= stackTraceLevel) {
      if (stackTrace != null) {
        capturedStackTrace = stackTrace.toString();
      } else if (error != null) {
        capturedStackTrace = StackTrace.current.toString();
      }
    }

    final deviceInfo = _deviceInfoProvider?.deviceInfo;

    return LogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      level: level,
      message: message,
      logger: name,
      metadata: combinedMetadata.isEmpty ? null : combinedMetadata,
      stackTrace: capturedStackTrace,
      error: error?.toString(),
      deviceId: deviceInfo?.deviceId,
      userId: _userId,
      sessionId: _sessionId,
      platform: deviceInfo?.platform,
      appVersion: deviceInfo?.appVersion,
      buildNumber: deviceInfo?.buildNumber,
      context: Map<String, dynamic>.from(_globalContext),
      tags: combinedTags.isEmpty ? null : combinedTags.toList(),
      threadName: Isolate.current.debugName,
      processId: null, // Process ID not easily available in Flutter
    );
  }

  Future<void> flush() async {
    await Future.wait(
      outputs.map((output) => output.flush()),
      eagerError: false,
    );
  }

  Future<void> close() async {
    await Future.wait(
      outputs.map((output) => output.close()),
      eagerError: false,
    );
  }

  T measure<T>(
    String operation,
    T Function() function, {
    Map<String, dynamic>? metadata,
    LogLevel? successLevel,
    LogLevel? errorLevel,
  }) {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = function();
      stopwatch.stop();
      
      log(
        successLevel ?? LogLevel.debug,
        'Operation "$operation" completed',
        metadata: {
          ...?metadata,
          'duration_ms': stopwatch.elapsedMilliseconds,
          'success': true,
        },
      );
      
      return result;
    } catch (e, stack) {
      stopwatch.stop();
      
      log(
        errorLevel ?? LogLevel.error,
        'Operation "$operation" failed',
        metadata: {
          ...?metadata,
          'duration_ms': stopwatch.elapsedMilliseconds,
          'success': false,
        },
        error: e,
        stackTrace: stack,
      );
      
      rethrow;
    }
  }

  Future<T> measureAsync<T>(
    String operation,
    Future<T> Function() function, {
    Map<String, dynamic>? metadata,
    LogLevel? successLevel,
    LogLevel? errorLevel,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await function();
      stopwatch.stop();
      
      log(
        successLevel ?? LogLevel.debug,
        'Async operation "$operation" completed',
        metadata: {
          ...?metadata,
          'duration_ms': stopwatch.elapsedMilliseconds,
          'success': true,
        },
      );
      
      return result;
    } catch (e, stack) {
      stopwatch.stop();
      
      log(
        errorLevel ?? LogLevel.error,
        'Async operation "$operation" failed',
        metadata: {
          ...?metadata,
          'duration_ms': stopwatch.elapsedMilliseconds,
          'success': false,
        },
        error: e,
        stackTrace: stack,
      );
      
      rethrow;
    }
  }
}
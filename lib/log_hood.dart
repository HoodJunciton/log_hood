
// Core exports
export 'src/core/log_level.dart';
export 'src/core/log_entry.dart';
export 'src/core/log_filter.dart';

// Logger
export 'src/logger.dart';

// Formatters
export 'src/formatters/log_formatter.dart';
export 'src/formatters/expandable_formatter.dart';

// Network
export 'src/network/http_interceptor.dart';
// Dio interceptor is not exported here - users must import it directly if they have dio dependency

// Outputs
export 'src/outputs/log_output.dart';
export 'src/outputs/console_output.dart';
export 'src/outputs/file_output.dart';
export 'src/outputs/http_output.dart';
export 'src/outputs/database_output.dart';

// Utilities
export 'src/utils/device_info_provider.dart';
export 'src/crash_handler.dart';
export 'src/monitors/performance_monitor.dart';

// Main LogHood class for easy initialization
import 'src/logger.dart';
import 'src/crash_handler.dart';
import 'src/outputs/console_output.dart';
import 'src/outputs/file_output.dart';
import 'src/outputs/http_output.dart';
import 'src/outputs/database_output.dart';
import 'src/outputs/log_output.dart';
import 'src/core/log_level.dart';
import 'src/formatters/log_formatter.dart';

class LogHood {
  static Logger? _defaultLogger;
  static bool _initialized = false;

  static Future<void> initialize({
    String? sessionId,
    LogLevel minimumLevel = LogLevel.verbose,
    List<LogOutput>? outputs,
    bool enableConsoleOutput = true,
    bool enableFileOutput = true,
    bool enableDatabaseOutput = false,
    String? httpEndpoint,
    bool enableCrashHandler = true,
    bool enablePerformanceMonitoring = false,
  }) async {
    if (_initialized) return;

    // Initialize logger
    await Logger.initialize(sessionId: sessionId);

    // Setup outputs
    final logOutputs = outputs ?? [];
    
    if (enableConsoleOutput) {
      logOutputs.add(ConsoleOutput(
        formatter: DetailedFormatter(),
        useColors: true,
      ));
    }
    
    if (enableFileOutput) {
      logOutputs.add(FileOutput(
        fileName: 'app',
        formatter: JsonFormatter(),
        maxFileSize: 10 * 1024 * 1024, // 10MB
        maxFiles: 5,
      ));
    }
    
    if (enableDatabaseOutput) {
      logOutputs.add(DatabaseOutput());
    }
    
    if (httpEndpoint != null) {
      logOutputs.add(HttpOutput(
        endpoint: httpEndpoint,
        batchInterval: const Duration(seconds: 30),
        batchSize: 100,
      ));
    }

    // Create default logger
    _defaultLogger = Logger(
      name: 'App',
      outputs: logOutputs,
      minimumLevel: minimumLevel,
    );

    // Initialize crash handler
    if (enableCrashHandler) {
      CrashHandler.initialize(
        logger: _defaultLogger,
        handleFlutterErrors: true,
        handleIsolateErrors: true,
        handlePlatformErrors: true,
      );
    }

    _initialized = true;
  }

  static Logger get logger {
    if (!_initialized || _defaultLogger == null) {
      throw StateError('LogHood not initialized. Call LogHood.initialize() first.');
    }
    return _defaultLogger!;
  }

  static void setUserId(String? userId) {
    Logger.setUserId(userId);
  }

  static void setGlobalContext(Map<String, dynamic> context) {
    Logger.setGlobalContext(context);
  }

  static void addGlobalContext(String key, dynamic value) {
    Logger.addGlobalContext(key, value);
  }

  static Logger getLogger(String name) {
    return Logger.getLogger(name);
  }

  static Future<void> close() async {
    await Logger.closeAll();
    _initialized = false;
    _defaultLogger = null;
  }

  // Convenience methods
  static void v(dynamic message, {Map<String, dynamic>? metadata, List<String>? tags}) {
    logger.verbose(message, metadata: metadata, tags: tags);
  }

  static void d(dynamic message, {Map<String, dynamic>? metadata, List<String>? tags}) {
    logger.debug(message, metadata: metadata, tags: tags);
  }

  static void i(dynamic message, {Map<String, dynamic>? metadata, List<String>? tags}) {
    logger.info(message, metadata: metadata, tags: tags);
  }

  static void w(dynamic message, {Map<String, dynamic>? metadata, List<String>? tags}) {
    logger.warning(message, metadata: metadata, tags: tags);
  }

  static void e(dynamic message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? metadata, List<String>? tags}) {
    logger.error(message, error: error, stackTrace: stackTrace, metadata: metadata, tags: tags);
  }

  static void c(dynamic message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? metadata, List<String>? tags}) {
    logger.critical(message, error: error, stackTrace: stackTrace, metadata: metadata, tags: tags);
  }

  static void f(dynamic message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? metadata, List<String>? tags}) {
    logger.fatal(message, error: error, stackTrace: stackTrace, metadata: metadata, tags: tags);
  }
}

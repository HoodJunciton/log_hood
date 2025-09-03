import 'package:flutter_test/flutter_test.dart';
import 'package:log_hood/log_hood.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LogHood complete integration test', () async {
    // Initialize LogHood
    await LogHood.initialize(
      minimumLevel: LogLevel.verbose,
      enableConsoleOutput: true,
      enableFileOutput: false, // Disable file output for tests
      enableDatabaseOutput: false,
      enableCrashHandler: true,
    );

    // Set global context
    LogHood.setGlobalContext({
      'test': true,
      'environment': 'testing',
    });
    
    // Set user ID
    LogHood.setUserId('test_user_123');
    
    // Test all log levels
    expect(() => LogHood.v('Verbose message'), returnsNormally);
    expect(() => LogHood.d('Debug message'), returnsNormally);
    expect(() => LogHood.i('Info message'), returnsNormally);
    expect(() => LogHood.w('Warning message'), returnsNormally);
    expect(() => LogHood.e('Error message'), returnsNormally);
    expect(() => LogHood.c('Critical message'), returnsNormally);
    expect(() => LogHood.f('Fatal message'), returnsNormally);
    
    // Test with metadata and tags
    expect(() => LogHood.i('With metadata', 
      metadata: {'key': 'value', 'number': 42}
    ), returnsNormally);
    
    expect(() => LogHood.i('With tags', 
      tags: ['important', 'test']
    ), returnsNormally);
    
    // Test error logging
    final error = Exception('Test error');
    final stackTrace = StackTrace.current;
    expect(() => LogHood.e('Error occurred', 
      error: error, 
      stackTrace: stackTrace
    ), returnsNormally);
    
    // Test named loggers
    final customLogger = LogHood.getLogger('CustomLogger');
    expect(customLogger.name, equals('CustomLogger'));
    expect(() => customLogger.info('Custom logger message'), returnsNormally);
    
    // Test filters
    final filteredLogger = Logger(
      name: 'FilteredLogger',
      outputs: [ConsoleOutput()],
      minimumLevel: LogLevel.warning,
    );
    
    // These should not log (below minimum level)
    filteredLogger.verbose('Should not appear');
    filteredLogger.debug('Should not appear');
    filteredLogger.info('Should not appear');
    
    // These should log
    expect(() => filteredLogger.warning('Should appear'), returnsNormally);
    expect(() => filteredLogger.error('Should appear'), returnsNormally);
    
    // Test log entry creation
    final entry = LogEntry(
      id: 'test-id',
      timestamp: DateTime.now(),
      level: LogLevel.info,
      message: 'Test entry',
      logger: 'TestLogger',
      metadata: {'test': true},
      tags: ['test'],
      userId: 'user123',
      sessionId: 'session456',
    );
    
    expect(entry.id, equals('test-id'));
    expect(entry.level, equals(LogLevel.info));
    expect(entry.message, equals('Test entry'));
    expect(entry.metadata, equals({'test': true}));
    expect(entry.tags, equals(['test']));
    
    // Test JSON serialization
    final json = entry.toJson();
    expect(json['id'], equals('test-id'));
    expect(json['level'], equals('INFO'));
    expect(json['message'], equals('Test entry'));
    
    // Test formatters
    final simpleFormatter = SimpleFormatter();
    final jsonFormatter = JsonFormatter();
    final compactFormatter = CompactFormatter();
    final detailedFormatter = DetailedFormatter();
    final csvFormatter = CsvFormatter();
    
    final formatted = simpleFormatter.format(entry);
    expect(formatted, contains('Test entry'));
    expect(formatted, contains('[INFO]'));
    
    final jsonFormatted = jsonFormatter.format(entry);
    expect(jsonFormatted, contains('"message":"Test entry"'));
    
    final compactFormatted = compactFormatter.format(entry);
    expect(compactFormatted, equals('I|Test entry'));
    
    final detailedFormatted = detailedFormatter.format(entry);
    expect(detailedFormatted, contains('┌─'));
    expect(detailedFormatted, contains('Test entry'));
    expect(detailedFormatted, contains('└─'));
    
    final csvFormatted = csvFormatter.format(entry);
    expect(csvFormatted.split(',').length, greaterThan(5));
    
    // Test filters
    final levelFilter = LevelFilter(minLevel: LogLevel.warning);
    expect(levelFilter.shouldLog(entry), isFalse); // INFO < WARNING
    
    final warningEntry = entry.copyWith(level: LogLevel.warning);
    expect(levelFilter.shouldLog(warningEntry), isTrue);
    
    final tagFilter = TagFilter(allowedTags: ['test']);
    expect(tagFilter.shouldLog(entry), isTrue);
    
    final noTagEntry = entry.copyWith(tags: []);
    expect(tagFilter.shouldLog(noTagEntry), isFalse);
    
    // Test crash handler
    CrashHandler.initialize(logger: LogHood.logger);
    
    CrashHandler.recordError(
      Exception('Test crash'),
      StackTrace.current,
      metadata: {'test': true},
    );
    
    final errorHistory = CrashHandler.getErrorHistory();
    expect(errorHistory.length, greaterThan(0));
    expect(errorHistory.last['error'], contains('Test crash'));
    
    // Clean up
    await LogHood.close();
  });

  test('LogHood performance features', () async {
    await LogHood.initialize(
      enableConsoleOutput: true,
      enableFileOutput: false,
    );
    
    final logger = LogHood.logger;
    
    // Test operation measurement
    final result = logger.measure(
      'calculation',
      () {
        int sum = 0;
        for (int i = 0; i < 1000; i++) {
          sum += i;
        }
        return sum;
      },
    );
    
    expect(result, equals(499500));
    
    // Test async measurement
    final asyncResult = await logger.measureAsync(
      'async_operation',
      () async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 'done';
      },
    );
    
    expect(asyncResult, equals('done'));
    
    // Test performance monitor
    final perfMonitor = PerformanceMonitor(
      logger: logger,
      sampleInterval: const Duration(seconds: 1),
    );
    
    perfMonitor.startMonitoring();
    await Future.delayed(const Duration(milliseconds: 100));
    
    final stats = perfMonitor.getCurrentStats();
    expect(stats, isA<Map<String, dynamic>>());
    
    perfMonitor.stopMonitoring();
    
    await LogHood.close();
  });
}
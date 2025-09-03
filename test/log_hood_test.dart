import 'package:flutter_test/flutter_test.dart';
import 'package:log_hood/log_hood.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('LogHood Initialization', () {
    tearDown(() async {
      await LogHood.close();
    });

    test('initializes with default settings', () async {
      await LogHood.initialize();
      
      expect(() => LogHood.logger, returnsNormally);
      expect(LogHood.logger, isNotNull);
    });

    test('initializes with custom settings', () async {
      await LogHood.initialize(
        minimumLevel: LogLevel.info,
        enableConsoleOutput: true,
        enableFileOutput: false,
        enableDatabaseOutput: false,
        httpEndpoint: 'https://test.com/logs',
      );
      
      expect(() => LogHood.logger, returnsNormally);
    });

    test('prevents double initialization', () async {
      await LogHood.initialize();
      await LogHood.initialize(); // Should not throw
      
      expect(() => LogHood.logger, returnsNormally);
    });

    test('throws when accessing logger before initialization', () async {
      await LogHood.close();
      
      expect(() => LogHood.logger, throwsStateError);
    });
  });

  group('Global Context', () {
    setUpAll(() async {
      await LogHood.initialize();
    });

    tearDownAll(() async {
      await LogHood.close();
    });

    test('sets and updates global context', () {
      LogHood.setGlobalContext({
        'environment': 'test',
        'version': '1.0.0',
      });
      
      LogHood.addGlobalContext('feature', 'logging');
      
      // Context is applied to logs (would need to verify through output)
      expect(() => LogHood.i('Test message'), returnsNormally);
    });

    test('sets user ID', () {
      LogHood.setUserId('test_user_123');
      
      expect(() => LogHood.i('User action'), returnsNormally);
    });
  });

  group('Convenience Logging Methods', () {
    setUpAll(() async {
      await LogHood.initialize();
    });

    tearDownAll(() async {
      await LogHood.close();
    });

    test('logs with all convenience methods', () {
      expect(() => LogHood.v('Verbose message'), returnsNormally);
      expect(() => LogHood.d('Debug message'), returnsNormally);
      expect(() => LogHood.i('Info message'), returnsNormally);
      expect(() => LogHood.w('Warning message'), returnsNormally);
      expect(() => LogHood.e('Error message'), returnsNormally);
      expect(() => LogHood.c('Critical message'), returnsNormally);
      expect(() => LogHood.f('Fatal message'), returnsNormally);
    });

    test('logs with metadata', () {
      expect(
        () => LogHood.i('Test', metadata: {'key': 'value'}),
        returnsNormally,
      );
    });

    test('logs with tags', () {
      expect(
        () => LogHood.i('Test', tags: ['test', 'unit']),
        returnsNormally,
      );
    });

    test('logs with error and stack trace', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;
      
      expect(
        () => LogHood.e('Error occurred', 
          error: error, 
          stackTrace: stackTrace
        ),
        returnsNormally,
      );
    });
  });

  group('Named Loggers', () {
    setUpAll(() async {
      await LogHood.initialize();
    });

    tearDownAll(() async {
      await LogHood.close();
    });

    test('creates and retrieves named logger', () {
      final logger1 = LogHood.getLogger('TestLogger');
      final logger2 = LogHood.getLogger('TestLogger');
      
      expect(logger1, same(logger2));
      expect(logger1.name, equals('TestLogger'));
    });

    test('named logger logs messages', () {
      final logger = LogHood.getLogger('TestLogger');
      
      expect(() => logger.info('Test message'), returnsNormally);
      expect(() => logger.error('Error message'), returnsNormally);
    });
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:log_hood/log_hood.dart';
import 'outputs/mock_output.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Logger', () {
    setUp(() async {
      await Logger.initialize();
    });

    tearDown(() async {
      await Logger.closeAll();
    });

    test('creates logger with default settings', () {
      final logger = Logger(name: 'TestLogger');
      
      expect(logger.name, equals('TestLogger'));
      expect(logger.minimumLevel, equals(LogLevel.verbose));
      expect(logger.outputs.length, equals(1)); // Default console output
    });

    test('creates logger with custom settings', () {
      final mockOutput = MockOutput();
      final logger = Logger(
        name: 'CustomLogger',
        outputs: [mockOutput],
        minimumLevel: LogLevel.warning,
        defaultMetadata: {'source': 'test'},
        defaultTags: ['test'],
      );
      
      expect(logger.name, equals('CustomLogger'));
      expect(logger.outputs.length, equals(1));
      expect(logger.minimumLevel, equals(LogLevel.warning));
    });

    test('returns same instance for same name', () {
      final logger1 = Logger(name: 'SingletonLogger');
      final logger2 = Logger(name: 'SingletonLogger');
      
      expect(identical(logger1, logger2), isTrue);
    });

    test('respects minimum log level', () async {
      final mockOutput = MockOutput();
      final logger = Logger(
        name: 'LevelLogger',
        outputs: [mockOutput],
        minimumLevel: LogLevel.warning,
      );
      
      logger.verbose('Verbose message');
      logger.debug('Debug message');
      logger.info('Info message');
      logger.warning('Warning message');
      logger.error('Error message');
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      expect(mockOutput.writtenEntries.length, equals(2));
      expect(mockOutput.writtenEntries[0].level, equals(LogLevel.warning));
      expect(mockOutput.writtenEntries[1].level, equals(LogLevel.error));
    });

    test('applies filters', () async {
      final mockOutput = MockOutput();
      final logger = Logger(
        name: 'FilterLogger',
        outputs: [mockOutput],
        filters: [
          TagFilter(allowedTags: ['important']),
        ],
      );
      
      logger.info('Not important', tags: ['other']);
      logger.info('Important message', tags: ['important']);
      logger.info('Also important', tags: ['important', 'other']);
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      expect(mockOutput.writtenEntries.length, equals(2));
      expect(mockOutput.writtenEntries[0].message, equals('Important message'));
      expect(mockOutput.writtenEntries[1].message, equals('Also important'));
    });

    test('includes default metadata and tags', () async {
      final mockOutput = MockOutput();
      final logger = Logger(
        name: 'DefaultsLogger',
        outputs: [mockOutput],
        defaultMetadata: {'app': 'test-app'},
        defaultTags: ['default'],
      );
      
      logger.info('Test message', 
        metadata: {'custom': 'value'},
        tags: ['custom'],
      );
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      final entry = mockOutput.writtenEntries.first;
      expect(entry.metadata, equals({
        'app': 'test-app',
        'custom': 'value',
      }));
      expect(entry.tags, containsAll(['default', 'custom']));
    });

    test('captures stack trace for high level logs', () async {
      final mockOutput = MockOutput();
      final logger = Logger(
        name: 'StackLogger',
        outputs: [mockOutput],
        captureStackTrace: true,
        stackTraceLevel: 4, // Error and above
      );
      
      logger.info('Info - no stack');
      logger.error('Error - with stack');
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      expect(mockOutput.writtenEntries[0].stackTrace, isNull);
      expect(mockOutput.writtenEntries[1].stackTrace, isNotNull);
    });

    test('logs with all convenience methods', () async {
      final mockOutput = MockOutput();
      final logger = Logger(
        name: 'ConvenienceLogger',
        outputs: [mockOutput],
        minimumLevel: LogLevel.verbose,
      );
      
      logger.verbose('Verbose');
      logger.debug('Debug');
      logger.info('Info');
      logger.warning('Warning');
      logger.error('Error');
      logger.critical('Critical');
      logger.fatal('Fatal');
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      expect(mockOutput.writtenEntries.length, equals(7));
      expect(mockOutput.writtenEntries[0].level, equals(LogLevel.verbose));
      expect(mockOutput.writtenEntries[1].level, equals(LogLevel.debug));
      expect(mockOutput.writtenEntries[2].level, equals(LogLevel.info));
      expect(mockOutput.writtenEntries[3].level, equals(LogLevel.warning));
      expect(mockOutput.writtenEntries[4].level, equals(LogLevel.error));
      expect(mockOutput.writtenEntries[5].level, equals(LogLevel.critical));
      expect(mockOutput.writtenEntries[6].level, equals(LogLevel.fatal));
    });

    test('measures synchronous operations', () {
      final mockOutput = MockOutput();
      final logger = Logger(
        name: 'MeasureLogger',
        outputs: [mockOutput],
      );
      
      final result = logger.measure(
        'test_operation',
        () {
          // Simulate work
          final sum = List.generate(1000, (i) => i).reduce((a, b) => a + b);
          return sum;
        },
        metadata: {'type': 'calculation'},
      );
      
      expect(result, equals(499500)); // Sum of 0 to 999
      
      // Check that operation was logged
      expect(mockOutput.writtenEntries.length, equals(1));
      final entry = mockOutput.writtenEntries.first;
      expect(entry.message, contains('Operation "test_operation" completed'));
      expect(entry.metadata?['duration_ms'], isNotNull);
      expect(entry.metadata?['success'], isTrue);
      expect(entry.metadata?['type'], equals('calculation'));
    });

    test('measures async operations', () async {
      final mockOutput = MockOutput();
      final logger = Logger(
        name: 'AsyncMeasureLogger',
        outputs: [mockOutput],
      );
      
      final result = await logger.measureAsync(
        'async_operation',
        () async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'completed';
        },
      );
      
      expect(result, equals('completed'));
      
      final entry = mockOutput.writtenEntries.first;
      expect(entry.message, contains('Async operation "async_operation" completed'));
      expect(entry.metadata?['duration_ms'], greaterThanOrEqualTo(50));
      expect(entry.metadata?['success'], isTrue);
    });

    test('logs failed operations', () async {
      final mockOutput = MockOutput();
      final logger = Logger(
        name: 'FailureLogger',
        outputs: [mockOutput],
      );
      
      expect(
        () => logger.measure(
          'failing_operation',
          () => throw Exception('Test failure'),
        ),
        throwsException,
      );
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      final entry = mockOutput.writtenEntries.first;
      expect(entry.level, equals(LogLevel.error));
      expect(entry.message, contains('Operation "failing_operation" failed'));
      expect(entry.metadata?['success'], isFalse);
      expect(entry.error, contains('Test failure'));
    });

    test('flushes all outputs', () async {
      final mockOutput1 = MockOutput();
      final mockOutput2 = MockOutput();
      final logger = Logger(
        name: 'FlushLogger',
        outputs: [mockOutput1, mockOutput2],
      );
      
      await logger.flush();
      
      expect(mockOutput1.isFlushed, isTrue);
      expect(mockOutput2.isFlushed, isTrue);
    });

    test('closes all outputs', () async {
      final mockOutput1 = MockOutput();
      final mockOutput2 = MockOutput();
      final logger = Logger(
        name: 'CloseLogger',
        outputs: [mockOutput1, mockOutput2],
      );
      
      await logger.close();
      
      expect(mockOutput1.isClosed, isTrue);
      expect(mockOutput2.isClosed, isTrue);
    });

    test('handles output errors gracefully', () async {
      final failingOutput = MockOutput()..shouldThrowOnWrite = true;
      final workingOutput = MockOutput();
      
      final logger = Logger(
        name: 'ErrorHandlingLogger',
        outputs: [failingOutput, workingOutput],
      );
      
      // Should not throw
      expect(() => logger.info('Test message'), returnsNormally);
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      // Working output should still receive the message
      expect(workingOutput.writtenEntries.length, equals(1));
      expect(failingOutput.writtenEntries.length, equals(0));
    });

    test('includes global context', () async {
      final mockOutput = MockOutput();
      
      Logger.setGlobalContext({'global': 'value'});
      Logger.addGlobalContext('additional', 'context');
      
      final logger = Logger(
        name: 'GlobalContextLogger',
        outputs: [mockOutput],
      );
      
      logger.info('Test message');
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      final entry = mockOutput.writtenEntries.first;
      expect(entry.context, equals({
        'global': 'value',
        'additional': 'context',
      }));
      
      Logger.removeGlobalContext('additional');
      logger.info('Second message');
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      final entry2 = mockOutput.writtenEntries[1];
      expect(entry2.context, equals({'global': 'value'}));
    });

    test('includes user ID and session ID', () async {
      final mockOutput = MockOutput();
      
      Logger.setUserId('user123');
      
      final logger = Logger(
        name: 'UserLogger',
        outputs: [mockOutput],
      );
      
      logger.info('User action');
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      final entry = mockOutput.writtenEntries.first;
      expect(entry.userId, equals('user123'));
      expect(entry.sessionId, isNotNull);
    });

    test('closeAll closes all loggers', () async {
      final outputs1 = [MockOutput(), MockOutput()];
      final outputs2 = [MockOutput()];
      
      Logger(name: 'Logger1', outputs: outputs1);
      Logger(name: 'Logger2', outputs: outputs2);
      
      await Logger.closeAll();
      
      for (final output in outputs1) {
        expect((output as MockOutput).isClosed, isTrue);
      }
      for (final output in outputs2) {
        expect((output as MockOutput).isClosed, isTrue);
      }
    });
  });
}
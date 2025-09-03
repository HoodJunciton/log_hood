import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:log_hood/log_hood.dart';
import 'outputs/mock_output.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CrashHandler', () {
    late MockOutput mockOutput;
    late Logger testLogger;

    setUp(() async {
      await Logger.initialize();
      mockOutput = MockOutput();
      testLogger = Logger(
        name: 'CrashLogger',
        outputs: [mockOutput],
      );
    });

    tearDown(() async {
      await Logger.closeAll();
    });

    test('initializes crash handler', () {
      expect(
        () => CrashHandler.initialize(logger: testLogger),
        returnsNormally,
      );
    });

    test('records errors manually', () async {
      CrashHandler.initialize(logger: testLogger);
      
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;
      
      CrashHandler.recordError(
        error,
        stackTrace,
        metadata: {'action': 'test'},
        fatal: false,
      );
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      expect(mockOutput.writtenEntries.length, equals(1));
      final entry = mockOutput.writtenEntries.first;
      expect(entry.level, equals(LogLevel.error));
      expect(entry.error, contains('Test error'));
      expect(entry.metadata?['recorded'], isTrue);
      expect(entry.metadata?['fatal'], isFalse);
      expect(entry.metadata?['action'], equals('test'));
    });

    test('records fatal errors', () async {
      CrashHandler.initialize(logger: testLogger);
      
      final error = Exception('Fatal error');
      
      CrashHandler.recordError(
        error,
        null,
        fatal: true,
      );
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      // Should log twice - once as error, once as fatal
      expect(mockOutput.writtenEntries.length, equals(2));
      
      final errorEntry = mockOutput.writtenEntries[0];
      expect(errorEntry.level, equals(LogLevel.error));
      
      final fatalEntry = mockOutput.writtenEntries[1];
      expect(fatalEntry.level, equals(LogLevel.fatal));
      expect(fatalEntry.message, contains('Fatal error recorded'));
    });

    test('maintains error history', () {
      CrashHandler.initialize(logger: testLogger);
      
      // Record multiple errors
      for (int i = 0; i < 5; i++) {
        CrashHandler.recordError(
          Exception('Error $i'),
          StackTrace.current,
        );
      }
      
      final history = CrashHandler.getErrorHistory();
      expect(history.length, equals(5));
      
      // Check errors are in order
      for (int i = 0; i < 5; i++) {
        expect(history[i]['error'], contains('Error $i'));
      }
    });

    test('limits error history size', () {
      CrashHandler.initialize(logger: testLogger);
      
      // Record more than max errors (100)
      for (int i = 0; i < 105; i++) {
        CrashHandler.recordError(
          Exception('Error $i'),
          StackTrace.current,
        );
      }
      
      final history = CrashHandler.getErrorHistory();
      expect(history.length, equals(100));
      
      // Should have kept the most recent errors
      expect(history.last['error'], contains('Error 104'));
    });

    test('clears error history', () {
      CrashHandler.initialize(logger: testLogger);
      
      CrashHandler.recordError(Exception('Error'), null);
      expect(CrashHandler.getErrorHistory().length, equals(1));
      
      CrashHandler.clearErrorHistory();
      expect(CrashHandler.getErrorHistory().length, equals(0));
    });

    test('runGuarded catches and logs errors', () async {
      CrashHandler.initialize(logger: testLogger);
      
      bool errorCallbackCalled = false;
      
      expect(
        () async => await CrashHandler.runGuarded(
          () async => throw Exception('Guarded error'),
          onError: (error, stackTrace) {
            errorCallbackCalled = true;
          },
          metadata: {'operation': 'test'},
        ),
        throwsException,
      );
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      expect(errorCallbackCalled, isTrue);
      expect(mockOutput.writtenEntries.length, equals(1));
      
      final entry = mockOutput.writtenEntries.first;
      expect(entry.error, contains('Guarded error'));
      expect(entry.metadata?['guarded_execution'], isTrue);
      expect(entry.metadata?['operation'], equals('test'));
    });

    test('runGuardedSync catches and logs errors', () async {
      CrashHandler.initialize(logger: testLogger);
      
      expect(
        () => CrashHandler.runGuardedSync(
          () => throw Exception('Sync error'),
        ),
        throwsException,
      );
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      expect(mockOutput.writtenEntries.length, equals(1));
      final entry = mockOutput.writtenEntries.first;
      expect(entry.error, contains('Sync error'));
      expect(entry.metadata?['guarded_sync_execution'], isTrue);
    });

    test('handles custom error callback', () async {
      bool customCallbackCalled = false;
      Object? capturedError;
      StackTrace? capturedStack;
      
      CrashHandler.initialize(
        logger: testLogger,
        onError: (error, stackTrace) {
          customCallbackCalled = true;
          capturedError = error;
          capturedStack = stackTrace;
        },
      );
      
      final testError = Exception('Callback test');
      final testStack = StackTrace.current;
      
      CrashHandler.recordError(testError, testStack);
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      expect(customCallbackCalled, isTrue);
      expect(capturedError.toString(), contains('Callback test'));
      expect(capturedStack, equals(testStack));
    });

    testWidgets('handles Flutter errors', (WidgetTester tester) async {
      CrashHandler.initialize(
        logger: testLogger,
        handleFlutterErrors: true,
      );
      
      // Trigger a Flutter error
      FlutterError.reportError(FlutterErrorDetails(
        exception: Exception('Flutter test error'),
        library: 'test library',
        context: ErrorDescription('test context'),
      ));
      
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 10));
      
      expect(mockOutput.writtenEntries.length, equals(1));
      final entry = mockOutput.writtenEntries.first;
      expect(entry.error, contains('Flutter test error'));
      expect(entry.metadata?['library'], equals('test library'));
      expect(entry.metadata?['context'], contains('test context'));
    });

    test('prevents double initialization', () {
      CrashHandler.initialize(logger: testLogger);
      
      // Second initialization should not throw
      expect(
        () => CrashHandler.initialize(logger: testLogger),
        returnsNormally,
      );
    });
  });
}
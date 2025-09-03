import 'package:flutter_test/flutter_test.dart';
import 'package:log_hood/log_hood.dart';
import 'dart:convert';

void main() {
  final testTimestamp = DateTime(2024, 1, 1, 12, 0);
  
  LogEntry createTestEntry({
    LogLevel level = LogLevel.info,
    String message = 'Test message',
    String? logger,
    Map<String, dynamic>? metadata,
    String? error,
    String? stackTrace,
    List<String>? tags,
  }) {
    return LogEntry(
      id: 'test-id',
      timestamp: testTimestamp,
      level: level,
      message: message,
      logger: logger,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
      tags: tags,
    );
  }

  group('SimpleFormatter', () {
    test('formats with all components', () {
      final formatter = SimpleFormatter();
      final entry = createTestEntry(logger: 'TestLogger');
      final formatted = formatter.format(entry);
      
      expect(formatted, contains('[2024-01-01T12:00:00.000]'));
      expect(formatted, contains('💡'));
      expect(formatted, contains('[INFO]'));
      expect(formatted, contains('[TestLogger]'));
      expect(formatted, contains('Test message'));
    });

    test('formats without optional components', () {
      final formatter = SimpleFormatter(
        includeTimestamp: false,
        includeLevel: false,
        includeLogger: false,
        includeEmoji: false,
      );
      final entry = createTestEntry(logger: 'TestLogger');
      final formatted = formatter.format(entry);
      
      expect(formatted, equals('Test message'));
    });

    test('formats without emoji', () {
      final formatter = SimpleFormatter(includeEmoji: false);
      final entry = createTestEntry();
      final formatted = formatter.format(entry);
      
      expect(formatted, isNot(contains('💡')));
      expect(formatted, contains('[INFO]'));
    });
  });

  group('JsonFormatter', () {
    test('formats as compact JSON', () {
      final formatter = JsonFormatter(pretty: false);
      final entry = createTestEntry(
        metadata: {'key': 'value'},
        tags: ['test'],
      );
      final formatted = formatter.format(entry);
      
      final json = jsonDecode(formatted);
      expect(json['id'], equals('test-id'));
      expect(json['level'], equals('INFO'));
      expect(json['message'], equals('Test message'));
      expect(json['metadata'], equals({'key': 'value'}));
      expect(json['tags'], equals(['test']));
    });

    test('formats as pretty JSON', () {
      final formatter = JsonFormatter(pretty: true);
      final entry = createTestEntry();
      final formatted = formatter.format(entry);
      
      expect(formatted, contains('\n'));
      expect(formatted, contains('  ')); // Indentation
      
      final json = jsonDecode(formatted);
      expect(json['message'], equals('Test message'));
    });
  });

  group('CompactFormatter', () {
    test('formats in compact style', () {
      final formatter = CompactFormatter();
      
      expect(formatter.format(createTestEntry(level: LogLevel.info)), 
             equals('I|Test message'));
      expect(formatter.format(createTestEntry(level: LogLevel.error)), 
             equals('E|Test message'));
      expect(formatter.format(createTestEntry(level: LogLevel.warning)), 
             equals('W|Test message'));
    });
  });

  group('DetailedFormatter', () {
    test('formats with all details', () {
      final formatter = DetailedFormatter();
      final entry = createTestEntry(
        logger: 'TestLogger',
        metadata: {'key': 'value', 'number': 42},
        tags: ['important', 'test'],
        error: 'Test error',
        stackTrace: 'Line 1\nLine 2',
      );
      
      final formatted = formatter.format(entry);
      
      // Header
      expect(formatted, contains('┌─ 💡 INFO'));
      expect(formatted, contains('─ TestLogger'));
      
      // Message
      expect(formatted, contains('│ Test message'));
      
      // Metadata
      expect(formatted, contains('│ Metadata:'));
      expect(formatted, contains('│   key: value'));
      expect(formatted, contains('│   number: 42'));
      
      // Tags
      expect(formatted, contains('│ Tags: important, test'));
      
      // Error
      expect(formatted, contains('│ Error: Test error'));
      
      // Stack trace
      expect(formatted, contains('│ Stack Trace:'));
      expect(formatted, contains('│   Line 1'));
      expect(formatted, contains('│   Line 2'));
      
      // Footer
      expect(formatted, contains('└─'));
    });

    test('omits empty sections', () {
      final formatter = DetailedFormatter();
      final entry = createTestEntry();
      final formatted = formatter.format(entry);
      
      expect(formatted, isNot(contains('Metadata:')));
      expect(formatted, isNot(contains('Tags:')));
      expect(formatted, isNot(contains('Error:')));
      expect(formatted, isNot(contains('Stack Trace:')));
    });
  });

  group('CsvFormatter', () {
    test('formats as CSV', () {
      final formatter = CsvFormatter();
      final entry = LogEntry(
        id: 'test-id',
        timestamp: testTimestamp,
        level: LogLevel.info,
        message: 'Test message',
        logger: 'TestLogger',
        error: 'Test error',
        userId: 'user123',
        sessionId: 'session456',
        deviceId: 'device789',
        platform: 'test',
        appVersion: '1.0.0',
      );
      
      final formatted = formatter.format(entry);
      final parts = formatted.split(',');
      
      expect(parts[0], equals(testTimestamp.toIso8601String()));
      expect(parts[1], equals('INFO'));
      expect(parts[2], equals('TestLogger'));
      expect(parts[3], equals('Test message'));
      expect(parts[4], equals('Test error'));
      expect(parts[5], equals('user123'));
      expect(parts[6], equals('session456'));
      expect(parts[7], equals('device789'));
      expect(parts[8], equals('test'));
      expect(parts[9], equals('1.0.0'));
    });

    test('escapes CSV values with special characters', () {
      final formatter = CsvFormatter();
      final entry = createTestEntry(
        message: 'Message with, comma',
        error: 'Error with "quotes"',
      );
      
      final formatted = formatter.format(entry);
      
      expect(formatted, contains('"Message with, comma"'));
      expect(formatted, contains('"Error with ""quotes"""'));
    });

    test('handles newlines in values', () {
      final formatter = CsvFormatter();
      final entry = createTestEntry(
        message: 'Line 1\nLine 2',
      );
      
      final formatted = formatter.format(entry);
      expect(formatted, contains('"Line 1\nLine 2"'));
    });

    test('provides header', () {
      final formatter = CsvFormatter(includeHeader: true);
      final header = formatter.header;
      
      expect(header, contains('timestamp'));
      expect(header, contains('level'));
      expect(header, contains('logger'));
      expect(header, contains('message'));
      expect(header, contains('error'));
      expect(header, contains('userId'));
      expect(header, contains('sessionId'));
      expect(header, contains('deviceId'));
      expect(header, contains('platform'));
      expect(header, contains('appVersion'));
    });

    test('uses custom delimiter', () {
      final formatter = CsvFormatter(delimiter: '|');
      final entry = createTestEntry(logger: 'TestLogger');
      
      final formatted = formatter.format(entry);
      
      expect(formatted, contains('|'));
      expect(formatted, isNot(contains(',')));
      
      final parts = formatted.split('|');
      expect(parts[1], equals('INFO'));
      expect(parts[2], equals('TestLogger'));
    });
  });
}
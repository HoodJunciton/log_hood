import 'package:flutter_test/flutter_test.dart';
import 'package:log_hood/log_hood.dart';

void main() {
  group('LogEntry', () {
    final testTimestamp = DateTime(2024, 1, 1, 12, 0);
    
    LogEntry createTestEntry({
      String? id,
      DateTime? timestamp,
      LogLevel? level,
      String? message,
    }) {
      return LogEntry(
        id: id ?? 'test-id',
        timestamp: timestamp ?? testTimestamp,
        level: level ?? LogLevel.info,
        message: message ?? 'Test message',
        logger: 'TestLogger',
        metadata: {'key': 'value'},
        tags: ['test', 'unit'],
        userId: 'user123',
        sessionId: 'session456',
        deviceId: 'device789',
        platform: 'test',
        appVersion: '1.0.0',
        buildNumber: '100',
      );
    }

    test('creates entry with all fields', () {
      final entry = createTestEntry();
      
      expect(entry.id, equals('test-id'));
      expect(entry.timestamp, equals(testTimestamp));
      expect(entry.level, equals(LogLevel.info));
      expect(entry.message, equals('Test message'));
      expect(entry.logger, equals('TestLogger'));
      expect(entry.metadata, equals({'key': 'value'}));
      expect(entry.tags, equals(['test', 'unit']));
      expect(entry.userId, equals('user123'));
      expect(entry.sessionId, equals('session456'));
      expect(entry.deviceId, equals('device789'));
      expect(entry.platform, equals('test'));
      expect(entry.appVersion, equals('1.0.0'));
      expect(entry.buildNumber, equals('100'));
    });

    test('converts to JSON correctly', () {
      final entry = createTestEntry();
      final json = entry.toJson();
      
      expect(json['id'], equals('test-id'));
      expect(json['timestamp'], equals(testTimestamp.toIso8601String()));
      expect(json['level'], equals('INFO'));
      expect(json['message'], equals('Test message'));
      expect(json['logger'], equals('TestLogger'));
      expect(json['metadata'], equals({'key': 'value'}));
      expect(json['tags'], equals(['test', 'unit']));
      expect(json['userId'], equals('user123'));
    });

    test('creates from JSON correctly', () {
      final json = {
        'id': 'json-id',
        'timestamp': testTimestamp.toIso8601String(),
        'level': 'ERROR',
        'message': 'JSON message',
        'logger': 'JSONLogger',
        'metadata': {'json': true},
        'tags': ['json', 'test'],
        'userId': 'jsonUser',
      };
      
      final entry = LogEntry.fromJson(json);
      
      expect(entry.id, equals('json-id'));
      expect(entry.timestamp, equals(testTimestamp));
      expect(entry.level, equals(LogLevel.error));
      expect(entry.message, equals('JSON message'));
      expect(entry.logger, equals('JSONLogger'));
      expect(entry.metadata, equals({'json': true}));
      expect(entry.tags, equals(['json', 'test']));
      expect(entry.userId, equals('jsonUser'));
    });

    test('formats with default settings', () {
      final entry = createTestEntry();
      final formatted = entry.format();
      
      expect(formatted, contains(testTimestamp.toIso8601String()));
      expect(formatted, contains('💡')); // Info emoji
      expect(formatted, contains('[INFO]'));
      expect(formatted, contains('[TestLogger]'));
      expect(formatted, contains('Test message'));
    });

    test('formats without emoji', () {
      final entry = createTestEntry();
      final formatted = entry.format(includeEmoji: false);
      
      expect(formatted, isNot(contains('💡')));
      expect(formatted, contains('[INFO]'));
    });

    test('formats with error and stack trace', () {
      final entry = LogEntry(
        id: 'error-id',
        timestamp: testTimestamp,
        level: LogLevel.error,
        message: 'Error message',
        error: 'Test error occurred',
        stackTrace: 'Stack trace here',
      );
      
      final formatted = entry.format();
      
      expect(formatted, contains('Error message'));
      expect(formatted, contains('Error: Test error occurred'));
      expect(formatted, contains('Stack Trace:\nStack trace here'));
    });

    test('copyWith creates new instance with updated fields', () {
      final original = createTestEntry();
      final copied = original.copyWith(
        message: 'Updated message',
        level: LogLevel.error,
        userId: 'newUser',
      );
      
      expect(copied.id, equals(original.id));
      expect(copied.timestamp, equals(original.timestamp));
      expect(copied.message, equals('Updated message'));
      expect(copied.level, equals(LogLevel.error));
      expect(copied.userId, equals('newUser'));
      expect(copied.logger, equals(original.logger));
    });

    test('handles null optional fields', () {
      final entry = LogEntry(
        id: 'minimal',
        timestamp: testTimestamp,
        level: LogLevel.info,
        message: 'Minimal entry',
      );
      
      expect(entry.logger, isNull);
      expect(entry.metadata, isNull);
      expect(entry.tags, isNull);
      expect(entry.error, isNull);
      expect(entry.stackTrace, isNull);
      
      final json = entry.toJson();
      expect(json.containsKey('logger'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
      expect(json.containsKey('tags'), isFalse);
    });
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:log_hood/log_hood.dart';
import 'mock_output.dart';

void main() {
  group('MultiOutput', () {
    late MockOutput output1;
    late MockOutput output2;
    late MockOutput output3;
    late MultiOutput multiOutput;
    
    setUp(() {
      output1 = MockOutput();
      output2 = MockOutput();
      output3 = MockOutput();
      multiOutput = MultiOutput([output1, output2, output3]);
    });

    test('writes to all outputs', () async {
      final entry = LogEntry(
        id: 'test-id',
        timestamp: DateTime.now(),
        level: LogLevel.info,
        message: 'Test message',
      );
      
      await multiOutput.write(entry);
      
      expect(output1.writtenEntries.length, equals(1));
      expect(output2.writtenEntries.length, equals(1));
      expect(output3.writtenEntries.length, equals(1));
      
      expect(output1.writtenEntries.first.id, equals('test-id'));
      expect(output2.writtenEntries.first.id, equals('test-id'));
      expect(output3.writtenEntries.first.id, equals('test-id'));
    });

    test('writes batch to all outputs', () async {
      final entries = [
        LogEntry(
          id: 'id1',
          timestamp: DateTime.now(),
          level: LogLevel.info,
          message: 'Message 1',
        ),
        LogEntry(
          id: 'id2',
          timestamp: DateTime.now(),
          level: LogLevel.error,
          message: 'Message 2',
        ),
      ];
      
      await multiOutput.writeBatch(entries);
      
      expect(output1.batchedEntries.length, equals(1));
      expect(output2.batchedEntries.length, equals(1));
      expect(output3.batchedEntries.length, equals(1));
      
      expect(output1.batchedEntries.first.length, equals(2));
      expect(output2.batchedEntries.first.length, equals(2));
      expect(output3.batchedEntries.first.length, equals(2));
    });

    test('closes all outputs', () async {
      await multiOutput.close();
      
      expect(output1.isClosed, isTrue);
      expect(output2.isClosed, isTrue);
      expect(output3.isClosed, isTrue);
    });

    test('flushes all outputs', () async {
      await multiOutput.flush();
      
      expect(output1.isFlushed, isTrue);
      expect(output2.isFlushed, isTrue);
      expect(output3.isFlushed, isTrue);
    });

    test('continues writing even if one output fails', () async {
      output2.shouldThrowOnWrite = true;
      
      final entry = LogEntry(
        id: 'test-id',
        timestamp: DateTime.now(),
        level: LogLevel.info,
        message: 'Test message',
      );
      
      await multiOutput.write(entry);
      
      // Output 1 and 3 should still receive the entry
      expect(output1.writtenEntries.length, equals(1));
      expect(output2.writtenEntries.length, equals(0)); // Failed
      expect(output3.writtenEntries.length, equals(1));
    });

    test('continues batch writing even if one output fails', () async {
      output2.shouldThrowOnBatch = true;
      
      final entries = [
        LogEntry(
          id: 'id1',
          timestamp: DateTime.now(),
          level: LogLevel.info,
          message: 'Message 1',
        ),
      ];
      
      await multiOutput.writeBatch(entries);
      
      expect(output1.batchedEntries.length, equals(1));
      expect(output2.batchedEntries.length, equals(0)); // Failed
      expect(output3.batchedEntries.length, equals(1));
    });

    test('continues closing even if one output fails', () async {
      output2.shouldThrowOnWrite = true; // Will throw on any operation
      
      await multiOutput.close();
      
      expect(output1.isClosed, isTrue);
      // output2 might fail but shouldn't affect others
      expect(output3.isClosed, isTrue);
    });

    test('handles empty output list', () async {
      final emptyOutput = MultiOutput([]);
      
      final entry = LogEntry(
        id: 'test-id',
        timestamp: DateTime.now(),
        level: LogLevel.info,
        message: 'Test message',
      );
      
      // Should not throw
      await expectLater(emptyOutput.write(entry), completes);
      await expectLater(emptyOutput.writeBatch([entry]), completes);
      await expectLater(emptyOutput.flush(), completes);
      await expectLater(emptyOutput.close(), completes);
    });
  });
}
import 'dart:async';
import 'package:log_hood/log_hood.dart';

class MockOutput implements LogOutput {
  final List<LogEntry> writtenEntries = [];
  final List<List<LogEntry>> batchedEntries = [];
  bool isClosed = false;
  bool isFlushed = false;
  
  // For testing errors
  bool shouldThrowOnWrite = false;
  bool shouldThrowOnBatch = false;
  String errorMessage = 'Mock error';

  @override
  Future<void> write(LogEntry entry) async {
    if (shouldThrowOnWrite) {
      throw Exception(errorMessage);
    }
    writtenEntries.add(entry);
  }

  @override
  Future<void> writeBatch(List<LogEntry> entries) async {
    if (shouldThrowOnBatch) {
      throw Exception(errorMessage);
    }
    batchedEntries.add(entries);
    writtenEntries.addAll(entries);
  }

  @override
  Future<void> close() async {
    isClosed = true;
  }

  @override
  Future<void> flush() async {
    isFlushed = true;
  }
  
  void reset() {
    writtenEntries.clear();
    batchedEntries.clear();
    isClosed = false;
    isFlushed = false;
    shouldThrowOnWrite = false;
    shouldThrowOnBatch = false;
  }
}
import 'dart:async';
import '../core/log_entry.dart';

abstract class LogOutput {
  Future<void> write(LogEntry entry);
  Future<void> writeBatch(List<LogEntry> entries);
  Future<void> close();
  Future<void> flush();
}

class MultiOutput implements LogOutput {
  final List<LogOutput> outputs;

  MultiOutput(this.outputs);

  @override
  Future<void> write(LogEntry entry) async {
    await Future.wait(
      outputs.map((output) => output.write(entry)),
      eagerError: false,
    );
  }

  @override
  Future<void> writeBatch(List<LogEntry> entries) async {
    await Future.wait(
      outputs.map((output) => output.writeBatch(entries)),
      eagerError: false,
    );
  }

  @override
  Future<void> close() async {
    await Future.wait(
      outputs.map((output) => output.close()),
      eagerError: false,
    );
  }

  @override
  Future<void> flush() async {
    await Future.wait(
      outputs.map((output) => output.flush()),
      eagerError: false,
    );
  }
}
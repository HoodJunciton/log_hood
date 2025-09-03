import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../core/log_entry.dart';
import '../core/log_level.dart';
import '../formatters/log_formatter.dart';
import 'log_output.dart';

class ConsoleOutput implements LogOutput {
  final LogFormatter formatter;
  final bool useColors;
  final bool useDeveloperLog;

  ConsoleOutput({
    LogFormatter? formatter,
    this.useColors = true,
    this.useDeveloperLog = true,
  }) : formatter = formatter ?? SimpleFormatter();

  @override
  Future<void> write(LogEntry entry) async {
    final formatted = formatter.format(entry);
    final colored = useColors ? _colorize(formatted, entry.level) : formatted;

    if (useDeveloperLog && !kIsWeb) {
      developer.log(
        formatted,
        time: entry.timestamp,
        level: _getDeveloperLogLevel(entry.level),
        name: entry.logger ?? 'LogHood',
        error: entry.error,
        stackTrace: entry.stackTrace != null 
            ? StackTrace.fromString(entry.stackTrace!) 
            : null,
      );
    } else {
      if (kDebugMode) {
        print(colored);
      }
    }
  }

  @override
  Future<void> writeBatch(List<LogEntry> entries) async {
    for (final entry in entries) {
      await write(entry);
    }
  }

  @override
  Future<void> close() async {
    // Console doesn't need closing
  }

  @override
  Future<void> flush() async {
    // Console is always flushed immediately
  }

  String _colorize(String message, LogLevel level) {
    if (!useColors) return message;

    const reset = '\x1B[0m';
    String color;

    switch (level) {
      case LogLevel.verbose:
        color = '\x1B[90m'; // Gray
        break;
      case LogLevel.debug:
        color = '\x1B[36m'; // Cyan
        break;
      case LogLevel.info:
        color = '\x1B[32m'; // Green
        break;
      case LogLevel.warning:
        color = '\x1B[33m'; // Yellow
        break;
      case LogLevel.error:
        color = '\x1B[31m'; // Red
        break;
      case LogLevel.critical:
        color = '\x1B[35m'; // Magenta
        break;
      case LogLevel.fatal:
        color = '\x1B[91m'; // Bright Red
        break;
    }

    return '$color$message$reset';
  }

  int _getDeveloperLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return 300;
      case LogLevel.debug:
        return 400;
      case LogLevel.info:
        return 500;
      case LogLevel.warning:
        return 700;
      case LogLevel.error:
        return 900;
      case LogLevel.critical:
        return 1000;
      case LogLevel.fatal:
        return 1200;
    }
  }
}
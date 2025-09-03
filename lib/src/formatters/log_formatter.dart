import 'dart:convert';
import '../core/log_entry.dart';

abstract class LogFormatter {
  String format(LogEntry entry);
}

class SimpleFormatter implements LogFormatter {
  final bool includeTimestamp;
  final bool includeLevel;
  final bool includeLogger;
  final bool includeEmoji;

  SimpleFormatter({
    this.includeTimestamp = true,
    this.includeLevel = true,
    this.includeLogger = true,
    this.includeEmoji = true,
  });

  @override
  String format(LogEntry entry) {
    final buffer = StringBuffer();

    if (includeTimestamp) {
      buffer.write('[${_formatTimestamp(entry.timestamp)}] ');
    }

    if (includeLevel) {
      if (includeEmoji) {
        buffer.write('${entry.level.emoji} ');
      }
      buffer.write('[${entry.level.name}] ');
    }

    if (includeLogger && entry.logger != null) {
      buffer.write('[${entry.logger}] ');
    }

    buffer.write(entry.message);

    return buffer.toString();
  }

  String _formatTimestamp(DateTime timestamp) {
    return timestamp.toIso8601String();
  }
}

class JsonFormatter implements LogFormatter {
  final bool pretty;

  JsonFormatter({this.pretty = false});

  @override
  String format(LogEntry entry) {
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(entry.toJson());
    }
    return entry.toJsonString();
  }
}

class CompactFormatter implements LogFormatter {
  @override
  String format(LogEntry entry) {
    return '${entry.level.name[0]}|${entry.message}';
  }
}

class DetailedFormatter implements LogFormatter {
  final String lineBreak;
  final String indent;

  DetailedFormatter({
    this.lineBreak = '\n',
    this.indent = '  ',
  });

  @override
  String format(LogEntry entry) {
    final buffer = StringBuffer();
    
    // Header line
    buffer.write('┌─ ${entry.level.emoji} ${entry.level.name} ');
    buffer.write('─ ${_formatTimestamp(entry.timestamp)} ');
    if (entry.logger != null) {
      buffer.write('─ ${entry.logger} ');
    }
    buffer.writeln('─' * 20);
    
    // Message
    buffer.writeln('│ ${entry.message}');
    
    // Metadata
    if (entry.metadata != null && entry.metadata!.isNotEmpty) {
      buffer.writeln('│');
      buffer.writeln('│ Metadata:');
      entry.metadata!.forEach((key, value) {
        buffer.writeln('│ $indent$key: $value');
      });
    }
    
    // Context
    if (entry.context != null && entry.context!.isNotEmpty) {
      buffer.writeln('│');
      buffer.writeln('│ Context:');
      entry.context!.forEach((key, value) {
        buffer.writeln('│ $indent$key: $value');
      });
    }
    
    // Tags
    if (entry.tags != null && entry.tags!.isNotEmpty) {
      buffer.writeln('│');
      buffer.writeln('│ Tags: ${entry.tags!.join(', ')}');
    }
    
    // Error
    if (entry.error != null) {
      buffer.writeln('│');
      buffer.writeln('│ Error: ${entry.error}');
    }
    
    // Stack trace
    if (entry.stackTrace != null) {
      buffer.writeln('│');
      buffer.writeln('│ Stack Trace:');
      final lines = entry.stackTrace!.split('\n');
      for (final line in lines) {
        buffer.writeln('│ $indent$line');
      }
    }
    
    // Footer
    buffer.write('└');
    buffer.write('─' * 60);
    
    return buffer.toString();
  }

  String _formatTimestamp(DateTime timestamp) {
    return timestamp.toLocal().toString();
  }
}

class CsvFormatter implements LogFormatter {
  final String delimiter;
  final bool includeHeader;

  CsvFormatter({
    this.delimiter = ',',
    this.includeHeader = false,
  });

  String get header {
    return [
      'timestamp',
      'level',
      'logger',
      'message',
      'error',
      'userId',
      'sessionId',
      'deviceId',
      'platform',
      'appVersion',
    ].join(delimiter);
  }

  @override
  String format(LogEntry entry) {
    final values = [
      entry.timestamp.toIso8601String(),
      entry.level.name,
      entry.logger ?? '',
      _escapeCsv(entry.message),
      _escapeCsv(entry.error ?? ''),
      entry.userId ?? '',
      entry.sessionId ?? '',
      entry.deviceId ?? '',
      entry.platform ?? '',
      entry.appVersion ?? '',
    ];

    return values.join(delimiter);
  }

  String _escapeCsv(String value) {
    if (value.contains(delimiter) || 
        value.contains('"') || 
        value.contains('\n') || 
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
import 'dart:convert';
import 'package:log_hood/log_hood.dart';

import '../core/log_entry.dart';
import 'log_formatter.dart';

class ExpandableFormatter implements LogFormatter {
  final bool expanded;
  final bool showMetadata;
  final bool showStackTrace;
  final bool useColors;
  final String collapsedIndicator;
  final String expandedIndicator;

  ExpandableFormatter({
    this.expanded = false,
    this.showMetadata = true,
    this.showStackTrace = true,
    this.useColors = true,
    this.collapsedIndicator = '▶',
    this.expandedIndicator = '▼',
  });

  @override
  String format(LogEntry entry) {
    if (!expanded) {
      return _formatCollapsed(entry);
    }
    return _formatExpanded(entry);
  }

  String _formatCollapsed(LogEntry entry) {
    final buffer = StringBuffer();
    
    // Indicator
    buffer.write('$collapsedIndicator ');
    
    // Timestamp
    buffer.write('[${_formatTimestamp(entry.timestamp)}] ');
    
    // Level with emoji
    buffer.write('${entry.level.emoji} [${entry.level.name}] ');
    
    // Logger name
    if (entry.logger != null) {
      buffer.write('[${entry.logger}] ');
    }
    
    // Message (truncated)
    final message = entry.message.replaceAll('\n', ' ');
    if (message.length > 80) {
      buffer.write('${message.substring(0, 77)}...');
    } else {
      buffer.write(message);
    }
    
    // Add indicators for additional content
    final extras = <String>[];
    if (entry.metadata != null && entry.metadata!.isNotEmpty) {
      extras.add('+metadata');
    }
    if (entry.error != null) {
      extras.add('+error');
    }
    if (entry.stackTrace != null) {
      extras.add('+stack');
    }
    if (entry.tags != null && entry.tags!.isNotEmpty) {
      extras.add('+tags');
    }
    
    if (extras.isNotEmpty) {
      buffer.write(' [${extras.join(' ')}]');
    }
    
    return buffer.toString();
  }

  String _formatExpanded(LogEntry entry) {
    final buffer = StringBuffer();
    final indent = '  ';
    
    // Header with indicator
    buffer.writeln('$expandedIndicator ${_formatHeader(entry)}');
    
    // Message (full)
    buffer.writeln('$indent${_colorize("Message:", _AnsiColor.cyan)} ${entry.message}');
    
    // Metadata
    if (showMetadata && entry.metadata != null && entry.metadata!.isNotEmpty) {
      buffer.writeln('$indent${_colorize("Metadata:", _AnsiColor.cyan)}');
      final formatted = _formatJson(entry.metadata!, indent: '$indent  ');
      buffer.writeln(formatted);
    }
    
    // Context
    if (entry.context != null && entry.context!.isNotEmpty) {
      buffer.writeln('$indent${_colorize("Context:", _AnsiColor.cyan)}');
      final formatted = _formatJson(entry.context!, indent: '$indent  ');
      buffer.writeln(formatted);
    }
    
    // Tags
    if (entry.tags != null && entry.tags!.isNotEmpty) {
      buffer.writeln('$indent${_colorize("Tags:", _AnsiColor.cyan)} ${entry.tags!.join(', ')}');
    }
    
    // Device info
    if (entry.deviceId != null || entry.platform != null) {
      buffer.writeln('$indent${_colorize("Device:", _AnsiColor.cyan)}');
      if (entry.deviceId != null) {
        buffer.writeln('$indent  ID: ${entry.deviceId}');
      }
      if (entry.platform != null) {
        buffer.writeln('$indent  Platform: ${entry.platform}');
      }
      if (entry.appVersion != null) {
        buffer.writeln('$indent  App Version: ${entry.appVersion}');
      }
    }
    
    // User/Session info
    if (entry.userId != null || entry.sessionId != null) {
      buffer.writeln('$indent${_colorize("Session:", _AnsiColor.cyan)}');
      if (entry.userId != null) {
        buffer.writeln('$indent  User ID: ${entry.userId}');
      }
      if (entry.sessionId != null) {
        buffer.writeln('$indent  Session ID: ${entry.sessionId}');
      }
    }
    
    // Error
    if (entry.error != null) {
      buffer.writeln('$indent${_colorize("Error:", _AnsiColor.red)} ${entry.error}');
    }
    
    // Stack trace
    if (showStackTrace && entry.stackTrace != null) {
      buffer.writeln('$indent${_colorize("Stack Trace:", _AnsiColor.red)}');
      final lines = entry.stackTrace!.split('\n');
      for (int i = 0; i < lines.length && i < 10; i++) {
        buffer.writeln('$indent  ${lines[i]}');
      }
      if (lines.length > 10) {
        buffer.writeln('$indent  ... (${lines.length - 10} more lines)');
      }
    }
    
    // Footer
    buffer.write('└${"─" * 60}');
    
    return buffer.toString();
  }

  String _formatHeader(LogEntry entry) {
    final parts = <String>[];
    
    // Timestamp
    parts.add('[${_formatTimestamp(entry.timestamp)}]');
    
    // Level
    parts.add('${entry.level.emoji} [${_colorize(entry.level.name, _getColorForLevel(entry.level))}]');
    
    // Logger
    if (entry.logger != null) {
      parts.add('[${entry.logger}]');
    }
    
    return parts.join(' ');
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
           '${timestamp.minute.toString().padLeft(2, '0')}:'
           '${timestamp.second.toString().padLeft(2, '0')}.'
           '${timestamp.millisecond.toString().padLeft(3, '0')}';
  }

  String _formatJson(Map<String, dynamic> data, {String indent = ''}) {
    final encoder = JsonEncoder.withIndent('  ');
    final json = encoder.convert(data);
    
    // Add indent to each line
    return json.split('\n').map((line) => '$indent$line').join('\n');
  }

  String _colorize(String text, _AnsiColor color) {
    if (!useColors) return text;
    return '${color.code}$text${_AnsiColor.reset.code}';
  }

  _AnsiColor _getColorForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return _AnsiColor.gray;
      case LogLevel.debug:
        return _AnsiColor.cyan;
      case LogLevel.info:
        return _AnsiColor.green;
      case LogLevel.warning:
        return _AnsiColor.yellow;
      case LogLevel.error:
        return _AnsiColor.red;
      case LogLevel.critical:
        return _AnsiColor.magenta;
      case LogLevel.fatal:
        return _AnsiColor.brightRed;
    }
  }
}

// Network-specific formatter
class NetworkFormatter extends ExpandableFormatter {
  NetworkFormatter({
    super.expanded,
    super.showMetadata = true,
    super.showStackTrace = false,
    super.useColors = true,
  });

  @override
  String _formatCollapsed(LogEntry entry) {
    final metadata = entry.metadata ?? {};
    final type = metadata['type'] as String?;
    
    if (type == 'request') {
      return _formatRequestCollapsed(entry, metadata);
    } else if (type == 'response') {
      return _formatResponseCollapsed(entry, metadata);
    } else if (type == 'error') {
      return _formatErrorCollapsed(entry, metadata);
    }
    
    return super._formatCollapsed(entry);
  }

  String _formatRequestCollapsed(LogEntry entry, Map<String, dynamic> metadata) {
    final buffer = StringBuffer();
    
    buffer.write('$collapsedIndicator ');
    buffer.write('[${_formatTimestamp(entry.timestamp)}] ');
    buffer.write('🌐 → ');
    buffer.write('${metadata['method']} ');
    
    final url = metadata['url'] as String? ?? '';
    final truncatedUrl = url.length > 60 ? '${url.substring(0, 57)}...' : url;
    buffer.write(truncatedUrl);
    
    final extras = <String>[];
    if (metadata['headers'] != null) extras.add('headers');
    if (metadata['body'] != null) extras.add('body');
    if (metadata['queryParams'] != null) extras.add('params');
    
    if (extras.isNotEmpty) {
      buffer.write(' [+${extras.join(' +')}]');
    }
    
    return buffer.toString();
  }

  String _formatResponseCollapsed(LogEntry entry, Map<String, dynamic> metadata) {
    final buffer = StringBuffer();
    
    buffer.write('$collapsedIndicator ');
    buffer.write('[${_formatTimestamp(entry.timestamp)}] ');
    
    final statusCode = metadata['statusCode'] as int? ?? 0;
    final emoji = _getEmojiForStatus(statusCode);
    buffer.write('$emoji ← ');
    
    buffer.write('$statusCode ');
    
    final duration = metadata['duration'] as int?;
    if (duration != null) {
      buffer.write('(${duration}ms) ');
    }
    
    final bodySize = metadata['bodySize'] as int?;
    if (bodySize != null) {
      buffer.write('[${_formatBytes(bodySize)}]');
    }
    
    return buffer.toString();
  }

  String _formatErrorCollapsed(LogEntry entry, Map<String, dynamic> metadata) {
    final buffer = StringBuffer();
    
    buffer.write('$collapsedIndicator ');
    buffer.write('[${_formatTimestamp(entry.timestamp)}] ');
    buffer.write('❌ ');
    buffer.write('${metadata['method']} ');
    
    final url = metadata['url'] as String? ?? '';
    final truncatedUrl = url.length > 40 ? '${url.substring(0, 37)}...' : url;
    buffer.write(truncatedUrl);
    
    buffer.write(' - ');
    buffer.write(entry.error ?? 'Network error');
    
    return buffer.toString();
  }

  String _getEmojiForStatus(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) return '✅';
    if (statusCode >= 300 && statusCode < 400) return '↩️';
    if (statusCode >= 400 && statusCode < 500) return '⚠️';
    return '❌';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

enum _AnsiColor {
  reset('\x1B[0m'),
  gray('\x1B[90m'),
  cyan('\x1B[36m'),
  green('\x1B[32m'),
  yellow('\x1B[33m'),
  red('\x1B[31m'),
  magenta('\x1B[35m'),
  brightRed('\x1B[91m');

  final String code;
  const _AnsiColor(this.code);
}
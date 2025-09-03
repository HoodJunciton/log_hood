import 'log_level.dart';
import 'log_entry.dart';

abstract class LogFilter {
  bool shouldLog(LogEntry entry);
}

class LevelFilter implements LogFilter {
  final LogLevel minLevel;

  LevelFilter({this.minLevel = LogLevel.verbose});

  @override
  bool shouldLog(LogEntry entry) {
    return entry.level >= minLevel;
  }
}

class TagFilter implements LogFilter {
  final List<String> allowedTags;
  final List<String> excludedTags;

  TagFilter({
    this.allowedTags = const [],
    this.excludedTags = const [],
  });

  @override
  bool shouldLog(LogEntry entry) {
    if (entry.tags == null || entry.tags!.isEmpty) {
      return allowedTags.isEmpty;
    }

    // Check excluded tags first
    for (final tag in excludedTags) {
      if (entry.tags!.contains(tag)) {
        return false;
      }
    }

    // If allowed tags are specified, check if entry has at least one
    if (allowedTags.isNotEmpty) {
      return entry.tags!.any((tag) => allowedTags.contains(tag));
    }

    return true;
  }
}

class LoggerNameFilter implements LogFilter {
  final List<String> allowedLoggers;
  final List<String> excludedLoggers;

  LoggerNameFilter({
    this.allowedLoggers = const [],
    this.excludedLoggers = const [],
  });

  @override
  bool shouldLog(LogEntry entry) {
    if (entry.logger == null) {
      return allowedLoggers.isEmpty;
    }

    // Check excluded loggers
    for (final logger in excludedLoggers) {
      if (entry.logger!.contains(logger)) {
        return false;
      }
    }

    // Check allowed loggers
    if (allowedLoggers.isNotEmpty) {
      return allowedLoggers.any((logger) => entry.logger!.contains(logger));
    }

    return true;
  }
}

class CompositeFilter implements LogFilter {
  final List<LogFilter> filters;
  final bool requireAll;

  CompositeFilter({
    required this.filters,
    this.requireAll = true,
  });

  @override
  bool shouldLog(LogEntry entry) {
    if (requireAll) {
      return filters.every((filter) => filter.shouldLog(entry));
    } else {
      return filters.any((filter) => filter.shouldLog(entry));
    }
  }
}

class TimeRangeFilter implements LogFilter {
  final DateTime? startTime;
  final DateTime? endTime;

  TimeRangeFilter({this.startTime, this.endTime});

  @override
  bool shouldLog(LogEntry entry) {
    if (startTime != null && entry.timestamp.isBefore(startTime!)) {
      return false;
    }
    if (endTime != null && entry.timestamp.isAfter(endTime!)) {
      return false;
    }
    return true;
  }
}

class RegexFilter implements LogFilter {
  final RegExp pattern;
  final bool include;

  RegexFilter({required String pattern, this.include = true})
      : pattern = RegExp(pattern);

  @override
  bool shouldLog(LogEntry entry) {
    final matches = pattern.hasMatch(entry.message);
    return include ? matches : !matches;
  }
}
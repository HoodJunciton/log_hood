enum LogLevel {
  verbose(0, 'VERBOSE', '💬'),
  debug(1, 'DEBUG', '🐛'),
  info(2, 'INFO', '💡'),
  warning(3, 'WARNING', '⚠️'),
  error(4, 'ERROR', '❌'),
  critical(5, 'CRITICAL', '🔥'),
  fatal(6, 'FATAL', '💀');

  final int value;
  final String name;
  final String emoji;

  const LogLevel(this.value, this.name, this.emoji);

  bool operator >=(LogLevel other) => value >= other.value;
  bool operator <=(LogLevel other) => value <= other.value;
  bool operator >(LogLevel other) => value > other.value;
  bool operator <(LogLevel other) => value < other.value;

  static LogLevel fromString(String level) {
    return LogLevel.values.firstWhere(
      (l) => l.name.toLowerCase() == level.toLowerCase(),
      orElse: () => LogLevel.info,
    );
  }
}
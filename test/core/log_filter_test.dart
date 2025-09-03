import 'package:flutter_test/flutter_test.dart';
import 'package:log_hood/log_hood.dart';

void main() {
  final testTimestamp = DateTime(2024, 1, 1, 12, 0);
  
  LogEntry createEntry({
    LogLevel level = LogLevel.info,
    String message = 'Test message',
    String? logger,
    List<String>? tags,
    DateTime? timestamp,
  }) {
    return LogEntry(
      id: 'test-id',
      timestamp: timestamp ?? testTimestamp,
      level: level,
      message: message,
      logger: logger,
      tags: tags,
    );
  }

  group('LevelFilter', () {
    test('filters by minimum level', () {
      final filter = LevelFilter(minLevel: LogLevel.warning);
      
      expect(filter.shouldLog(createEntry(level: LogLevel.verbose)), isFalse);
      expect(filter.shouldLog(createEntry(level: LogLevel.debug)), isFalse);
      expect(filter.shouldLog(createEntry(level: LogLevel.info)), isFalse);
      expect(filter.shouldLog(createEntry(level: LogLevel.warning)), isTrue);
      expect(filter.shouldLog(createEntry(level: LogLevel.error)), isTrue);
      expect(filter.shouldLog(createEntry(level: LogLevel.critical)), isTrue);
      expect(filter.shouldLog(createEntry(level: LogLevel.fatal)), isTrue);
    });

    test('allows all with verbose minimum', () {
      final filter = LevelFilter(minLevel: LogLevel.verbose);
      
      for (final level in LogLevel.values) {
        expect(filter.shouldLog(createEntry(level: level)), isTrue);
      }
    });
  });

  group('TagFilter', () {
    test('filters by allowed tags', () {
      final filter = TagFilter(allowedTags: ['important', 'user']);
      
      expect(filter.shouldLog(createEntry(tags: ['important'])), isTrue);
      expect(filter.shouldLog(createEntry(tags: ['user'])), isTrue);
      expect(filter.shouldLog(createEntry(tags: ['important', 'user'])), isTrue);
      expect(filter.shouldLog(createEntry(tags: ['other'])), isFalse);
      expect(filter.shouldLog(createEntry(tags: null)), isFalse);
    });

    test('filters by excluded tags', () {
      final filter = TagFilter(excludedTags: ['debug', 'verbose']);
      
      expect(filter.shouldLog(createEntry(tags: ['debug'])), isFalse);
      expect(filter.shouldLog(createEntry(tags: ['verbose'])), isFalse);
      expect(filter.shouldLog(createEntry(tags: ['important', 'debug'])), isFalse);
      expect(filter.shouldLog(createEntry(tags: ['important'])), isTrue);
      expect(filter.shouldLog(createEntry(tags: null)), isTrue);
    });

    test('combines allowed and excluded tags', () {
      final filter = TagFilter(
        allowedTags: ['important', 'user'],
        excludedTags: ['debug'],
      );
      
      expect(filter.shouldLog(createEntry(tags: ['important'])), isTrue);
      expect(filter.shouldLog(createEntry(tags: ['important', 'debug'])), isFalse);
      expect(filter.shouldLog(createEntry(tags: ['user', 'debug'])), isFalse);
      expect(filter.shouldLog(createEntry(tags: ['other'])), isFalse);
    });
  });

  group('LoggerNameFilter', () {
    test('filters by allowed logger names', () {
      final filter = LoggerNameFilter(allowedLoggers: ['App', 'Network']);
      
      expect(filter.shouldLog(createEntry(logger: 'App')), isTrue);
      expect(filter.shouldLog(createEntry(logger: 'Network')), isTrue);
      expect(filter.shouldLog(createEntry(logger: 'AppLogger')), isTrue); // Contains 'App'
      expect(filter.shouldLog(createEntry(logger: 'Database')), isFalse);
      expect(filter.shouldLog(createEntry(logger: null)), isFalse);
    });

    test('filters by excluded logger names', () {
      final filter = LoggerNameFilter(excludedLoggers: ['Test', 'Debug']);
      
      expect(filter.shouldLog(createEntry(logger: 'TestLogger')), isFalse);
      expect(filter.shouldLog(createEntry(logger: 'DebugService')), isFalse);
      expect(filter.shouldLog(createEntry(logger: 'AppLogger')), isTrue);
      expect(filter.shouldLog(createEntry(logger: null)), isTrue);
    });
  });

  group('CompositeFilter', () {
    test('requires all filters when requireAll is true', () {
      final filter = CompositeFilter(
        filters: [
          LevelFilter(minLevel: LogLevel.warning),
          TagFilter(allowedTags: ['important']),
        ],
        requireAll: true,
      );
      
      expect(
        filter.shouldLog(createEntry(
          level: LogLevel.error,
          tags: ['important'],
        )),
        isTrue,
      );
      
      expect(
        filter.shouldLog(createEntry(
          level: LogLevel.error,
          tags: ['other'],
        )),
        isFalse,
      );
      
      expect(
        filter.shouldLog(createEntry(
          level: LogLevel.info,
          tags: ['important'],
        )),
        isFalse,
      );
    });

    test('requires any filter when requireAll is false', () {
      final filter = CompositeFilter(
        filters: [
          LevelFilter(minLevel: LogLevel.error),
          TagFilter(allowedTags: ['important']),
        ],
        requireAll: false,
      );
      
      expect(
        filter.shouldLog(createEntry(
          level: LogLevel.error,
          tags: ['other'],
        )),
        isTrue,
      );
      
      expect(
        filter.shouldLog(createEntry(
          level: LogLevel.info,
          tags: ['important'],
        )),
        isTrue,
      );
      
      expect(
        filter.shouldLog(createEntry(
          level: LogLevel.info,
          tags: ['other'],
        )),
        isFalse,
      );
    });
  });

  group('TimeRangeFilter', () {
    test('filters by time range', () {
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      final twoHoursAgo = now.subtract(const Duration(hours: 2));
      final thirtyMinutesAgo = now.subtract(const Duration(minutes: 30));
      
      final filter = TimeRangeFilter(
        startTime: oneHourAgo,
        endTime: now,
      );
      
      expect(
        filter.shouldLog(createEntry(timestamp: thirtyMinutesAgo)),
        isTrue,
      );
      
      expect(
        filter.shouldLog(createEntry(timestamp: twoHoursAgo)),
        isFalse,
      );
      
      expect(
        filter.shouldLog(createEntry(
          timestamp: now.add(const Duration(minutes: 1))
        )),
        isFalse,
      );
    });

    test('handles null start or end time', () {
      final now = DateTime.now();
      final past = now.subtract(const Duration(hours: 1));
      final future = now.add(const Duration(hours: 1));
      
      final startOnlyFilter = TimeRangeFilter(startTime: now);
      expect(startOnlyFilter.shouldLog(createEntry(timestamp: past)), isFalse);
      expect(startOnlyFilter.shouldLog(createEntry(timestamp: future)), isTrue);
      
      final endOnlyFilter = TimeRangeFilter(endTime: now);
      expect(endOnlyFilter.shouldLog(createEntry(timestamp: past)), isTrue);
      expect(endOnlyFilter.shouldLog(createEntry(timestamp: future)), isFalse);
    });
  });

  group('RegexFilter', () {
    test('filters by regex pattern with include', () {
      final filter = RegexFilter(pattern: r'user_\d+', include: true);
      
      expect(filter.shouldLog(createEntry(message: 'user_123 logged in')), isTrue);
      expect(filter.shouldLog(createEntry(message: 'user_456 action')), isTrue);
      expect(filter.shouldLog(createEntry(message: 'admin logged in')), isFalse);
    });

    test('filters by regex pattern with exclude', () {
      final filter = RegexFilter(pattern: r'debug|verbose', include: false);
      
      expect(filter.shouldLog(createEntry(message: 'debug: testing')), isFalse);
      expect(filter.shouldLog(createEntry(message: 'verbose output')), isFalse);
      expect(filter.shouldLog(createEntry(message: 'important message')), isTrue);
    });

    test('handles complex patterns', () {
      final filter = RegexFilter(
        pattern: r'^\[ERROR\].*failed.*$',
        include: true,
      );
      
      expect(
        filter.shouldLog(createEntry(message: '[ERROR] Operation failed')),
        isTrue,
      );
      
      expect(
        filter.shouldLog(createEntry(message: '[INFO] Operation failed')),
        isFalse,
      );
      
      expect(
        filter.shouldLog(createEntry(message: '[ERROR] Success')),
        isFalse,
      );
    });
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:log_hood/log_hood.dart';

void main() {
  group('LogLevel', () {
    test('has correct values', () {
      expect(LogLevel.verbose.value, equals(0));
      expect(LogLevel.debug.value, equals(1));
      expect(LogLevel.info.value, equals(2));
      expect(LogLevel.warning.value, equals(3));
      expect(LogLevel.error.value, equals(4));
      expect(LogLevel.critical.value, equals(5));
      expect(LogLevel.fatal.value, equals(6));
    });

    test('has correct names', () {
      expect(LogLevel.verbose.name, equals('VERBOSE'));
      expect(LogLevel.debug.name, equals('DEBUG'));
      expect(LogLevel.info.name, equals('INFO'));
      expect(LogLevel.warning.name, equals('WARNING'));
      expect(LogLevel.error.name, equals('ERROR'));
      expect(LogLevel.critical.name, equals('CRITICAL'));
      expect(LogLevel.fatal.name, equals('FATAL'));
    });

    test('has emojis', () {
      expect(LogLevel.verbose.emoji, equals('💬'));
      expect(LogLevel.debug.emoji, equals('🐛'));
      expect(LogLevel.info.emoji, equals('💡'));
      expect(LogLevel.warning.emoji, equals('⚠️'));
      expect(LogLevel.error.emoji, equals('❌'));
      expect(LogLevel.critical.emoji, equals('🔥'));
      expect(LogLevel.fatal.emoji, equals('💀'));
    });

    test('comparison operators work correctly', () {
      expect(LogLevel.error > LogLevel.info, isTrue);
      expect(LogLevel.info < LogLevel.error, isTrue);
      expect(LogLevel.warning >= LogLevel.warning, isTrue);
      expect(LogLevel.debug <= LogLevel.info, isTrue);
      expect(LogLevel.fatal > LogLevel.verbose, isTrue);
    });

    test('fromString parses correctly', () {
      expect(LogLevel.fromString('verbose'), equals(LogLevel.verbose));
      expect(LogLevel.fromString('DEBUG'), equals(LogLevel.debug));
      expect(LogLevel.fromString('Info'), equals(LogLevel.info));
      expect(LogLevel.fromString('WARNING'), equals(LogLevel.warning));
      expect(LogLevel.fromString('error'), equals(LogLevel.error));
      expect(LogLevel.fromString('CRITICAL'), equals(LogLevel.critical));
      expect(LogLevel.fromString('fatal'), equals(LogLevel.fatal));
    });

    test('fromString returns info for unknown values', () {
      expect(LogLevel.fromString('unknown'), equals(LogLevel.info));
      expect(LogLevel.fromString(''), equals(LogLevel.info));
      expect(LogLevel.fromString('random'), equals(LogLevel.info));
    });
  });
}
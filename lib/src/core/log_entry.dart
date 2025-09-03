import 'dart:convert';
import 'package:stack_trace/stack_trace.dart';
import 'log_level.dart';

class LogEntry {
  final String id;
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? logger;
  final Map<String, dynamic>? metadata;
  final String? stackTrace;
  final String? error;
  final String? deviceId;
  final String? userId;
  final String? sessionId;
  final String? platform;
  final String? appVersion;
  final String? buildNumber;
  final Map<String, dynamic>? context;
  final List<String>? tags;
  final String? threadName;
  final int? processId;

  LogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.message,
    this.logger,
    this.metadata,
    this.stackTrace,
    this.error,
    this.deviceId,
    this.userId,
    this.sessionId,
    this.platform,
    this.appVersion,
    this.buildNumber,
    this.context,
    this.tags,
    this.threadName,
    this.processId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      if (logger != null) 'logger': logger,
      if (metadata != null) 'metadata': metadata,
      if (stackTrace != null) 'stackTrace': stackTrace,
      if (error != null) 'error': error,
      if (deviceId != null) 'deviceId': deviceId,
      if (userId != null) 'userId': userId,
      if (sessionId != null) 'sessionId': sessionId,
      if (platform != null) 'platform': platform,
      if (appVersion != null) 'appVersion': appVersion,
      if (buildNumber != null) 'buildNumber': buildNumber,
      if (context != null) 'context': context,
      if (tags != null) 'tags': tags,
      if (threadName != null) 'threadName': threadName,
      if (processId != null) 'processId': processId,
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      level: LogLevel.fromString(json['level']),
      message: json['message'],
      logger: json['logger'],
      metadata: json['metadata'],
      stackTrace: json['stackTrace'],
      error: json['error'],
      deviceId: json['deviceId'],
      userId: json['userId'],
      sessionId: json['sessionId'],
      platform: json['platform'],
      appVersion: json['appVersion'],
      buildNumber: json['buildNumber'],
      context: json['context'],
      tags: json['tags']?.cast<String>(),
      threadName: json['threadName'],
      processId: json['processId'],
    );
  }

  String toJsonString() => jsonEncode(toJson());

  String format({bool includeEmoji = true, bool includeMetadata = true}) {
    final buffer = StringBuffer();
    
    // Timestamp
    buffer.write('[${timestamp.toIso8601String()}] ');
    
    // Level with emoji
    if (includeEmoji) {
      buffer.write('${level.emoji} ');
    }
    buffer.write('[${level.name}] ');
    
    // Logger name
    if (logger != null) {
      buffer.write('[$logger] ');
    }
    
    // Message
    buffer.write(message);
    
    // Metadata
    if (includeMetadata && metadata != null && metadata!.isNotEmpty) {
      buffer.write(' ${jsonEncode(metadata)}');
    }
    
    // Error and stack trace
    if (error != null) {
      buffer.write('\nError: $error');
    }
    if (stackTrace != null) {
      buffer.write('\nStack Trace:\n$stackTrace');
    }
    
    return buffer.toString();
  }

  LogEntry copyWith({
    String? id,
    DateTime? timestamp,
    LogLevel? level,
    String? message,
    String? logger,
    Map<String, dynamic>? metadata,
    String? stackTrace,
    String? error,
    String? deviceId,
    String? userId,
    String? sessionId,
    String? platform,
    String? appVersion,
    String? buildNumber,
    Map<String, dynamic>? context,
    List<String>? tags,
    String? threadName,
    int? processId,
  }) {
    return LogEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      level: level ?? this.level,
      message: message ?? this.message,
      logger: logger ?? this.logger,
      metadata: metadata ?? this.metadata,
      stackTrace: stackTrace ?? this.stackTrace,
      error: error ?? this.error,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      platform: platform ?? this.platform,
      appVersion: appVersion ?? this.appVersion,
      buildNumber: buildNumber ?? this.buildNumber,
      context: context ?? this.context,
      tags: tags ?? this.tags,
      threadName: threadName ?? this.threadName,
      processId: processId ?? this.processId,
    );
  }
}
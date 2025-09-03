# LogHood - Advanced Flutter Logging System

LogHood is a comprehensive, enterprise-grade logging system for Flutter applications that works across all platforms. It provides advanced features like structured logging, crash reporting, performance monitoring, and remote log shipping.

## Features

### Core Features
- **Multiple Log Levels**: Verbose, Debug, Info, Warning, Error, Critical, Fatal with emoji support
- **Structured Logging**: Log with metadata, tags, and contextual information
- **Multiple Outputs**: Console, File, Database, and HTTP endpoints
- **Log Formatting**: JSON, CSV, Simple, Detailed, and Custom formatters
- **Crash Handling**: Automatic crash detection and reporting
- **Performance Monitoring**: Track frame drops, memory usage, and operation timing
- **Cross-Platform**: Works on iOS, Android, Web, Windows, macOS, and Linux

### Advanced Features
- **Log Rotation**: Automatic file rotation based on size and count
- **Compression**: GZip compression for file storage and HTTP transmission
- **Batching**: Efficient batch processing for HTTP and database outputs
- **Filtering**: Filter logs by level, tags, logger name, time range, and regex
- **Device Information**: Automatic collection of device and app information
- **Session Management**: Track user sessions and correlate logs
- **Global Context**: Add persistent context to all logs
- **Error History**: Maintain history of recent errors
- **Network Logging**: Automatic logging for HTTP and Dio network calls
- **Expandable Console Logs**: Collapsed/expanded view for detailed logs

## Installation

Add LogHood to your `pubspec.yaml`:

```yaml
dependencies:
  log_hood: ^1.0.0
```

## Quick Start

### Basic Initialization

```dart
import 'package:log_hood/log_hood.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize LogHood with default settings
  await LogHood.initialize();
  
  runApp(MyApp());
}
```

### Advanced Initialization

```dart
await LogHood.initialize(
  minimumLevel: LogLevel.debug,
  enableConsoleOutput: true,
  enableFileOutput: true,
  enableDatabaseOutput: true,
  enableCrashHandler: true,
  httpEndpoint: 'https://your-log-server.com/logs',
);

// Set user context
LogHood.setUserId('user123');

// Add global context
LogHood.setGlobalContext({
  'environment': 'production',
  'version': '1.0.0',
  'region': 'us-west',
});
```

### Basic Logging

```dart
// Simple logging
LogHood.i('User logged in successfully');
LogHood.w('Low memory warning');
LogHood.e('Failed to fetch data', error: exception, stackTrace: stack);

// With metadata
LogHood.d('API request completed', metadata: {
  'endpoint': '/api/users',
  'duration': 234,
  'status': 200,
});

// With tags
LogHood.i('Payment processed', tags: ['payment', 'important']);
```

### Using Named Loggers

```dart
final logger = LogHood.getLogger('NetworkService');

logger.info('Making API request', metadata: {
  'url': 'https://api.example.com/data',
  'method': 'GET',
});

logger.error('Request failed', 
  error: exception,
  stackTrace: stackTrace,
  metadata: {'statusCode': 500}
);
```

## Output Configuration

### Console Output

```dart
final logger = Logger(
  name: 'MyLogger',
  outputs: [
    ConsoleOutput(
      formatter: DetailedFormatter(),
      useColors: true,
      useDeveloperLog: true,
    ),
  ],
);
```

### File Output

```dart
FileOutput(
  fileName: 'app',
  formatter: JsonFormatter(pretty: true),
  maxFileSize: 10 * 1024 * 1024, // 10MB
  maxFiles: 5,
  compress: true,
  flushInterval: Duration(seconds: 5),
)
```

### HTTP Output

```dart
HttpOutput(
  endpoint: 'https://logs.example.com/ingest',
  headers: {'Authorization': 'Bearer YOUR_TOKEN'},
  batchInterval: Duration(seconds: 30),
  batchSize: 100,
  compress: true,
  onError: (error, stackTrace) {
    // Handle HTTP errors
  },
)
```

### Database Output

```dart
DatabaseOutput(
  databaseName: 'app_logs.db',
  maxEntries: 100000,
  cleanupInterval: Duration(hours: 1),
  enableIndexing: true,
)
```

## Filtering

```dart
// Level filtering
final logger = Logger(
  filters: [
    LevelFilter(minLevel: LogLevel.info),
  ],
);

// Tag filtering
TagFilter(
  allowedTags: ['important', 'user-action'],
  excludedTags: ['verbose', 'debug'],
)

// Time range filtering
TimeRangeFilter(
  startTime: DateTime.now().subtract(Duration(hours: 1)),
  endTime: DateTime.now(),
)

// Regex filtering
RegexFilter(
  pattern: r'user_\d+',
  include: true,
)
```

## Crash Handling

```dart
// Initialize crash handler
CrashHandler.initialize(
  logger: logger,
  handleFlutterErrors: true,
  handleIsolateErrors: true,
  handlePlatformErrors: true,
  onError: (error, stackTrace) {
    // Custom error handling
  },
);

// Record errors manually
CrashHandler.recordError(
  exception,
  stackTrace,
  metadata: {'user_action': 'button_click'},
  fatal: false,
);

// Run guarded code
await CrashHandler.runGuarded(() async {
  // Code that might throw
});
```

## Performance Monitoring

```dart
final monitor = PerformanceMonitor(
  sampleInterval: Duration(seconds: 5),
  frameDropThreshold: 16.67, // 60 FPS
);

// Start monitoring
monitor.startMonitoring();

// Get current stats
final stats = monitor.getCurrentStats();

// Stop monitoring
monitor.stopMonitoring();
```

## Measuring Operations

```dart
// Measure synchronous operations
final result = logger.measure(
  'database_query',
  () => database.query('SELECT * FROM users'),
  metadata: {'query_type': 'select'},
);

// Measure async operations
final data = await logger.measureAsync(
  'api_request',
  () async => http.get('https://api.example.com/data'),
  metadata: {'endpoint': '/data'},
);
```

## Network Logging

### HTTP Client Logging

LogHood provides automatic logging for the standard `http` package:

```dart
import 'package:http/http.dart' as http;

// Create HTTP client with logging
final client = http.Client().withLogging(
  logger: LogHood.getLogger('HTTP'),
  logRequestBody: true,
  logResponseBody: true,
  logHeaders: true,
  maxBodyLength: 1000,
);

// All requests will be automatically logged
final response = await client.get(Uri.parse('https://api.example.com/data'));
```

### Dio Interceptor

For Dio users, add `dio` to your pubspec.yaml, then import and use the interceptor:

```yaml
dependencies:
  dio: ^5.4.0
```

```dart
import 'package:dio/dio.dart';
import 'package:log_hood/log_hood.dart';
// Import the Dio interceptor directly
import 'package:log_hood/src/network/dio_interceptor.dart';

final dio = Dio();

// Add LogHood interceptor
dio.addLogHoodInterceptor(
  logger: LogHood.getLogger('DIO'),
  logRequestBody: true,
  logResponseBody: true,
  logHeaders: true,
);

// All Dio requests will be logged
final response = await dio.get('https://api.example.com/data');
```

**Note:** The Dio interceptor is only available when you have the `dio` package as a dependency in your project.

### Network Log Formatting

Use the `NetworkFormatter` for better network log visualization:

```dart
final logger = Logger(
  name: 'API',
  outputs: [
    ConsoleOutput(
      formatter: NetworkFormatter(
        expanded: false, // Set to true for detailed view
      ),
    ),
  ],
);
```

Network logs show:
- Request: `🌐 → GET https://api.example.com/data`
- Success: `✅ ← 200 (125ms) [1.2 KB]`
- Error: `❌ ← 500 (2341ms)`

### Expandable Console Logs

The `ExpandableFormatter` supports collapsed/expanded views:

```dart
// Collapsed view (single line)
▶ [12:34:56.789] 💡 [INFO] [API] User logged in [+metadata +tags]

// Expanded view (detailed)
▼ [12:34:56.789] 💡 [INFO] [API]
  Message: User logged in
  Metadata:
    {
      "userId": "123",
      "method": "OAuth",
      "duration": 234
    }
  Tags: authentication, user
  Session:
    User ID: user123
    Session ID: session456
└────────────────────────────────────────────────────────────
```

## Querying Logs

```dart
// Query from database
final dbOutput = DatabaseOutput();
final logs = await dbOutput.query(
  startTime: DateTime.now().subtract(Duration(hours: 1)),
  levels: [LogLevel.error, LogLevel.critical],
  userId: 'user123',
  searchText: 'payment',
  limit: 100,
);

// Get statistics
final stats = await dbOutput.getStatistics(
  startTime: DateTime.now().subtract(Duration(days: 1)),
);
```

## Custom Formatters

```dart
class CustomFormatter implements LogFormatter {
  @override
  String format(LogEntry entry) {
    return '${entry.timestamp} | ${entry.level.name} | ${entry.message}';
  }
}

// Use custom formatter
ConsoleOutput(formatter: CustomFormatter())
```

## Best Practices

1. **Initialize Early**: Initialize LogHood in your main() function before runApp()
2. **Use Named Loggers**: Create separate loggers for different components
3. **Add Context**: Use metadata and tags to add searchable context
4. **Set User ID**: Always set user ID for better debugging
5. **Handle Sensitive Data**: Never log passwords, tokens, or sensitive information
6. **Use Appropriate Levels**: Use correct log levels for better filtering
7. **Monitor Performance**: Enable performance monitoring in development
8. **Clean Up**: Call LogHood.close() when your app terminates

## Example App

See the complete example in the `example` folder that demonstrates:
- All log levels
- User configuration
- Performance monitoring
- Crash handling
- Batch operations

## HTTP Server Setup

To receive logs via HTTP, your server should accept POST requests with the following format:

```json
{
  "logs": [
    {
      "id": "unique_id",
      "timestamp": "2024-01-01T12:00:00Z",
      "level": "INFO",
      "message": "Log message",
      "metadata": {},
      "tags": ["tag1", "tag2"]
    }
  ],
  "timestamp": "2024-01-01T12:00:00Z",
  "count": 1
}
```

Headers:
- `Content-Type: application/json`
- `Content-Encoding: gzip` (if compression is enabled)

## Troubleshooting

### Logs not appearing
- Check minimum log level configuration
- Verify filters aren't blocking logs
- Ensure outputs are properly initialized

### File permissions
- On mobile platforms, file output requires storage permissions
- Check path_provider is properly configured

### HTTP errors
- Verify endpoint URL is correct
- Check network connectivity
- Review server logs for errors

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

## Support

For issues and feature requests, please use the GitHub issue tracker.
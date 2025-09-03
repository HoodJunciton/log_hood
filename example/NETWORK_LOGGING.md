# Network Logging in LogHood Example

This example demonstrates how to use LogHood's network interceptors for automatic API logging.

## Setup

### HTTP Interceptor (Built-in)

The HTTP interceptor is included in the main LogHood package:

```dart
import 'package:log_hood/log_hood.dart';
import 'package:http/http.dart' as http;

// Create HTTP client with logging
final client = http.Client().withLogging(
  logger: LogHood.getLogger('HTTP'),
  logRequestBody: true,
  logResponseBody: true,
  logHeaders: true,
);
```

### Dio Interceptor (Optional)

Since Dio is an optional dependency, you need to:

1. Add Dio to your `pubspec.yaml`:
```yaml
dependencies:
  dio: ^5.4.0
```

2. Import the interceptor directly:
```dart
// ignore: implementation_imports
import 'package:log_hood/src/network/dio_interceptor.dart';
```

3. Add the interceptor to your Dio instance:
```dart
final dio = Dio();
dio.addLogHoodInterceptor(
  logger: LogHood.getLogger('DIO'),
);
```

## Features Demonstrated

1. **Toggle Log Expansion**: Switch between collapsed and expanded network log views
2. **HTTP Client Test**: Makes GET and POST requests using the HTTP client
3. **Dio Client Test**: Makes GET and POST requests using Dio
4. **Error Handling**: Shows how errors are logged automatically

## Log Output Examples

### Collapsed View
```
🌐 → GET https://jsonplaceholder.typicode.com/posts/1
✅ ← 200 (125ms)
```

### Expanded View
```
▼ [12:34:56.789] 🌐 [INFO] [HTTP]
  Message: GET https://jsonplaceholder.typicode.com/posts/1
  Metadata:
    {
      "method": "GET",
      "url": "https://jsonplaceholder.typicode.com/posts/1",
      "headers": {...},
      "timestamp": "2024-01-01T12:34:56Z"
    }
```

## Running the Example

1. Run the example app:
```bash
flutter run
```

2. Scroll to the "Network Logging" section
3. Toggle "Expand Network Logs" to see detailed output
4. Click "Test HTTP Client" or "Test Dio Client"
5. Check the console for logged network calls

## Understanding the Code

The example shows:
- How to initialize both HTTP and Dio clients with logging
- How to recreate clients when changing formatter settings
- How both successful and failed requests are logged
- How to use the NetworkFormatter for better visualization

## Tips

- Use different logger names for different APIs
- Consider using expanded view during development
- Use collapsed view in production for cleaner logs
- Network errors are automatically logged with stack traces
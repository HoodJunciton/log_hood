# LogHood Interceptor Guide

This guide explains how LogHood interceptors work to automatically log network requests.

## How Interceptors Work

### HTTP Interceptor (Built-in)

The HTTP interceptor wraps the standard `http.Client` to log all requests and responses:

```dart
import 'package:http/http.dart' as http;
import 'package:log_hood/log_hood.dart';

// Create a logger for network logs
final logger = LogHood.getLogger('API');

// Wrap any http.Client with logging
final client = http.Client().withLogging(
  logger: logger,
  logRequestBody: true,
  logResponseBody: true,
);

// All requests through this client will be logged
final response = await client.get(Uri.parse('https://api.example.com'));
```

**What gets logged:**
- Request method, URL, headers
- Request body (if enabled)
- Response status code, duration
- Response body (if enabled)
- Errors and exceptions

### Dio Interceptor (Optional)

For Dio users, first add Dio to your dependencies:

```yaml
dependencies:
  log_hood: ^1.0.0
  dio: ^5.4.0
```

Then import and use:

```dart
import 'package:dio/dio.dart';
import 'package:log_hood/log_hood.dart';
// Must import directly since Dio is optional
import 'package:log_hood/src/network/dio_interceptor.dart';

final dio = Dio();

// Add the LogHood interceptor
dio.addLogHoodInterceptor(
  logger: LogHood.getLogger('DIO'),
  logRequestBody: true,
  logResponseBody: true,
  logHeaders: true,
  maxBodyLength: 1000,
);
```

## Log Format Examples

### Collapsed View (Default)
```
🌐 → GET https://api.example.com/users
✅ ← 200 (125ms)
```

### Expanded View
```
▼ [12:34:56.789] 🌐 [INFO] [API]
  Message: GET https://api.example.com/users
  Metadata:
    {
      "type": "request",
      "method": "GET",
      "url": "https://api.example.com/users",
      "headers": {
        "User-Agent": "MyApp/1.0",
        "Accept": "application/json"
      }
    }
  Tags: network, http, request, get
└────────────────────────────────────────

▼ [12:34:56.914] ✅ [INFO] [API]
  Message: 200 (125ms)
  Metadata:
    {
      "type": "response",
      "statusCode": 200,
      "duration": 125,
      "bodySize": 1234,
      "body": "[{\"id\": 1, \"name\": \"John\"}]"
    }
  Tags: network, http, response, status_200
└────────────────────────────────────────
```

## Network-Specific Formatter

Use the `NetworkFormatter` for better visualization:

```dart
// Create a logger with network formatter
final networkLogger = Logger(
  name: 'API',
  outputs: [
    ConsoleOutput(
      formatter: NetworkFormatter(
        expanded: false,  // Set to true for detailed view
        showBody: true,
        showHeaders: true,
        maxBodyLength: 500,
      ),
    ),
  ],
);

// Use with HTTP client
final client = http.Client().withLogging(logger: networkLogger);
```

## Sensitive Data Protection

Headers containing sensitive data are automatically redacted:
- Authorization headers
- Cookie headers  
- Token headers
- API-Key headers

Example:
```
Headers: {
  "Authorization": "***REDACTED***",
  "Content-Type": "application/json",
  "API-Key": "***REDACTED***"
}
```

## Error Logging

Network errors are logged with appropriate levels:
- 2xx responses: INFO level ✅
- 3xx responses: INFO level ↩️
- 4xx responses: WARNING level ⚠️
- 5xx responses: ERROR level ❌
- Network failures: ERROR level ❌

## Performance Tracking

Each request logs:
- Duration in milliseconds
- Request/response body size
- Timestamp for correlation

## Best Practices

1. **Use separate loggers for different APIs:**
   ```dart
   final authLogger = LogHood.getLogger('Auth');
   final apiLogger = LogHood.getLogger('API');
   ```

2. **Filter sensitive endpoints:**
   ```dart
   // Don't log bodies for sensitive endpoints
   final client = http.Client().withLogging(
     logger: logger,
     logRequestBody: !url.contains('/auth/'),
     logResponseBody: !url.contains('/auth/'),
   );
   ```

3. **Use appropriate formatters:**
   - `NetworkFormatter` for API debugging
   - `JsonFormatter` for structured logs
   - `SimpleFormatter` for production

4. **Control log levels:**
   ```dart
   // Only log errors in production
   final logger = Logger(
     name: 'API',
     minimumLevel: kDebugMode ? LogLevel.debug : LogLevel.error,
   );
   ```

## Integration with LogHood Features

Network logs work with all LogHood features:

- **Filtering:** Filter by tags like 'network', 'http', 'error'
- **Metadata:** Access request/response details
- **Database:** Query historical API calls
- **Remote Logging:** Send network logs to your server
- **Performance:** Track API response times

## Troubleshooting

### Dio interceptor not found
Make sure to:
1. Add `dio` to your dependencies
2. Import the interceptor directly: `import 'package:log_hood/src/network/dio_interceptor.dart';`

### Large response bodies
Control body logging with `maxBodyLength`:
```dart
dio.addLogHoodInterceptor(
  maxBodyLength: 500,  // Truncate bodies longer than 500 chars
);
```

### Too many logs
Filter by URL patterns:
```dart
// Only log specific endpoints
if (url.contains('/api/v2/')) {
  logger.info('Request...', tags: ['apiv2']);
}
```
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:log_hood/log_hood.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize LogHood with advanced features
  await LogHood.initialize(
    minimumLevel: LogLevel.verbose,
    enableConsoleOutput: true,
    enableFileOutput: true,
    enableDatabaseOutput: true,
    enableCrashHandler: true,
    httpEndpoint: null, // Replace with your endpoint if needed
  );
  
  // Configure console output with expandable formatter for network logs
  Logger(
    name: 'NetworkDemo',
    outputs: [
      ConsoleOutput(
        formatter: NetworkFormatter(expanded: false),
        useColors: true,
      ),
    ],
  );

  // Set global context
  LogHood.setGlobalContext({
    'environment': 'development',
    'app_name': 'LogHood Example',
    'build_mode': 'debug',
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LogHood Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LogHoodDemo(),
    );
  }
}

class LogHoodDemo extends StatefulWidget {
  const LogHoodDemo({super.key});

  @override
  State<LogHoodDemo> createState() => _LogHoodDemoState();
}

class _LogHoodDemoState extends State<LogHoodDemo> {
  final Logger _logger = LogHood.getLogger('DemoScreen');
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final _userIdController = TextEditingController();
  bool _isPerformanceMonitoring = false;
  bool _expandNetworkLogs = false;
  
  // HTTP client with logging
  late final http.Client _httpClient;
  
  // Dio instance with logging
  late final Dio _dio;

  @override
  void initState() {
    super.initState();
    _logger.info('Demo screen initialized');
    
    // Initialize HTTP client with logging
    _httpClient = http.Client().withLogging(
      logger: Logger(
        name: 'HTTP',
        outputs: [
          ConsoleOutput(
            formatter: NetworkFormatter(expanded: _expandNetworkLogs),
            useColors: true,
          ),
        ],
      ),
    );
    
    // Initialize Dio with logging
    _dio = Dio()
      ..options.connectTimeout = const Duration(seconds: 10)
      ..options.receiveTimeout = const Duration(seconds: 10);
    
    _dio.addLogHoodInterceptor(
      logger: Logger(
        name: 'DIO',
        outputs: [
          ConsoleOutput(
            formatter: NetworkFormatter(expanded: _expandNetworkLogs),
            useColors: true,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _performanceMonitor.stopMonitoring();
    _userIdController.dispose();
    _httpClient.close();
    _dio.close();
    super.dispose();
  }

  void _logWithLevel(LogLevel level, String message) {
    final metadata = {
      'timestamp': DateTime.now().toIso8601String(),
      'random_value': Random().nextInt(100),
      'user_action': 'manual_log',
    };

    switch (level) {
      case LogLevel.verbose:
        _logger.verbose(message, metadata: metadata, tags: ['demo', 'manual']);
        break;
      case LogLevel.debug:
        _logger.debug(message, metadata: metadata, tags: ['demo', 'manual']);
        break;
      case LogLevel.info:
        _logger.info(message, metadata: metadata, tags: ['demo', 'manual']);
        break;
      case LogLevel.warning:
        _logger.warning(message, metadata: metadata, tags: ['demo', 'manual']);
        break;
      case LogLevel.error:
        _logger.error(
          message,
          error: Exception('Demo error'),
          stackTrace: StackTrace.current,
          metadata: metadata,
          tags: ['demo', 'manual', 'error'],
        );
        break;
      case LogLevel.critical:
        _logger.critical(
          message,
          error: Exception('Critical demo error'),
          metadata: metadata,
          tags: ['demo', 'manual', 'critical'],
        );
        break;
      case LogLevel.fatal:
        _logger.fatal(
          message,
          error: Exception('Fatal demo error'),
          metadata: metadata,
          tags: ['demo', 'manual', 'fatal'],
        );
        break;
    }
  }

  void _triggerCrash() {
    _logger.warning('About to trigger a crash for demonstration');
    
    // This will be caught by the crash handler
    Future.delayed(const Duration(milliseconds: 100), () {
      throw Exception('Intentional crash for demonstration purposes');
    });
  }

  void _measureOperation() async {
    try {
      final result = await _logger.measureAsync(
        'expensive_operation',
        () async {
          _logger.debug('Starting expensive operation');
          await Future.delayed(const Duration(seconds: 2));
          
          if (Random().nextBool()) {
            throw Exception('Random failure in operation');
          }
          
          return 'Operation completed successfully';
        },
        metadata: {'operation_type': 'demo'},
      );
      
      _showSnackBar('Operation result: $result');
    } catch (e) {
      _showSnackBar('Operation failed: $e');
    }
  }

  void _togglePerformanceMonitoring() {
    setState(() {
      _isPerformanceMonitoring = !_isPerformanceMonitoring;
      
      if (_isPerformanceMonitoring) {
        _performanceMonitor.startMonitoring();
        _logger.info('Performance monitoring started');
      } else {
        final stats = _performanceMonitor.getCurrentStats();
        _performanceMonitor.stopMonitoring();
        _logger.info('Performance monitoring stopped', metadata: stats);
        _showSnackBar('Performance stats: ${stats.toString()}');
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  void _testHttpCall() async {
    try {
      // Test successful API call
      final response = await _httpClient.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
      );
      
      _showSnackBar('HTTP call successful: ${response.statusCode}');
      
      // Test POST with body
      await _httpClient.post(
        Uri.parse('https://jsonplaceholder.typicode.com/posts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': 'Test Post',
          'body': 'This is a test post from LogHood',
          'userId': 1,
        }),
      );
      
      // Test 404 error
      await _httpClient.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts/999999'),
      );
    } catch (e) {
      _showSnackBar('HTTP error: $e');
    }
  }
  
  void _testDioCall() async {
    try {
      // Test successful API call
      final response = await _dio.get(
        'https://jsonplaceholder.typicode.com/users',
        queryParameters: {'_limit': 5},
      );
      
      _showSnackBar('Dio call successful: ${response.data.length} users');
      
      // Test POST with JSON
      await _dio.post(
        'https://jsonplaceholder.typicode.com/posts',
        data: {
          'title': 'Dio Test Post',
          'body': 'Posted using Dio with LogHood interceptor',
          'userId': 1,
        },
      );
      
      // Test error handling
      try {
        await _dio.get('https://invalid-url-that-does-not-exist.com/api');
      } catch (e) {
        // Error will be logged by interceptor
      }
    } catch (e) {
      _showSnackBar('Dio error: $e');
    }
  }
  
  void _toggleNetworkLogExpansion() {
    setState(() {
      _expandNetworkLogs = !_expandNetworkLogs;
      
      // Recreate HTTP client with new formatter
      _httpClient.close();
      _httpClient = http.Client().withLogging(
        logger: Logger(
          name: 'HTTP',
          outputs: [
            ConsoleOutput(
              formatter: NetworkFormatter(expanded: _expandNetworkLogs),
              useColors: true,
            ),
          ],
        ),
      );
      
      // Update Dio interceptor
      _dio.interceptors.clear();
      _dio.addLogHoodInterceptor(
        logger: Logger(
          name: 'DIO',
          outputs: [
            ConsoleOutput(
              formatter: NetworkFormatter(expanded: _expandNetworkLogs),
              useColors: true,
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LogHood Advanced Logger Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Configuration',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _userIdController,
                      decoration: const InputDecoration(
                        labelText: 'User ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        LogHood.setUserId(_userIdController.text);
                        _logger.info('User ID updated', metadata: {
                          'user_id': _userIdController.text,
                        });
                        _showSnackBar('User ID set to: ${_userIdController.text}');
                      },
                      child: const Text('Set User ID'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log Levels',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    ...LogLevel.values.map((level) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ElevatedButton.icon(
                        onPressed: () => _logWithLevel(
                          level,
                          'This is a ${level.name} message',
                        ),
                        icon: Text(level.emoji),
                        label: Text('Log ${level.name}'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Advanced Features',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _triggerCrash,
                      icon: const Icon(Icons.warning),
                      label: const Text('Trigger Crash (Handled)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        minimumSize: const Size.fromHeight(40),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _measureOperation,
                      icon: const Icon(Icons.timer),
                      label: const Text('Measure Async Operation'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _togglePerformanceMonitoring,
                      icon: Icon(_isPerformanceMonitoring ? Icons.stop : Icons.play_arrow),
                      label: Text(_isPerformanceMonitoring 
                          ? 'Stop Performance Monitoring' 
                          : 'Start Performance Monitoring'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isPerformanceMonitoring ? Colors.red : Colors.green,
                        minimumSize: const Size.fromHeight(40),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Network Logging',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Expand Network Logs'),
                      subtitle: const Text('Show detailed request/response info'),
                      value: _expandNetworkLogs,
                      onChanged: (value) => _toggleNetworkLogExpansion(),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _testHttpCall,
                      icon: const Icon(Icons.http),
                      label: const Text('Test HTTP Client'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _testDioCall,
                      icon: const Icon(Icons.network_check),
                      label: const Text('Test Dio Client'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        minimumSize: const Size.fromHeight(40),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Batch Operations',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Log multiple messages quickly
                        for (int i = 0; i < 50; i++) {
                          _logger.info(
                            'Batch log message #$i',
                            metadata: {'index': i, 'batch': true},
                            tags: ['batch', 'demo'],
                          );
                        }
                        _showSnackBar('50 log messages sent!');
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                      ),
                      child: const Text('Send 50 Log Messages'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
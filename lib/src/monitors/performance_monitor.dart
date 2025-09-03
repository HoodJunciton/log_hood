import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../logger.dart';
import '../core/log_level.dart';

class PerformanceMonitor {
  final Logger logger;
  final Duration sampleInterval;
  final double frameDropThreshold;
  final double memoryWarningThreshold;
  
  Timer? _timer;
  bool _isMonitoring = false;
  
  // Performance metrics
  final List<double> _frameTimes = [];
  final List<double> _memoryUsage = [];
  DateTime? _lastFrameTime;
  int _droppedFrames = 0;
  int _totalFrames = 0;

  PerformanceMonitor({
    Logger? logger,
    this.sampleInterval = const Duration(seconds: 5),
    this.frameDropThreshold = 16.67, // 60 FPS threshold
    this.memoryWarningThreshold = 0.8, // 80% of available memory
  }) : logger = logger ?? Logger.getLogger('PerformanceMonitor');

  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;

    // Monitor frame timing
    if (!kIsWeb) {
      SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    }

    // Start periodic sampling
    _timer = Timer.periodic(sampleInterval, (_) => _sample());

    logger.info('Performance monitoring started');
  }

  void stopMonitoring() {
    if (!_isMonitoring) return;
    _isMonitoring = false;

    _timer?.cancel();
    
    if (!kIsWeb) {
      SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    }

    logger.info('Performance monitoring stopped');
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final frameDuration = timing.totalSpan.inMicroseconds / 1000.0; // Convert to ms
      _frameTimes.add(frameDuration);
      _totalFrames++;

      if (frameDuration > frameDropThreshold) {
        _droppedFrames++;
      }

      // Keep only recent frame times (last 1000 frames)
      if (_frameTimes.length > 1000) {
        _frameTimes.removeAt(0);
      }
    }
  }

  Future<void> _sample() async {
    final metrics = await _collectMetrics();
    
    logger.debug(
      'Performance metrics',
      metadata: metrics,
      tags: ['performance', 'metrics'],
    );

    // Check for performance issues
    _checkPerformanceIssues(metrics);
  }

  Future<Map<String, dynamic>> _collectMetrics() async {
    final metrics = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Frame metrics
    if (_frameTimes.isNotEmpty) {
      final avgFrameTime = _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
      final maxFrameTime = _frameTimes.reduce((a, b) => a > b ? a : b);
      final minFrameTime = _frameTimes.reduce((a, b) => a < b ? a : b);
      
      metrics['frame_metrics'] = {
        'average_ms': avgFrameTime.toStringAsFixed(2),
        'max_ms': maxFrameTime.toStringAsFixed(2),
        'min_ms': minFrameTime.toStringAsFixed(2),
        'dropped_frames': _droppedFrames,
        'total_frames': _totalFrames,
        'drop_rate': _totalFrames > 0 
            ? (_droppedFrames / _totalFrames * 100).toStringAsFixed(2) + '%'
            : '0%',
      };
    }

    // Memory metrics
    if (!kIsWeb) {
      final memoryInfo = await _getMemoryInfo();
      if (memoryInfo != null) {
        metrics['memory'] = memoryInfo;
        _memoryUsage.add(memoryInfo['used_mb'] as double);
        
        // Keep only recent memory samples
        if (_memoryUsage.length > 100) {
          _memoryUsage.removeAt(0);
        }
      }
    }

    return metrics;
  }

  Future<Map<String, dynamic>?> _getMemoryInfo() async {
    try {
      // For now, return basic memory info
      // In a real implementation, you would use platform channels
      // to get actual memory usage
      return {
        'used_mb': '0',
        'platform': Platform.operatingSystem,
        'note': 'Memory monitoring requires platform-specific implementation',
      };
    } catch (e) {
      logger.debug('Failed to get memory info: $e');
    }
    
    return null;
  }

  void _checkPerformanceIssues(Map<String, dynamic> metrics) {
    // Check for frame drops
    if (metrics.containsKey('frame_metrics')) {
      final frameMetrics = metrics['frame_metrics'] as Map<String, dynamic>;
      final dropRate = double.tryParse(
        frameMetrics['drop_rate'].toString().replaceAll('%', '')
      ) ?? 0;
      
      if (dropRate > 5) {
        logger.warning(
          'High frame drop rate detected: ${dropRate.toStringAsFixed(2)}%',
          metadata: frameMetrics,
          tags: ['performance', 'frame_drops'],
        );
      }
    }

    // Check memory usage
    if (metrics.containsKey('memory')) {
      final memoryInfo = metrics['memory'] as Map<String, dynamic>;
      final usedMb = double.tryParse(memoryInfo['used_mb'].toString()) ?? 0;
      
      // Simple threshold check (you might want to make this more sophisticated)
      if (usedMb > 500) {
        logger.warning(
          'High memory usage detected: ${usedMb.toStringAsFixed(2)} MB',
          metadata: memoryInfo,
          tags: ['performance', 'memory'],
        );
      }
    }
  }

  Map<String, dynamic> getCurrentStats() {
    final stats = <String, dynamic>{};
    
    if (_frameTimes.isNotEmpty) {
      final avgFrameTime = _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
      stats['average_frame_time_ms'] = avgFrameTime.toStringAsFixed(2);
      stats['dropped_frames'] = _droppedFrames;
      stats['total_frames'] = _totalFrames;
    }
    
    if (_memoryUsage.isNotEmpty) {
      final avgMemory = _memoryUsage.reduce((a, b) => a + b) / _memoryUsage.length;
      stats['average_memory_mb'] = avgMemory.toStringAsFixed(2);
    }
    
    return stats;
  }

  void reset() {
    _frameTimes.clear();
    _memoryUsage.clear();
    _droppedFrames = 0;
    _totalFrames = 0;
    _lastFrameTime = null;
  }
}
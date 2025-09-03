import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../core/log_entry.dart';
import '../formatters/log_formatter.dart';
import 'log_output.dart';

class FileOutput implements LogOutput {
  final String fileName;
  final LogFormatter formatter;
  final int maxFileSize;
  final int maxFiles;
  final bool compress;
  final Duration? flushInterval;
  
  late Directory _logDirectory;
  IOSink? _sink;
  File? _currentFile;
  int _currentFileSize = 0;
  Timer? _flushTimer;
  final List<LogEntry> _buffer = [];
  final int _bufferSize;

  FileOutput({
    required this.fileName,
    LogFormatter? formatter,
    this.maxFileSize = 10 * 1024 * 1024, // 10MB
    this.maxFiles = 5,
    this.compress = false,
    this.flushInterval,
    int bufferSize = 100,
  })  : formatter = formatter ?? SimpleFormatter(),
        _bufferSize = bufferSize;

  Future<void> _initialize() async {
    if (_sink != null) return;

    final appDir = await getApplicationDocumentsDirectory();
    _logDirectory = Directory(path.join(appDir.path, 'logs'));
    
    if (!await _logDirectory.exists()) {
      await _logDirectory.create(recursive: true);
    }

    await _openNewFile();

    if (flushInterval != null) {
      _flushTimer = Timer.periodic(flushInterval!, (_) => flush());
    }
  }

  Future<void> _openNewFile() async {
    await _closeCurrentFile();

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final filePath = path.join(_logDirectory.path, '${fileName}_$timestamp.log');
    
    _currentFile = File(filePath);
    _sink = _currentFile!.openWrite(mode: FileMode.append);
    _currentFileSize = 0;

    await _cleanupOldFiles();
  }

  Future<void> _closeCurrentFile() async {
    if (_sink != null) {
      await _sink!.flush();
      await _sink!.close();
      _sink = null;

      if (compress && _currentFile != null) {
        await _compressFile(_currentFile!);
      }
    }
  }

  Future<void> _compressFile(File file) async {
    final gzipFile = File('${file.path}.gz');
    final bytes = await file.readAsBytes();
    final compressed = gzip.encode(bytes);
    await gzipFile.writeAsBytes(compressed);
    await file.delete();
  }

  Future<void> _cleanupOldFiles() async {
    final files = await _logDirectory
        .list()
        .where((entity) => entity is File && entity.path.contains(fileName))
        .map((entity) => entity as File)
        .toList();

    files.sort((a, b) {
      final aStats = a.statSync();
      final bStats = b.statSync();
      return bStats.modified.compareTo(aStats.modified);
    });

    if (files.length > maxFiles) {
      for (int i = maxFiles; i < files.length; i++) {
        await files[i].delete();
      }
    }
  }

  Future<void> _checkRotation() async {
    if (_currentFileSize >= maxFileSize) {
      await _openNewFile();
    }
  }

  @override
  Future<void> write(LogEntry entry) async {
    await _initialize();
    
    _buffer.add(entry);
    
    if (_buffer.length >= _bufferSize) {
      await flush();
    }
  }

  @override
  Future<void> writeBatch(List<LogEntry> entries) async {
    await _initialize();
    
    _buffer.addAll(entries);
    
    if (_buffer.length >= _bufferSize) {
      await flush();
    }
  }

  @override
  Future<void> flush() async {
    if (_buffer.isEmpty || _sink == null) return;

    final entriesToWrite = List<LogEntry>.from(_buffer);
    _buffer.clear();

    for (final entry in entriesToWrite) {
      final formatted = formatter.format(entry);
      final bytes = utf8.encode('$formatted\n');
      
      _sink!.add(bytes);
      _currentFileSize += bytes.length;
    }

    await _sink!.flush();
    await _checkRotation();
  }

  @override
  Future<void> close() async {
    _flushTimer?.cancel();
    await flush();
    await _closeCurrentFile();
  }

  Future<List<File>> getLogFiles() async {
    await _initialize();
    
    final files = await _logDirectory
        .list()
        .where((entity) => entity is File && entity.path.contains(fileName))
        .map((entity) => entity as File)
        .toList();

    files.sort((a, b) {
      final aStats = a.statSync();
      final bStats = b.statSync();
      return bStats.modified.compareTo(aStats.modified);
    });

    return files;
  }

  Future<String> readLogs({int? lines, DateTime? since}) async {
    final files = await getLogFiles();
    final buffer = StringBuffer();
    
    for (final file in files) {
      if (since != null) {
        final stats = await file.stat();
        if (stats.modified.isBefore(since)) {
          continue;
        }
      }

      String content;
      if (file.path.endsWith('.gz')) {
        final bytes = await file.readAsBytes();
        final decompressed = gzip.decode(bytes);
        content = utf8.decode(decompressed);
      } else {
        content = await file.readAsString();
      }

      if (lines != null) {
        final fileLines = LineSplitter.split(content).toList();
        final startIndex = fileLines.length > lines ? fileLines.length - lines : 0;
        content = fileLines.skip(startIndex).join('\n');
      }

      buffer.writeln(content);
    }

    return buffer.toString();
  }
}
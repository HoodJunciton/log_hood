import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'log_hood_method_channel.dart';

abstract class LogHoodPlatform extends PlatformInterface {
  /// Constructs a LogHoodPlatform.
  LogHoodPlatform() : super(token: _token);

  static final Object _token = Object();

  static LogHoodPlatform _instance = MethodChannelLogHood();

  /// The default instance of [LogHoodPlatform] to use.
  ///
  /// Defaults to [MethodChannelLogHood].
  static LogHoodPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [LogHoodPlatform] when
  /// they register themselves.
  static set instance(LogHoodPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'log_hood_platform_interface.dart';

/// An implementation of [LogHoodPlatform] that uses method channels.
class MethodChannelLogHood extends LogHoodPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('log_hood');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}

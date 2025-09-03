import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceInfo {
  final String deviceId;
  final String platform;
  final String osVersion;
  final String deviceModel;
  final String appVersion;
  final String buildNumber;
  final String packageName;
  final Map<String, dynamic> additionalInfo;

  DeviceInfo({
    required this.deviceId,
    required this.platform,
    required this.osVersion,
    required this.deviceModel,
    required this.appVersion,
    required this.buildNumber,
    required this.packageName,
    required this.additionalInfo,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'platform': platform,
      'osVersion': osVersion,
      'deviceModel': deviceModel,
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      'packageName': packageName,
      ...additionalInfo,
    };
  }
}

class DeviceInfoProvider {
  DeviceInfo? _deviceInfo;
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  DeviceInfo? get deviceInfo => _deviceInfo;

  Future<void> initialize() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      String deviceId = 'unknown';
      String platform = 'unknown';
      String osVersion = 'unknown';
      String deviceModel = 'unknown';
      Map<String, dynamic> additionalInfo = {};

      if (kIsWeb) {
        platform = 'web';
        final webInfo = await _deviceInfoPlugin.webBrowserInfo;
        deviceId = webInfo.userAgent ?? 'web_unknown';
        osVersion = webInfo.platform ?? 'unknown';
        deviceModel = webInfo.browserName.name;
        additionalInfo = {
          'browser': webInfo.browserName.name,
          'browserVersion': webInfo.appVersion,
          'userAgent': webInfo.userAgent,
          'language': webInfo.language,
          'vendor': webInfo.vendor,
          'platform': webInfo.platform,
          'hardwareConcurrency': webInfo.hardwareConcurrency,
          'deviceMemory': webInfo.deviceMemory,
        };
      } else if (Platform.isAndroid) {
        platform = 'android';
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        deviceId = androidInfo.id;
        osVersion = androidInfo.version.release;
        deviceModel = androidInfo.model;
        additionalInfo = {
          'brand': androidInfo.brand,
          'device': androidInfo.device,
          'manufacturer': androidInfo.manufacturer,
          'product': androidInfo.product,
          'androidSdkInt': androidInfo.version.sdkInt,
          'androidVersion': androidInfo.version.release,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
        };
      } else if (Platform.isIOS) {
        platform = 'ios';
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'ios_unknown';
        osVersion = iosInfo.systemVersion;
        deviceModel = iosInfo.model;
        additionalInfo = {
          'name': iosInfo.name,
          'systemName': iosInfo.systemName,
          'utsname': {
            'sysname': iosInfo.utsname.sysname,
            'nodename': iosInfo.utsname.nodename,
            'release': iosInfo.utsname.release,
            'version': iosInfo.utsname.version,
            'machine': iosInfo.utsname.machine,
          },
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
        };
      } else if (Platform.isMacOS) {
        platform = 'macos';
        final macInfo = await _deviceInfoPlugin.macOsInfo;
        deviceId = macInfo.systemGUID ?? 'macos_unknown';
        osVersion = '${macInfo.majorVersion}.${macInfo.minorVersion}.${macInfo.patchVersion}';
        deviceModel = macInfo.model;
        additionalInfo = {
          'computerName': macInfo.computerName,
          'hostName': macInfo.hostName,
          'arch': macInfo.arch,
          'kernelVersion': macInfo.kernelVersion,
          'cpuFrequency': macInfo.cpuFrequency,
          'memorySize': macInfo.memorySize,
        };
      } else if (Platform.isLinux) {
        platform = 'linux';
        final linuxInfo = await _deviceInfoPlugin.linuxInfo;
        deviceId = linuxInfo.machineId ?? 'linux_unknown';
        osVersion = linuxInfo.version ?? 'unknown';
        deviceModel = linuxInfo.name;
        additionalInfo = {
          'prettyName': linuxInfo.prettyName,
          'id': linuxInfo.id,
          'versionId': linuxInfo.versionId,
          'buildId': linuxInfo.buildId,
          'variant': linuxInfo.variant,
          'variantId': linuxInfo.variantId,
        };
      } else if (Platform.isWindows) {
        platform = 'windows';
        final windowsInfo = await _deviceInfoPlugin.windowsInfo;
        deviceId = windowsInfo.computerName;
        osVersion = '${windowsInfo.majorVersion}.${windowsInfo.minorVersion}.${windowsInfo.buildNumber}';
        deviceModel = windowsInfo.productName;
        additionalInfo = {
          'numberOfCores': windowsInfo.numberOfCores,
          'systemMemoryInMegabytes': windowsInfo.systemMemoryInMegabytes,
          'userName': windowsInfo.userName,
          'computerName': windowsInfo.computerName,
          'productId': windowsInfo.productId,
          'buildLab': windowsInfo.buildLab,
          'buildLabEx': windowsInfo.buildLabEx,
          'digitalProductId': windowsInfo.digitalProductId,
          'displayVersion': windowsInfo.displayVersion,
          'editionId': windowsInfo.editionId,
          'installDate': windowsInfo.installDate?.toIso8601String(),
          'productName': windowsInfo.productName,
          'registeredOwner': windowsInfo.registeredOwner,
          'releaseId': windowsInfo.releaseId,
        };
      }

      _deviceInfo = DeviceInfo(
        deviceId: deviceId,
        platform: platform,
        osVersion: osVersion,
        deviceModel: deviceModel,
        appVersion: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
        packageName: packageInfo.packageName,
        additionalInfo: additionalInfo,
      );
    } catch (e) {
      // Fallback device info if collection fails
      _deviceInfo = DeviceInfo(
        deviceId: 'unknown',
        platform: _getPlatformString(),
        osVersion: 'unknown',
        deviceModel: 'unknown',
        appVersion: 'unknown',
        buildNumber: 'unknown',
        packageName: 'unknown',
        additionalInfo: {'error': e.toString()},
      );
    }
  }

  String _getPlatformString() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) return 'windows';
    return 'unknown';
  }
}
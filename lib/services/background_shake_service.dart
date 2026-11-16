import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef BackgroundShakeCallback = void Function();

class BackgroundShakeService {
  BackgroundShakeService._privateConstructor() {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }
  static final BackgroundShakeService instance = BackgroundShakeService._privateConstructor();

  static const MethodChannel _channel = MethodChannel('com.fintech.expensetracker/background_shake');
  BackgroundShakeCallback? _onShakeCallback;

  void registerBackgroundShakeCallback(BackgroundShakeCallback callback) {
    _onShakeCallback = callback;
  }

  void unregisterBackgroundShakeCallback() {
    _onShakeCallback = null;
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'onShakeDetected') {
      debugPrint('Background shake detected via Android Foreground Service!');
      _onShakeCallback?.call();
    }
  }

  Future<bool> startService({double sensitivity = 14.0, int cooldown = 2000}) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('startBackgroundService', {
        'sensitivity': sensitivity,
        'cooldown': cooldown,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('Error starting background shake service: $e');
      return false;
    }
  }

  Future<bool> stopService() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('stopBackgroundService');
      return success ?? false;
    } catch (e) {
      debugPrint('Error stopping background shake service: $e');
      return false;
    }
  }

  Future<bool> isServiceRunning() async {
    try {
      final bool? running = await _channel.invokeMethod<bool>('isServiceRunning');
      return running ?? false;
    } catch (e) {
      debugPrint('Error checking if background service is running: $e');
      return false;
    }
  }

  Future<bool> checkNotificationPermission() async {
    try {
      final bool? granted = await _channel.invokeMethod<bool>('checkNotificationPermission');
      return granted ?? true;
    } catch (e) {
      debugPrint('Error checking notification permission: $e');
      return true;
    }
  }

  Future<void> requestNotificationPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final bool? ignored = await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored');
      return ignored ?? false;
    } catch (e) {
      debugPrint('Error checking battery optimization: $e');
      return false;
    }
  }

  Future<bool> requestIgnoreBatteryOptimization() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimization');
      return result ?? false;
    } catch (e) {
      debugPrint('Error requesting battery optimization exemption: $e');
      return false;
    }
  }

  Future<void> openBatteryOptimizationSettings() async {
    try {
      await _channel.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      debugPrint('Error opening battery optimization settings: $e');
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

typedef BackgroundShakeCallback = void Function();
typedef OverlayExpenseAddedCallback = void Function(Map<String, dynamic> data);

class BackgroundShakeService {
  BackgroundShakeService._privateConstructor() {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }
  static final BackgroundShakeService instance = BackgroundShakeService._privateConstructor();

  static const MethodChannel _channel = MethodChannel('com.fintech.expensetracker/background_shake');
  BackgroundShakeCallback? _onShakeCallback;
  OverlayExpenseAddedCallback? _onOverlayExpenseAddedCallback;

  void registerBackgroundShakeCallback(BackgroundShakeCallback callback) {
    _onShakeCallback = callback;
  }

  void unregisterBackgroundShakeCallback() {
    _onShakeCallback = null;
  }

  void registerOverlayExpenseAddedCallback(OverlayExpenseAddedCallback callback) {
    _onOverlayExpenseAddedCallback = callback;
  }

  void unregisterOverlayExpenseAddedCallback() {
    _onOverlayExpenseAddedCallback = null;
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'onShakeDetected') {
      debugPrint('Background shake detected via Android Foreground Service!');
      _onShakeCallback?.call();
    } else if (call.method == 'onOverlayExpenseAdded') {
      debugPrint('Expense added via Native Floating Overlay: ${call.arguments}');
      try {
        final map = Map<String, dynamic>.from(call.arguments as Map);
        _onOverlayExpenseAddedCallback?.call(map);
      } catch (e) {
        debugPrint('Error processing overlay expense payload: $e');
      }
    }
  }

  Future<bool> startService({
    double sensitivity = AppConstants.defaultShakeSensitivity,
    int cooldown = AppConstants.defaultShakeCooldown,
  }) async {
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

  Future<bool> updateConfig({
    required double sensitivity,
    required int cooldown,
  }) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('updateShakeConfig', {
        'sensitivity': sensitivity,
        'cooldown': cooldown,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('Error updating background shake service config: $e');
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

  Future<bool> isOverlayPermissionGranted() async {
    try {
      final bool? granted = await _channel.invokeMethod<bool>('checkOverlayPermission');
      return granted ?? false;
    } catch (e) {
      debugPrint('Error checking overlay permission: $e');
      return false;
    }
  }

  Future<bool> requestOverlayPermission() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('requestOverlayPermission');
      return result ?? false;
    } catch (e) {
      debugPrint('Error requesting overlay permission: $e');
      return false;
    }
  }

  Future<bool> showFloatingOverlay() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('showFloatingOverlay');
      return result ?? false;
    } catch (e) {
      debugPrint('Error triggering floating overlay: $e');
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

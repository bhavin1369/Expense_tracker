import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../utils/constants.dart';

typedef ShakeCallback = void Function();

class ShakeDetectionService {
  ShakeDetectionService._privateConstructor();
  static final ShakeDetectionService instance = ShakeDetectionService._privateConstructor();

  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  ShakeCallback? _onShakeCallback;

  bool _isEnabled = true;
  double _threshold = AppConstants.defaultShakeSensitivity; // m/s^2
  int _cooldownMs = AppConstants.defaultShakeCooldown; // ms
  DateTime _lastShakeTimestamp = DateTime.fromMillisecondsSinceEpoch(0);

  // Peak counter to avoid single accidental bumps
  int _peakCount = 0;
  DateTime _firstPeakTimestamp = DateTime.fromMillisecondsSinceEpoch(0);

  bool _isPaused = false;
  bool _isSheetOpen = false;

  bool get isEnabled => _isEnabled;
  double get threshold => _threshold;
  int get cooldownMs => _cooldownMs;
  bool get isSheetOpen => _isSheetOpen;

  void configure({
    required bool enabled,
    required double sensitivity,
    required int cooldown,
  }) {
    _isEnabled = enabled;
    _threshold = sensitivity;
    _cooldownMs = cooldown;

    if (!_isEnabled) {
      stopListening();
    } else if (_accelerometerSubscription == null && !_isPaused) {
      startListening();
    }
  }

  void setSheetOpenState(bool isOpen) {
    _isSheetOpen = isOpen;
  }

  void registerCallback(ShakeCallback callback) {
    _onShakeCallback = callback;
    if (_isEnabled && !_isPaused && _accelerometerSubscription == null) {
      startListening();
    }
  }

  void unregisterCallback() {
    _onShakeCallback = null;
    stopListening();
  }

  void startListening() {
    if (!_isEnabled || _isPaused) return;

    _accelerometerSubscription?.cancel();
    try {
      _accelerometerSubscription = userAccelerometerEventStream().listen(
        _handleAccelerometerEvent,
        onError: (error) {
          debugPrint('UserAccelerometer sensor error: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Failed to start shake listener: $e');
    }
  }

  void stopListening() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  void pause() {
    _isPaused = true;
    stopListening();
  }

  void resume() {
    _isPaused = false;
    if (_isEnabled && _onShakeCallback != null) {
      startListening();
    }
  }

  void _handleAccelerometerEvent(UserAccelerometerEvent event) {
    if (!_isEnabled || _isPaused || _isSheetOpen) return;

    final double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    if (magnitude > _threshold) {
      final now = DateTime.now();

      // Check if this is within the peak detection window (400ms)
      if (now.difference(_firstPeakTimestamp).inMilliseconds > 400) {
        _peakCount = 1;
        _firstPeakTimestamp = now;
      } else {
        _peakCount++;
      }

      // Require 2 quick peaks or a strong single impulse (magnitude > threshold * 1.35)
      if (_peakCount >= 2 || magnitude > (_threshold * 1.35)) {
        if (now.difference(_lastShakeTimestamp).inMilliseconds > _cooldownMs) {
          _lastShakeTimestamp = now;
          _peakCount = 0;
          _triggerShake();
        }
      }
    }
  }

  void _triggerShake() {
    HapticFeedback.mediumImpact();
    if (_onShakeCallback != null && !_isSheetOpen) {
      _onShakeCallback!();
    }
  }

  /// Manually simulates a shake event (useful for Settings Test button or Emulators)
  void simulateShake() {
    if (!_isEnabled) return;
    _triggerShake();
  }

  void dispose() {
    stopListening();
    _onShakeCallback = null;
  }
}

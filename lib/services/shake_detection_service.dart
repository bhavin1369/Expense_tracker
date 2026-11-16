import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../utils/constants.dart';

typedef ShakeCallback = void Function();

/// Detailed snapshot of shake detection engine state for debug monitoring
class ShakeDebugInfo {
  final double x;
  final double y;
  final double z;
  final double magnitude;
  final int peakCount;
  final int requiredPeaks;
  final String state; // 'IDLE', 'DETECTING', 'COOLDOWN', 'TRIGGERED'
  final double threshold;
  final String sensitivityLevel; // 'low', 'medium', 'high'
  final int rejectedSingleSpikes;
  final int rejectedTimeouts;
  final int rejectedTooFast;
  final int rejectedCooldowns;
  final DateTime? lastShakeTimestamp;
  final bool debugLogsEnabled;

  const ShakeDebugInfo({
    this.x = 0.0,
    this.y = 0.0,
    this.z = 0.0,
    this.magnitude = 0.0,
    this.peakCount = 0,
    this.requiredPeaks = AppConstants.minShakePeaks,
    this.state = 'IDLE',
    this.threshold = AppConstants.defaultShakeSensitivity,
    this.sensitivityLevel = AppConstants.defaultShakeSensitivityLevel,
    this.rejectedSingleSpikes = 0,
    this.rejectedTimeouts = 0,
    this.rejectedTooFast = 0,
    this.rejectedCooldowns = 0,
    this.lastShakeTimestamp,
    this.debugLogsEnabled = false,
  });

  ShakeDebugInfo copyWith({
    double? x,
    double? y,
    double? z,
    double? magnitude,
    int? peakCount,
    int? requiredPeaks,
    String? state,
    double? threshold,
    String? sensitivityLevel,
    int? rejectedSingleSpikes,
    int? rejectedTimeouts,
    int? rejectedTooFast,
    int? rejectedCooldowns,
    DateTime? lastShakeTimestamp,
    bool? debugLogsEnabled,
  }) {
    return ShakeDebugInfo(
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      magnitude: magnitude ?? this.magnitude,
      peakCount: peakCount ?? this.peakCount,
      requiredPeaks: requiredPeaks ?? this.requiredPeaks,
      state: state ?? this.state,
      threshold: threshold ?? this.threshold,
      sensitivityLevel: sensitivityLevel ?? this.sensitivityLevel,
      rejectedSingleSpikes: rejectedSingleSpikes ?? this.rejectedSingleSpikes,
      rejectedTimeouts: rejectedTimeouts ?? this.rejectedTimeouts,
      rejectedTooFast: rejectedTooFast ?? this.rejectedTooFast,
      rejectedCooldowns: rejectedCooldowns ?? this.rejectedCooldowns,
      lastShakeTimestamp: lastShakeTimestamp ?? this.lastShakeTimestamp,
      debugLogsEnabled: debugLogsEnabled ?? this.debugLogsEnabled,
    );
  }
}

class ShakeDetectionService {
  ShakeDetectionService._privateConstructor();
  static final ShakeDetectionService instance = ShakeDetectionService._privateConstructor();

  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  ShakeCallback? _onShakeCallback;

  bool _isEnabled = true;
  double _threshold = AppConstants.defaultShakeSensitivity; // m/s^2 linear acceleration
  String _sensitivityLevel = AppConstants.defaultShakeSensitivityLevel;
  int _cooldownMs = AppConstants.defaultShakeCooldown; // ms

  // Pattern detection state machine
  int _peakCount = 0;
  int _firstPeakTimestamp = 0; // ms epoch
  int _lastPeakTimestamp = 0; // ms epoch
  int _lastTriggerTimestamp = 0; // ms epoch
  bool _waitingForValley = false;
  int _lastPeakAxis = 0; // 0: X, 1: Y, 2: Z
  double _lastPeakSign = 1.0;

  // Rejection metrics for debugging
  int _rejectedSingleSpikes = 0;
  int _rejectedTimeouts = 0;
  int _rejectedTooFast = 0;
  int _rejectedCooldowns = 0;
  DateTime? _lastShakeTimestamp;
  bool _debugLogsEnabled = false;

  bool _isPaused = false;
  bool _isSheetOpen = false;

  // ValueNotifier for real-time debug screen monitoring
  final ValueNotifier<ShakeDebugInfo> debugNotifier = ValueNotifier<ShakeDebugInfo>(const ShakeDebugInfo());

  bool get isEnabled => _isEnabled;
  double get threshold => _threshold;
  String get sensitivityLevel => _sensitivityLevel;
  int get cooldownMs => _cooldownMs;
  bool get isSheetOpen => _isSheetOpen;
  bool get debugLogsEnabled => _debugLogsEnabled;

  void configure({
    required bool enabled,
    required double sensitivity,
    required int cooldown,
    String? level,
  }) {
    _isEnabled = enabled;
    _threshold = sensitivity;
    _cooldownMs = cooldown;
    if (level != null) {
      _sensitivityLevel = level;
    }

    _updateDebugNotifier(state: _peakCount > 0 ? 'DETECTING' : 'IDLE');

    if (!_isEnabled) {
      stopListening();
    } else if (_accelerometerSubscription == null && !_isPaused) {
      startListening();
    }
  }

  void setDebugLogsEnabled(bool enabled) {
    _debugLogsEnabled = enabled;
    _updateDebugNotifier();
  }

  void resetDebugCounters() {
    _rejectedSingleSpikes = 0;
    _rejectedTimeouts = 0;
    _rejectedTooFast = 0;
    _rejectedCooldowns = 0;
    _peakCount = 0;
    _waitingForValley = false;
    _updateDebugNotifier(state: 'IDLE');
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

    try {
      _accelerometerSubscription?.cancel();
      _accelerometerSubscription = null;
      final stream = userAccelerometerEventStream();
      _accelerometerSubscription = stream.listen(
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
    try {
      _accelerometerSubscription?.cancel();
    } catch (_) {}
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

    final double x = event.x;
    final double y = event.y;
    final double z = event.z;
    final double magnitude = sqrt(x * x + y * y + z * z);
    final int now = DateTime.now().millisecondsSinceEpoch;

    // 1. Check Cooldown
    if (now - _lastTriggerTimestamp < _cooldownMs) {
      if (magnitude >= _threshold) {
        _rejectedCooldowns++;
      }
      _updateDebugNotifier(
        x: x,
        y: y,
        z: z,
        magnitude: magnitude,
        state: 'COOLDOWN',
      );
      return;
    }

    // 2. Window and Inter-Peak Timeout Validation
    if (_peakCount > 0) {
      final int elapsedSinceFirst = now - _firstPeakTimestamp;
      final int elapsedSinceLast = now - _lastPeakTimestamp;

      if (elapsedSinceFirst > AppConstants.maxShakeWindowMs ||
          elapsedSinceLast > AppConstants.maxTimeBetweenPeaksMs) {
        if (_debugLogsEnabled) {
          debugPrint(
            '[ShakeDetector] Movement rejected/reset: peaks=$_peakCount, elapsedSinceFirst=${elapsedSinceFirst}ms, elapsedSinceLast=${elapsedSinceLast}ms',
          );
        }

        if (_peakCount == 1) {
          _rejectedSingleSpikes++;
        } else {
          _rejectedTimeouts++;
        }

        _peakCount = 0;
        _waitingForValley = false;
      }
    }

    // 3. Valley / Hysteresis and Direction Reversal Validation
    final double valleyThreshold = _threshold * AppConstants.shakeValleyRatio;
    if (_waitingForValley) {
      if (magnitude < valleyThreshold) {
        // Dropped below valley threshold, ready to detect the next peak
        _waitingForValley = false;
      } else {
        // Directional sign reversal check on dominant axis
        final double dominantVal = _lastPeakAxis == 0 ? x : (_lastPeakAxis == 1 ? y : z);
        if ((dominantVal * _lastPeakSign) < -valleyThreshold) {
          // Axis acceleration reversed direction significantly
          _waitingForValley = false;
        }
      }
    }

    // 4. Peak Detection and Pattern Validation
    if (!_waitingForValley && magnitude >= _threshold) {
      final int timeSinceLast = _peakCount == 0 ? 999999 : (now - _lastPeakTimestamp);

      if (timeSinceLast < AppConstants.minTimeBetweenPeaksMs) {
        // High frequency vibration/tap (<100ms), reject as noise
        _rejectedTooFast++;
      } else {
        // Determine dominant axis
        final double absX = x.abs();
        final double absY = y.abs();
        final double absZ = z.abs();
        int domAxis = 0;
        double domVal = x;
        if (absY > absX && absY > absZ) {
          domAxis = 1;
          domVal = y;
        } else if (absZ > absX && absZ > absY) {
          domAxis = 2;
          domVal = z;
        }

        _peakCount++;
        _lastPeakTimestamp = now;
        _waitingForValley = true;
        _lastPeakAxis = domAxis;
        _lastPeakSign = domVal >= 0 ? 1.0 : -1.0;

        if (_peakCount == 1) {
          _firstPeakTimestamp = now;
          if (_debugLogsEnabled) {
            debugPrint('[ShakeDetector] Peak 1/4 (mag: ${magnitude.toStringAsFixed(2)}, axis: $domAxis)');
          }
        } else {
          if (_debugLogsEnabled) {
            debugPrint('[ShakeDetector] Peak $_peakCount/4 (interval: ${timeSinceLast}ms, mag: ${magnitude.toStringAsFixed(2)})');
          }
        }

        // 5. Require at least 4 distinct valid peaks within window
        if (_peakCount >= AppConstants.minShakePeaks) {
          if (_debugLogsEnabled) {
            debugPrint(
              '[ShakeDetector] VALID INTENTIONAL SHAKE DETECTED! Total time: ${now - _firstPeakTimestamp}ms. Triggering popup.',
            );
          }

          _lastTriggerTimestamp = now;
          _lastShakeTimestamp = DateTime.now();
          _peakCount = 0;
          _waitingForValley = false;

          _updateDebugNotifier(
            x: x,
            y: y,
            z: z,
            magnitude: magnitude,
            state: 'TRIGGERED',
          );

          _triggerShake();
          return;
        }
      }
    }

    final String currentState = _peakCount > 0 ? 'DETECTING' : 'IDLE';
    _updateDebugNotifier(
      x: x,
      y: y,
      z: z,
      magnitude: magnitude,
      state: currentState,
    );
  }

  void _updateDebugNotifier({
    double? x,
    double? y,
    double? z,
    double? magnitude,
    String? state,
  }) {
    debugNotifier.value = ShakeDebugInfo(
      x: x ?? debugNotifier.value.x,
      y: y ?? debugNotifier.value.y,
      z: z ?? debugNotifier.value.z,
      magnitude: magnitude ?? debugNotifier.value.magnitude,
      peakCount: _peakCount,
      requiredPeaks: AppConstants.minShakePeaks,
      state: state ?? debugNotifier.value.state,
      threshold: _threshold,
      sensitivityLevel: _sensitivityLevel,
      rejectedSingleSpikes: _rejectedSingleSpikes,
      rejectedTimeouts: _rejectedTimeouts,
      rejectedTooFast: _rejectedTooFast,
      rejectedCooldowns: _rejectedCooldowns,
      lastShakeTimestamp: _lastShakeTimestamp,
      debugLogsEnabled: _debugLogsEnabled,
    );
  }

  void _triggerShake() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
    if (_onShakeCallback != null && !_isSheetOpen) {
      _onShakeCallback!();
    }
  }

  /// Manually simulates a shake event (useful for Settings Test button or Emulators)
  void simulateShake() {
    if (!_isEnabled) return;
    _lastShakeTimestamp = DateTime.now();
    _triggerShake();
  }

  void dispose() {
    stopListening();
    _onShakeCallback = null;
    debugNotifier.dispose();
  }
}

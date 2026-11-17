import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/shake_detection_service.dart';
import '../utils/constants.dart';
import '../widgets/expense_entry_sheet.dart';

class ShakeDebugScreen extends StatefulWidget {
  const ShakeDebugScreen({super.key});

  @override
  State<ShakeDebugScreen> createState() => _ShakeDebugScreenState();
}

class _ShakeDebugScreenState extends State<ShakeDebugScreen> {
  final ShakeDetectionService _shakeService = ShakeDetectionService.instance;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('Shake Sensor Debugger'),
        actions: [
          IconButton(
            tooltip: 'Reset Counters',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              HapticFeedback.lightImpact();
              _shakeService.resetDebugCounters();
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<ShakeDebugInfo>(
        valueListenable: _shakeService.debugNotifier,
        builder: (context, info, child) {
          final isOverThreshold = info.magnitude >= info.threshold;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primaryGold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.science_rounded, color: AppColors.primaryGold, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Test picking up phone, pocket removal, and intentional shaking here in real-time. Notice how pocket pulls are completely rejected.',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 1. ENGINE STATE & MAGNITUDE CARD
                _buildCard(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Detection Engine State',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          _buildStateBadge(info.state),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Magnitude readout
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            info.magnitude.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: isOverThreshold
                                  ? AppColors.primaryGold
                                  : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'm/s²',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Threshold: ${info.threshold.toStringAsFixed(1)} m/s²',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Sensitivity: ${info.sensitivityLevel.toUpperCase()}',
                                style: const TextStyle(fontSize: 11, color: AppColors.primaryGold, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Magnitude Progress Bar with threshold marker
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (info.magnitude / 10.0).clamp(0.0, 1.0),
                              minHeight: 12,
                              backgroundColor: isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isOverThreshold ? AppColors.primaryGold : AppColors.accentGreen,
                              ),
                            ),
                          ),
                          // Threshold Indicator Line
                          Positioned(
                            left: ((info.threshold / 10.0).clamp(0.0, 1.0)) *
                                (MediaQuery.of(context).size.width - 64),
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 3,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Linear X, Y, Z readout
                      Row(
                        children: [
                          Expanded(child: _buildAxisTile('Lin X', info.x, isDark)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildAxisTile('Lin Y', info.y, isDark)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildAxisTile('Lin Z', info.z, isDark)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. MULTI-PEAK VALIDATION PATTERN CARD
                _buildCard(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Multi-Peak Pattern Verification',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          Text(
                            'Required: 4 Peaks in 1.5s',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 4 Peak indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(info.requiredPeaks, (index) {
                          final isHit = index < info.peakCount;
                          return Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isHit
                                      ? AppColors.primaryGold
                                      : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB)),
                                  shape: BoxShape.circle,
                                  boxShadow: isHit
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primaryGold.withValues(alpha: 0.5),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'P${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: isHit ? AppColors.darkNavy : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isHit ? 'VALID' : 'WAITING',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isHit ? AppColors.primaryGold : Colors.grey,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        info.peakCount == 0
                            ? 'Waiting for shake rhythm... Single spikes (pocket pulls) are ignored.'
                            : 'Detecting rhythm: ${info.peakCount} / ${info.requiredPeaks} peaks registered.',
                        style: TextStyle(
                          fontSize: 12,
                          color: info.peakCount > 0 ? AppColors.primaryGold : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 3. REJECTION STATS & METRICS
                _buildCard(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Accidental Movement Rejections',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      _buildMetricRow(
                        icon: Icons.directions_walk_rounded,
                        color: AppColors.accentRed,
                        label: 'Walking / Stairs Steps Rejected',
                        value: '${info.rejectedWalkingStairs}',
                        subtitle: 'Paced footfalls (>300ms cadence) reset before accumulating 4 peaks',
                      ),
                      const Divider(height: 16),
                      _buildMetricRow(
                        icon: Icons.swap_horiz_rounded,
                        color: AppColors.accentOrange,
                        label: 'Same-Direction Reversals Rejected',
                        value: '${info.rejectedSameDirection}',
                        subtitle: 'Unilateral impacts (steps/running) rejected because movement didn’t alternate',
                      ),
                      const Divider(height: 16),
                      _buildMetricRow(
                        icon: Icons.front_hand_rounded,
                        color: AppColors.primaryGold,
                        label: 'Single Spikes Rejected (Pocket / Table)',
                        value: '${info.rejectedSingleSpikes}',
                        subtitle: 'Isolated movement spike that did not repeat in a rhythm',
                      ),
                      const Divider(height: 16),
                      _buildMetricRow(
                        icon: Icons.timer_off_rounded,
                        color: AppColors.accentBlue,
                        label: 'Rhythm Timeouts (>300ms or >1.1s window)',
                        value: '${info.rejectedTimeouts}',
                        subtitle: 'Movements separated by >300ms or exceeding 1.1s total window',
                      ),
                      const Divider(height: 16),
                      _buildMetricRow(
                        icon: Icons.vibration_rounded,
                        color: AppColors.accentPurple,
                        label: 'High-Frequency Noise (<100ms)',
                        value: '${info.rejectedTooFast}',
                        subtitle: 'Vibrations or motor taps too rapid to be human shake',
                      ),
                      const Divider(height: 16),
                      _buildMetricRow(
                        icon: Icons.hourglass_disabled_rounded,
                        color: Colors.grey,
                        label: 'Cooldown Blocks (2.5s)',
                        value: '${info.rejectedCooldowns}',
                        subtitle: 'Movements blocked during 2.5s post-shake cooldown',
                      ),
                      const Divider(height: 16),
                      _buildMetricRow(
                        icon: Icons.check_circle_rounded,
                        color: AppColors.accentGreen,
                        label: 'Last Valid Shake Triggered',
                        value: info.lastShakeTimestamp != null
                            ? '${info.lastShakeTimestamp!.hour.toString().padLeft(2, '0')}:${info.lastShakeTimestamp!.minute.toString().padLeft(2, '0')}:${info.lastShakeTimestamp!.second.toString().padLeft(2, '0')}'
                            : 'None',
                        subtitle: 'Timestamp of the last verified 4-peak shake pattern',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. SENSITIVITY LEVEL SWITCHER
                _buildCard(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sensitivity Level',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildSensitivityOption(
                            label: 'Low',
                            desc: '4.2 m/s² (Firm)',
                            isSelected: settings.shakeSensitivityLevel.toLowerCase() == 'low',
                            onTap: () => settings.updateShakeSensitivityLevel('low'),
                          ),
                          const SizedBox(width: 8),
                          _buildSensitivityOption(
                            label: 'Medium',
                            desc: '3.0 m/s² (Default)',
                            isSelected: settings.shakeSensitivityLevel.toLowerCase() == 'medium',
                            onTap: () => settings.updateShakeSensitivityLevel('medium'),
                          ),
                          const SizedBox(width: 8),
                          _buildSensitivityOption(
                            label: 'High',
                            desc: '2.4 m/s² (Light)',
                            isSelected: settings.shakeSensitivityLevel.toLowerCase() == 'high',
                            onTap: () => settings.updateShakeSensitivityLevel('high'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 5. TEST & ACTIONS
                _buildCard(
                  isDark: isDark,
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Verbose Console Logging', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        subtitle: const Text('Print detailed sensor intervals to logcat / console', style: TextStyle(fontSize: 11.5)),
                        value: _shakeService.debugLogsEnabled,
                        activeThumbColor: AppColors.primaryGold,
                        onChanged: (val) {
                          _shakeService.setDebugLogsEnabled(val);
                        },
                      ),
                      const Divider(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGold,
                            foregroundColor: AppColors.darkNavy,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.touch_app_rounded),
                          label: const Text('Simulate Valid Shake Trigger', style: TextStyle(fontWeight: FontWeight.w800)),
                          onPressed: () {
                            HapticFeedback.heavyImpact();
                            ExpenseEntrySheet.show(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard({required bool isDark, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: child,
    );
  }

  Widget _buildStateBadge(String state) {
    Color color;
    switch (state) {
      case 'TRIGGERED':
        color = AppColors.accentGreen;
        break;
      case 'DETECTING':
        color = AppColors.primaryGold;
        break;
      case 'COOLDOWN':
        color = AppColors.accentBlue;
        break;
      case 'IDLE':
      default:
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        state,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAxisTile(String label, double value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            value >= 0 ? '+${value.toStringAsFixed(2)}' : value.toStringAsFixed(2),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSensitivityOption({
    required String label,
    required String desc,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryGold.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryGold : Colors.grey.withValues(alpha: 0.3),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: isSelected ? AppColors.primaryGoldDark : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? AppColors.primaryGoldDark : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

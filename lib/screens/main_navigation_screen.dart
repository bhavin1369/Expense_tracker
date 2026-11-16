import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../services/background_shake_service.dart';
import '../services/shake_detection_service.dart';
import '../utils/constants.dart';
import '../widgets/expense_entry_sheet.dart';
import 'analytics_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  static void switchToTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainNavigationScreenState>();
    state?.setTab(index);
  }

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  final ShakeDetectionService _shakeService = ShakeDetectionService.instance;

  void setTab(int index) {
    if (index >= 0 && index < _screens.length) {
      HapticFeedback.selectionClick();
      setState(() => _currentIndex = index);
    }
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    HistoryScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Register shake callback to automatically launch expense entry sheet
    _shakeService.registerCallback(_onShakeTriggered);
    BackgroundShakeService.instance.registerBackgroundShakeCallback(_onShakeTriggered);

    // Register callback for when an expense is added from native floating overlay
    BackgroundShakeService.instance.registerOverlayExpenseAddedCallback(_onOverlayExpenseAdded);
  }

  void _onShakeTriggered() {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    ExpenseEntrySheet.show(context);
  }

  void _onOverlayExpenseAdded(Map<String, dynamic> data) async {
    if (!mounted) return;
    debugPrint('Received overlay expense added event: $data');
    final expenseProvider = context.read<ExpenseProvider>();
    await expenseProvider.loadExpenses();
    await expenseProvider.syncPendingExpenses();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _shakeService.pause();
    } else if (state == AppLifecycleState.resumed) {
      _shakeService.resume();
      if (mounted) {
        context.read<SettingsProvider>().checkBackgroundServiceStatus();
        context.read<ExpenseProvider>().loadExpenses().then((_) {
          if (mounted) {
            context.read<ExpenseProvider>().syncPendingExpenses();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shakeService.unregisterCallback();
    BackgroundShakeService.instance.unregisterBackgroundShakeCallback();
    BackgroundShakeService.instance.unregisterOverlayExpenseAddedCallback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            HapticFeedback.selectionClick();
            setState(() => _currentIndex = index);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart_rounded),
              label: 'Analytics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          ExpenseEntrySheet.show(context);
        },
        backgroundColor: AppColors.primaryGold,
        foregroundColor: AppColors.darkNavy,
        elevation: 4,
        shape: const CircleBorder(),
        tooltip: 'Add Expense (or Shake phone)',
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }
}

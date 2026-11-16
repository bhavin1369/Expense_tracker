import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../services/excel_service.dart';
import '../services/settings_service.dart';
import '../utils/constants.dart';
import 'main_navigation_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initializeAndNavigate();
    });
  }

  Future<void> _initializeAndNavigate() async {
    // Initialize providers and database
    final settingsProvider = context.read<SettingsProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final expenseProvider = context.read<ExpenseProvider>();

    await Future.wait([
      settingsProvider.initialize(),
      categoryProvider.loadCategories(),
      expenseProvider.loadExpenses(),
    ]);

    // Ensure permanent Excel workbook is initialized
    await ExcelService.instance.ensurePermanentWorkbookExists(
      customPath: settingsProvider.excelFilePath,
    );

    final isFirst = await SettingsService.instance.isFirstLaunch();

    // Small delay for smooth splash transition
    await Future.delayed(const Duration(milliseconds: 1400));

    if (mounted) {
      if (isFirst || settingsProvider.userName == AppConstants.defaultUserName) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Golden glowing icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryGold,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGold.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.vibration_rounded,
                    color: AppColors.primaryGold,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Shake Expense Tracker',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Shake your phone to add expenses instantly',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGold,
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

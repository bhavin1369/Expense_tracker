import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../services/shake_detection_service.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_utils.dart';
import '../utils/icon_helper.dart';
import 'add_category_dialog.dart';
import 'amount_input.dart';
import 'category_card.dart';

class ExpenseEntrySheet extends StatefulWidget {
  final VoidCallback? onExpenseAdded;
  final String initialType; // 'expense' or 'income'

  const ExpenseEntrySheet({
    super.key,
    this.onExpenseAdded,
    this.initialType = 'expense',
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onExpenseAdded,
    String initialType = 'expense',
  }) async {
    ShakeDetectionService.instance.setSheetOpenState(true);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExpenseEntrySheet(
        onExpenseAdded: onExpenseAdded,
        initialType: initialType,
      ),
    );
    ShakeDetectionService.instance.setSheetOpenState(false);
  }

  @override
  State<ExpenseEntrySheet> createState() => _ExpenseEntrySheetState();
}

class _ExpenseEntrySheetState extends State<ExpenseEntrySheet> {
  int _currentStep = 1; // 1: Amount, 2: Category, 3: Remarks & Mode
  late String _transactionType; // 'expense' or 'income'

  // Step 1: Amount
  final TextEditingController _amountController = TextEditingController();
  double _amount = 0.0;

  // Step 2: Category
  CategoryModel? _selectedCategory;
  final TextEditingController _categorySearchController = TextEditingController();
  String _categorySearchQuery = '';

  // Step 3: Remarks, Payment Mode, Date & Time
  final TextEditingController _noteController = TextEditingController();
  String _selectedPaymentMode = 'UPI';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _transactionType = widget.initialType;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categorySearchController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get _isIncome => _transactionType == 'income';

  void _goToStep2() {
    final parsed = double.tryParse(_amountController.text) ?? 0.0;
    if (parsed <= 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount greater than 0'),
          backgroundColor: AppColors.accentRed,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _amount = parsed;
      _currentStep = 2;
    });
  }

  void _goToStep3() {
    if (_selectedCategory == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isIncome ? 'Please select an income source' : 'Please select an expense category'),
          backgroundColor: AppColors.accentRed,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _currentStep = 3;
    });
  }

  Future<void> _applyExpense() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final expenseProvider = context.read<ExpenseProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    final success = await expenseProvider.addExpense(
      amount: _amount,
      categoryId: _selectedCategory!.id ?? 1,
      categoryName: _selectedCategory!.categoryName,
      note: _noteController.text,
      transactionType: _transactionType,
      paymentMode: _selectedPaymentMode,
      date: _selectedDate,
      time: _selectedTime,
      customExcelPath: settingsProvider.excelFilePath,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        await settingsProvider.recordExcelSync();
        if (!mounted) return;

        widget.onExpenseAdded?.call();
        Navigator.of(context).pop();

        final label = _isIncome ? 'Income' : 'Expense';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$label of ${CurrencyHelper.formatAmount(_amount, symbol: settingsProvider.currencySymbol)} added successfully!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: _isIncome ? AppColors.accentGreen : AppColors.primaryGold,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save transaction. Please try again.'),
            backgroundColor: AppColors.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol = context.watch<SettingsProvider>().currencySymbol;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Top Bar: Back, Title & Close
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    if (_currentStep > 1)
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => setState(() => _currentStep--),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: (_isIncome ? AppColors.accentGreen : AppColors.primaryGold).withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isIncome ? Icons.account_balance_wallet_rounded : Icons.vibration_rounded,
                          color: _isIncome ? AppColors.accentGreen : AppColors.primaryGold,
                          size: 18,
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _getStepTitle(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Simple Progress Indicator: Amount → Category → Remarks
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStepItem('Amount', 1),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF94A3B8)),
                      ),
                      _buildStepItem('Category', 2),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF94A3B8)),
                      ),
                      _buildStepItem('Remarks', 3),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Step Content
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _buildCurrentStepContent(currencySymbol, isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem(String title, int step) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCurrent = _currentStep == step;
    final isDone = _currentStep > step;

    Color color;
    if (isCurrent) {
      color = _isIncome ? AppColors.accentGreen : AppColors.primaryGold;
    } else if (isDone) {
      color = AppColors.accentGreen;
    } else {
      color = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isDone)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.check_circle_rounded, size: 14, color: AppColors.accentGreen),
          ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _getStepTitle() {
    final typeName = _isIncome ? 'Income' : 'Expense';
    switch (_currentStep) {
      case 1:
        return 'Step 1: Enter $typeName';
      case 2:
        return 'Step 2: Select ${_isIncome ? "Source" : "Category"}';
      case 3:
        return 'Step 3: Remarks & Mode';
      default:
        return 'Add $typeName';
    }
  }

  Widget _buildCurrentStepContent(String currencySymbol, bool isDark) {
    switch (_currentStep) {
      case 1:
        return _buildStep1Amount(currencySymbol, isDark);
      case 2:
        return _buildStep2Category(isDark);
      case 3:
        return _buildStep3NoteAndApply(currencySymbol, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // STEP 1: TRANSACTION TYPE TOGGLE + AMOUNT
  Widget _buildStep1Amount(String currencySymbol, bool isDark) {
    return SingleChildScrollView(
      key: const ValueKey(1),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          // Transaction Type Selector (Segmented Cards)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _transactionType = 'expense';
                        _selectedCategory = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isIncome ? const Color(0xFFE11D48) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: !_isIncome
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            'Expense',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: !_isIncome ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _transactionType = 'income';
                        _selectedCategory = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isIncome ? const Color(0xFF059669) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _isIncome
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF059669).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('💰', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            'Income',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: _isIncome ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          AmountInputWidget(
            controller: _amountController,
            currencySymbol: currencySymbol,
            onAmountChanged: (val) => _amount = val,
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _goToStep2,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isIncome ? AppColors.accentGreen : AppColors.primaryGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue to ${_isIncome ? "Source" : "Category"}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkNavy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, color: AppColors.darkNavy, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // STEP 2: CATEGORY (3 COLUMNS PER ROW)
  Widget _buildStep2Category(bool isDark) {
    final catProvider = context.watch<CategoryProvider>();
    final categories = _isIncome ? catProvider.incomeCategories : catProvider.expenseCategories;

    final filteredCategories = categories.where((c) {
      if (_categorySearchQuery.trim().isEmpty) return true;
      return c.categoryName.toLowerCase().contains(_categorySearchQuery.toLowerCase());
    }).toList();

    return Padding(
      key: const ValueKey(2),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      child: Column(
        children: [
          // Search & Add Category button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _categorySearchController,
                  decoration: InputDecoration(
                    hintText: _isIncome ? 'Search income sources...' : 'Search categories...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    isDense: true,
                    suffixIcon: _categorySearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _categorySearchController.clear();
                              setState(() => _categorySearchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _categorySearchQuery = val),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.darkNavy),
                label: const Text(
                  'Add',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkNavy,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (ctx) => const AddCategoryDialog(),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Categories Grid (3 COLUMNS)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.42,
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.98,
              ),
              itemCount: filteredCategories.length,
              itemBuilder: (context, index) {
                final category = filteredCategories[index];
                final isSelected = _selectedCategory?.id == category.id ||
                    (_selectedCategory == null &&
                        ((!_isIncome && category.categoryName == 'Food & Drinks') ||
                            (_isIncome && category.categoryName == 'Salary')));

                return CategoryCard(
                  category: category,
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCategory = category);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Continue Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                if (_selectedCategory == null && filteredCategories.isNotEmpty) {
                  _selectedCategory = filteredCategories.first;
                }
                _goToStep3();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isIncome ? AppColors.accentGreen : AppColors.primaryGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue to Remarks',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkNavy,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: AppColors.darkNavy, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // STEP 3: REMARKS, PAYMENT MODE & APPLY
  Widget _buildStep3NoteAndApply(String currencySymbol, bool isDark) {
    final catColor = IconHelper.parseColor(_selectedCategory?.color ?? (_isIncome ? '#10B981' : '#FF7043'));
    final iconData = IconHelper.getIcon(_selectedCategory?.icon ?? (_isIncome ? 'payments' : 'fastfood_rounded'));

    return SingleChildScrollView(
      key: const ValueKey(3),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected Summary Badge (Amount + Category + Type)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: catColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _isIncome
                                  ? AppColors.accentGreen.withValues(alpha: 0.2)
                                  : const Color(0xFFE11D48).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _isIncome ? 'INCOME' : 'EXPENSE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _isIncome ? AppColors.accentGreen : const Color(0xFFE11D48),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _selectedCategory?.categoryName ?? 'Category',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        CurrencyHelper.formatAmount(_amount, symbol: currencySymbol),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _isIncome ? AppColors.accentGreen : const Color(0xFFE11D48),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _currentStep = 1),
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Payment Mode Section
          Text(
            'Payment Mode',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: AppConstants.paymentModes.map((pm) {
                final isSelected = _selectedPaymentMode == pm;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(pm),
                    selected: isSelected,
                    selectedColor: AppColors.primaryGold,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? AppColors.darkNavy : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    onSelected: (val) {
                      if (val) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedPaymentMode = pm);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Remarks / Note Field
          Text(
            'Remarks / Note (Optional)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _noteController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: _isIncome
                  ? 'e.g. Monthly salary, Client payout, Dividend'
                  : 'e.g. Lunch with team, Fuel, Groceries',
            ),
          ),
          const SizedBox(height: 8),

          // Quick Suggestions Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: (_isIncome
                      ? ['Salary', 'Bonus', 'Client Payout', 'Dividend', 'Rent Received', 'Gift']
                      : ['Lunch', 'Coffee', 'Dinner', 'Auto/Taxi', 'Groceries', 'Fuel', 'Shopping'])
                  .map(
                    (tag) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(tag, style: const TextStyle(fontSize: 11.5)),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          if (_noteController.text.trim().isEmpty) {
                            _noteController.text = tag;
                          } else {
                            _noteController.text += ', $tag';
                          }
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Date & Time pickers
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_rounded, size: 14),
                  label: Text(AppDateUtils.formatDate(_selectedDate), style: const TextStyle(fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _pickDate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.access_time_rounded, size: 14),
                  label: Text(_selectedTime.format(context), style: const TextStyle(fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Apply Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _applyExpense,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isIncome ? AppColors.accentGreen : const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          _isIncome ? 'Apply Income' : 'Apply Expense',
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

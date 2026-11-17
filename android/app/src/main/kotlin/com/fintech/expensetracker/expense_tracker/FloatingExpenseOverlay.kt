package com.fintech.expensetracker.expense_tracker

import android.annotation.SuppressLint
import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.widget.*
import java.text.SimpleDateFormat
import java.util.*

object FloatingExpenseOverlay {

    var isShowing: Boolean = false
        private set

    private var currentRootView: View? = null
    private var currentWindowManager: WindowManager? = null

    // State
    private var currentTransactionType: String = "expense" // "expense" or "income"
    private var currentAmount: Double = 0.0
    private var selectedCategory: CategoryData? = null
    private var currentNote: String = ""
    private var selectedPaymentMode: String = "UPI"
    private var currencySymbol: String = "₹"
    private var allCategories: List<CategoryData> = emptyList()

    data class CategoryData(
        val id: Long,
        val name: String,
        val colorHex: String,
        val icon: String,
        val categoryType: String = "expense"
    )

    fun show(context: Context) {
        if (isShowing) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
            return
        }

        Handler(Looper.getMainLooper()).post {
            try {
                // Load data from shared SQLite
                currencySymbol = loadCurrency(context)
                allCategories = loadCategories(context)
                currentTransactionType = "expense"
                selectedCategory = allCategories.firstOrNull { it.categoryType == "expense" && it.name == "Food & Drinks" }
                    ?: allCategories.firstOrNull { it.categoryType == "expense" }

                currentAmount = 0.0
                currentNote = ""
                selectedPaymentMode = "UPI"

                val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                currentWindowManager = wm

                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                    else
                        @Suppress("DEPRECATION")
                        WindowManager.LayoutParams.TYPE_PHONE,
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.CENTER
                    softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE or
                            WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE
                }

                val rootView = buildOverlayView(context)
                currentRootView = rootView

                wm.addView(rootView, params)
                isShowing = true
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    fun dismiss() {
        if (!isShowing) return
        Handler(Looper.getMainLooper()).post {
            try {
                currentRootView?.let { view ->
                    val imm = view.context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                    imm?.hideSoftInputFromWindow(view.windowToken, 0)
                    currentWindowManager?.removeView(view)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                currentRootView = null
                currentWindowManager = null
                isShowing = false
            }
        }
    }

    private fun dp(context: Context, value: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value,
            context.resources.displayMetrics
        ).toInt()
    }

    // ==========================================
    // VIEW BUILDER
    // ==========================================

    @SuppressLint("ClickableViewAccessibility")
    private fun buildOverlayView(context: Context): View {
        // 1. Root Scrim Container (Dark dimming background)
        val rootLayout = FrameLayout(context).apply {
            setBackgroundColor(Color.argb(160, 10, 15, 30))
            isClickable = true
            isFocusable = true
        }

        // Tap outside card to dismiss
        rootLayout.setOnClickListener {
            dismiss()
        }

        // 2. Central Card Layout
        val cardLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadius = dp(context, 22f).toFloat()
                setStroke(dp(context, 2f), Color.parseColor("#D4AF37")) // Gold border
            })
            elevation = dp(context, 16f).toFloat()
            setPadding(dp(context, 20f), dp(context, 18f), dp(context, 20f), dp(context, 20f))
            isClickable = true
            isFocusable = true
        }

        val cardParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
            val margin = dp(context, 20f)
            setMargins(margin, margin, margin, margin)
        }
        cardLayout.layoutParams = cardParams
        rootLayout.addView(cardLayout)

        // 3. Step Container (Switches between Step 0: Type, Step 1: Amount, Step 2: Category, Step 3: Note)
        val stepContainer = FrameLayout(context)
        cardLayout.addView(stepContainer)

        // Show Step 0 (Type Selection matching video prompt) initially
        showStep0TypeSelection(context, cardLayout, stepContainer)

        return rootLayout
    }

    // ==========================================
    // STEP 0: TYPE SELECTION (EXPENSE VS INCOME)
    // ==========================================

    private fun showStep0TypeSelection(context: Context, cardLayout: LinearLayout, stepContainer: FrameLayout) {
        stepContainer.removeAllViews()

        val stepView = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
        }

        // Top Header
        val headerRow = RelativeLayout(context)
        val titleView = TextView(context).apply {
            text = "QUICK TRANSACTION"
            textSize = 17f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#0F172A"))
        }
        val closeBtn = ImageView(context).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setColorFilter(Color.parseColor("#64748B"))
            val p = dp(context, 6f)
            setPadding(p, p, p, p)
            setOnClickListener { dismiss() }
        }
        val closeParams = RelativeLayout.LayoutParams(dp(context, 32f), dp(context, 32f)).apply {
            addRule(RelativeLayout.ALIGN_PARENT_RIGHT)
            addRule(RelativeLayout.CENTER_VERTICAL)
        }
        headerRow.addView(titleView)
        headerRow.addView(closeBtn, closeParams)
        stepView.addView(headerRow)

        val subtext = TextView(context).apply {
            text = "What would you like to record?"
            textSize = 13f
            setTextColor(Color.parseColor("#64748B"))
            val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(context, 4f)
                bottomMargin = dp(context, 16f)
            }
            layoutParams = p
        }
        stepView.addView(subtext)

        // Two prominent cards: Expense vs Income
        val typesRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            layoutParams = p
        }

        // 1. Expense Card
        val expenseCard = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(Color.parseColor("#FFF1F2")) // Soft red tint
                cornerRadius = dp(context, 16f).toFloat()
                setStroke(dp(context, 1.5f), Color.parseColor("#F43F5E"))
            })
            val pad = dp(context, 16f)
            setPadding(pad, pad, pad, pad)
            val p = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                rightMargin = dp(context, 8f)
            }
            layoutParams = p
            setOnClickListener {
                currentTransactionType = "expense"
                selectedCategory = allCategories.firstOrNull { it.categoryType == "expense" && it.name == "Food & Drinks" }
                    ?: allCategories.firstOrNull { it.categoryType == "expense" }
                showStep1Amount(context, cardLayout, stepContainer)
            }
        }
        val expIcon = TextView(context).apply {
            text = "🔥"
            textSize = 34f
            gravity = Gravity.CENTER
        }
        val expTitle = TextView(context).apply {
            text = "Expense"
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#E11D48"))
            val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(context, 4f)
            }
            layoutParams = p
        }
        val expSub = TextView(context).apply {
            text = "Money Out"
            textSize = 11.5f
            setTextColor(Color.parseColor("#881337"))
        }
        expenseCard.addView(expIcon)
        expenseCard.addView(expTitle)
        expenseCard.addView(expSub)

        // 2. Income Card
        val incomeCard = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(Color.parseColor("#F0FDF4")) // Soft green tint
                cornerRadius = dp(context, 16f).toFloat()
                setStroke(dp(context, 1.5f), Color.parseColor("#10B981"))
            })
            val pad = dp(context, 16f)
            setPadding(pad, pad, pad, pad)
            val p = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                leftMargin = dp(context, 8f)
            }
            layoutParams = p
            setOnClickListener {
                currentTransactionType = "income"
                selectedCategory = allCategories.firstOrNull { it.categoryType == "income" && it.name == "Salary" }
                    ?: allCategories.firstOrNull { it.categoryType == "income" }
                showStep1Amount(context, cardLayout, stepContainer)
            }
        }
        val incIcon = TextView(context).apply {
            text = "💰"
            textSize = 34f
            gravity = Gravity.CENTER
        }
        val incTitle = TextView(context).apply {
            text = "Income"
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#059669"))
            val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(context, 4f)
            }
            layoutParams = p
        }
        val incSub = TextView(context).apply {
            text = "Money In"
            textSize = 11.5f
            setTextColor(Color.parseColor("#064E3B"))
        }
        incomeCard.addView(incIcon)
        incomeCard.addView(incTitle)
        incomeCard.addView(incSub)

        typesRow.addView(expenseCard)
        typesRow.addView(incomeCard)
        stepView.addView(typesRow)

        stepContainer.addView(stepView)
    }

    // ==========================================
    // STEP 1: AMOUNT VIEW
    // ==========================================

    private fun showStep1Amount(context: Context, cardLayout: LinearLayout, stepContainer: FrameLayout) {
        stepContainer.removeAllViews()

        val stepView = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
        }

        // Top Header: Title & Close Button
        val headerRow = RelativeLayout(context)
        val backBtn = ImageView(context).apply {
            setImageResource(android.R.drawable.ic_media_previous)
            setColorFilter(Color.parseColor("#0F172A"))
            val p = dp(context, 4f)
            setPadding(p, p, p, p)
            setOnClickListener {
                showStep0TypeSelection(context, cardLayout, stepContainer)
            }
        }
        val backParams = RelativeLayout.LayoutParams(dp(context, 32f), dp(context, 32f)).apply {
            addRule(RelativeLayout.ALIGN_PARENT_LEFT)
            addRule(RelativeLayout.CENTER_VERTICAL)
        }
        val isIncome = currentTransactionType == "income"
        val titleView = TextView(context).apply {
            text = if (isIncome) "ADD INCOME 💰" else "ADD EXPENSE 🔥"
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(if (isIncome) Color.parseColor("#059669") else Color.parseColor("#E11D48"))
            val p = RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.WRAP_CONTENT, RelativeLayout.LayoutParams.WRAP_CONTENT).apply {
                addRule(RelativeLayout.CENTER_IN_PARENT)
            }
            layoutParams = p
        }
        val closeBtn = ImageView(context).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setColorFilter(Color.parseColor("#64748B"))
            val p = dp(context, 6f)
            setPadding(p, p, p, p)
            setOnClickListener { dismiss() }
        }
        val closeParams = RelativeLayout.LayoutParams(dp(context, 32f), dp(context, 32f)).apply {
            addRule(RelativeLayout.ALIGN_PARENT_RIGHT)
            addRule(RelativeLayout.CENTER_VERTICAL)
        }
        headerRow.addView(backBtn, backParams)
        headerRow.addView(titleView)
        headerRow.addView(closeBtn, closeParams)
        stepView.addView(headerRow)

        // Progress Indicator
        stepView.addView(buildProgressIndicator(context, 1))

        // Type Switcher Row (Inline toggle so user can easily flip)
        val toggleRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(Color.parseColor("#F1F5F9"))
                cornerRadius = dp(context, 12f).toFloat()
            })
            val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(context, 38f)).apply {
                topMargin = dp(context, 10f)
            }
            layoutParams = p
            setPadding(dp(context, 3f), dp(context, 3f), dp(context, 3f), dp(context, 3f))
        }

        val expToggle = TextView(context).apply {
            text = "🔥 Expense"
            textSize = 13f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setTextColor(if (!isIncome) Color.WHITE else Color.parseColor("#64748B"))
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(if (!isIncome) Color.parseColor("#E11D48") else Color.TRANSPARENT)
                cornerRadius = dp(context, 10f).toFloat()
            })
            val p = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f)
            layoutParams = p
            setOnClickListener {
                if (currentTransactionType != "expense") {
                    currentTransactionType = "expense"
                    selectedCategory = allCategories.firstOrNull { it.categoryType == "expense" }
                    showStep1Amount(context, cardLayout, stepContainer)
                }
            }
        }

        val incToggle = TextView(context).apply {
            text = "💰 Income"
            textSize = 13f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setTextColor(if (isIncome) Color.WHITE else Color.parseColor("#64748B"))
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(if (isIncome) Color.parseColor("#059669") else Color.TRANSPARENT)
                cornerRadius = dp(context, 10f).toFloat()
            })
            val p = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f)
            layoutParams = p
            setOnClickListener {
                if (currentTransactionType != "income") {
                    currentTransactionType = "income"
                    selectedCategory = allCategories.firstOrNull { it.categoryType == "income" }
                    showStep1Amount(context, cardLayout, stepContainer)
                }
            }
        }
        toggleRow.addView(expToggle)
        toggleRow.addView(incToggle)
        stepView.addView(toggleRow)

        // Amount Box Container
        val amountBox = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(Color.parseColor("#F8F9FA"))
                cornerRadius = dp(context, 16f).toFloat()
                setStroke(dp(context, 1.2f), Color.parseColor("#E2E8F0"))
            })
            setPadding(dp(context, 14f), dp(context, 14f), dp(context, 14f), dp(context, 14f))
        }
        val boxParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(context, 12f)
        }
        stepView.addView(amountBox, boxParams)

        val promptText = TextView(context).apply {
            text = if (isIncome) "ENTER INCOME AMOUNT" else "ENTER EXPENSE AMOUNT"
            textSize = 11f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#64748B"))
            letterSpacing = 0.08f
        }
        amountBox.addView(promptText)

        // Currency + Amount EditText
        val inputRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        val currencyView = TextView(context).apply {
            text = currencySymbol
            textSize = 32f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(if (isIncome) Color.parseColor("#10B981") else Color.parseColor("#D4AF37"))
        }
        val amountEditText = EditText(context).apply {
            hint = "0"
            textSize = 36f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#0F172A"))
            setHintTextColor(Color.parseColor("#94A3B8"))
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
            setBackgroundColor(Color.TRANSPARENT)
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(context, 8f), 0, 0, 0)
            if (currentAmount > 0) {
                setText(if (currentAmount % 1 == 0.0) currentAmount.toInt().toString() else currentAmount.toString())
                setSelection(text.length)
            }
        }
        inputRow.addView(currencyView)
        inputRow.addView(amountEditText)
        amountBox.addView(inputRow)

        // Auto Focus and show keyboard
        amountEditText.postDelayed({
            amountEditText.requestFocus()
            val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            imm?.showSoftInput(amountEditText, InputMethodManager.SHOW_IMPLICIT)
        }, 150)

        // Quick add chips
        val chipsScroll = HorizontalScrollView(context).apply {
            isHorizontalScrollBarEnabled = false
            overScrollMode = View.OVER_SCROLL_NEVER
        }
        val chipsRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(context, 10f), 0, 0)
        }
        val quickAmounts = if (isIncome) listOf(500, 1000, 2000, 5000, 10000) else listOf(50, 100, 200, 500, 1000)
        for (q in quickAmounts) {
            val chip = TextView(context).apply {
                text = "+$currencySymbol$q"
                textSize = 12.5f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(if (isIncome) Color.parseColor("#059669") else Color.parseColor("#B8860B"))
                setBackgroundDrawable(GradientDrawable().apply {
                    setColor(if (isIncome) Color.parseColor("#DCFCE7") else Color.parseColor("#F9F1D8"))
                    cornerRadius = dp(context, 12f).toFloat()
                    setStroke(dp(context, 1f), if (isIncome) Color.parseColor("#10B981") else Color.parseColor("#D4AF37"))
                })
                setPadding(dp(context, 12f), dp(context, 6f), dp(context, 12f), dp(context, 6f))
                val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                    rightMargin = dp(context, 8f)
                }
                layoutParams = p
                setOnClickListener {
                    val currentVal = amountEditText.text.toString().toDoubleOrNull() ?: 0.0
                    val updated = currentVal + q
                    val textVal = if (updated % 1 == 0.0) updated.toInt().toString() else String.format(Locale.US, "%.2f", updated)
                    amountEditText.setText(textVal)
                    amountEditText.setSelection(textVal.length)
                }
            }
            chipsRow.addView(chip)
        }
        chipsScroll.addView(chipsRow)
        stepView.addView(chipsScroll)

        // Error message view (hidden initially)
        val errorText = TextView(context).apply {
            text = "Please enter an amount greater than 0"
            textSize = 12f
            setTextColor(Color.parseColor("#EF4444"))
            visibility = View.GONE
            setPadding(0, dp(context, 6f), 0, 0)
        }
        stepView.addView(errorText)

        // Buttons Row: Close & Continue
        val btnRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(context, 16f)
            }
            layoutParams = p
        }

        val cancelBtn = Button(context).apply {
            text = "Close"
            textSize = 14f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#64748B"))
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(Color.parseColor("#F1F5F9"))
                cornerRadius = dp(context, 14f).toFloat()
            })
            val p = LinearLayout.LayoutParams(0, dp(context, 48f), 1f).apply {
                rightMargin = dp(context, 8f)
            }
            layoutParams = p
            setOnClickListener { dismiss() }
        }

        val continueBtn = Button(context).apply {
            text = "Continue →"
            textSize = 15f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#0F172A"))
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(Color.parseColor("#D4AF37")) // Gold
                cornerRadius = dp(context, 14f).toFloat()
            })
            val p = LinearLayout.LayoutParams(0, dp(context, 48f), 1.4f)
            layoutParams = p
            setOnClickListener {
                val entered = amountEditText.text.toString().toDoubleOrNull() ?: 0.0
                if (entered <= 0.0) {
                    errorText.visibility = View.VISIBLE
                    return@setOnClickListener
                }
                errorText.visibility = View.GONE
                currentAmount = entered

                // Hide soft keyboard before moving to categories
                val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                imm?.hideSoftInputFromWindow(amountEditText.windowToken, 0)

                showStep2Category(context, cardLayout, stepContainer)
            }
        }

        btnRow.addView(cancelBtn)
        btnRow.addView(continueBtn)
        stepView.addView(btnRow)

        stepContainer.addView(stepView)
    }

    // ==========================================
    // STEP 2: CATEGORY VIEW (3 COLUMNS)
    // ==========================================

    private fun showStep2Category(context: Context, cardLayout: LinearLayout, stepContainer: FrameLayout) {
        stepContainer.removeAllViews()

        val stepView = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
        }

        // Top Header with Back
        val headerRow = RelativeLayout(context)
        val backBtn = ImageView(context).apply {
            setImageResource(android.R.drawable.ic_media_previous)
            setColorFilter(Color.parseColor("#0F172A"))
            val p = dp(context, 4f)
            setPadding(p, p, p, p)
            setOnClickListener {
                showStep1Amount(context, cardLayout, stepContainer)
            }
        }
        val backParams = RelativeLayout.LayoutParams(dp(context, 32f), dp(context, 32f)).apply {
            addRule(RelativeLayout.ALIGN_PARENT_LEFT)
            addRule(RelativeLayout.CENTER_VERTICAL)
        }
        val isIncome = currentTransactionType == "income"
        val titleView = TextView(context).apply {
            text = if (isIncome) "SELECT INCOME SOURCE" else "SELECT CATEGORY"
            textSize = 15.5f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#0F172A"))
            val p = RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.WRAP_CONTENT, RelativeLayout.LayoutParams.WRAP_CONTENT).apply {
                addRule(RelativeLayout.CENTER_IN_PARENT)
            }
            layoutParams = p
        }
        headerRow.addView(backBtn, backParams)
        headerRow.addView(titleView)
        stepView.addView(headerRow)

        // Progress Indicator
        stepView.addView(buildProgressIndicator(context, 2))

        // Search Field
        val searchEditText = EditText(context).apply {
            hint = if (isIncome) "Search income sources..." else "Search categories..."
            textSize = 13.5f
            setTextColor(Color.parseColor("#0F172A"))
            setHintTextColor(Color.parseColor("#94A3B8"))
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(Color.parseColor("#F8F9FA"))
                cornerRadius = dp(context, 12f).toFloat()
                setStroke(dp(context, 1f), Color.parseColor("#E2E8F0"))
            })
            val pad = dp(context, 10f)
            setPadding(pad, pad, pad, pad)
            val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(context, 8f)
                bottomMargin = dp(context, 8f)
            }
            layoutParams = p
        }
        stepView.addView(searchEditText)

        // Category Grid Container (ScrollView with 3-column rows)
        val gridScrollView = ScrollView(context).apply {
            val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(context, 220f))
            layoutParams = p
            overScrollMode = View.OVER_SCROLL_NEVER
        }
        val gridContainer = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
        }
        gridScrollView.addView(gridContainer)
        stepView.addView(gridScrollView)

        val relevantCategories = allCategories.filter { it.categoryType == currentTransactionType }

        fun populateGrid(filterText: String) {
            gridContainer.removeAllViews()
            val filtered = relevantCategories.filter {
                filterText.isEmpty() || it.name.lowercase().contains(filterText.lowercase())
            }

            var currentRow: LinearLayout? = null
            for (i in filtered.indices) {
                if (i % 3 == 0) {
                    currentRow = LinearLayout(context).apply {
                        orientation = LinearLayout.HORIZONTAL
                        val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                            bottomMargin = dp(context, 8f)
                        }
                        layoutParams = p
                    }
                    gridContainer.addView(currentRow)
                }

                val cat = filtered[i]
                val isSelected = selectedCategory?.id == cat.id

                val itemCell = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    gravity = Gravity.CENTER
                    setBackgroundDrawable(GradientDrawable().apply {
                        setColor(if (isSelected) Color.parseColor("#FDF3D6") else Color.parseColor("#F8F9FA"))
                        cornerRadius = dp(context, 14f).toFloat()
                        setStroke(
                            if (isSelected) dp(context, 2.5f) else dp(context, 1f),
                            if (isSelected) Color.parseColor("#D4AF37") else Color.parseColor("#E2E8F0")
                        )
                    })
                    val pad = dp(context, 8f)
                    setPadding(pad, pad, pad, pad)
                    val p = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                        if (i % 3 != 2) rightMargin = dp(context, 6f)
                    }
                    layoutParams = p
                    setOnClickListener {
                        selectedCategory = cat
                        populateGrid(searchEditText.text.toString())
                    }
                }

                // Category Icon circle
                val iconCircle = TextView(context).apply {
                    text = getCategoryEmoji(cat.name)
                    textSize = 18f
                    gravity = Gravity.CENTER
                    val size = dp(context, 36f)
                    val p = LinearLayout.LayoutParams(size, size).apply {
                        bottomMargin = dp(context, 4f)
                    }
                    layoutParams = p
                    setBackgroundDrawable(GradientDrawable().apply {
                        val parsedColor = try { Color.parseColor(cat.colorHex) } catch (_: Exception) { Color.parseColor("#D4AF37") }
                        setColor(Color.argb(35, Color.red(parsedColor), Color.green(parsedColor), Color.blue(parsedColor)))
                        cornerRadius = dp(context, 18f).toFloat()
                    })
                }
                itemCell.addView(iconCircle)

                // Category Name
                val nameView = TextView(context).apply {
                    text = cat.name
                    textSize = 11f
                    typeface = if (isSelected) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
                    setTextColor(if (isSelected) Color.parseColor("#B8860B") else Color.parseColor("#1E293B"))
                    gravity = Gravity.CENTER
                    maxLines = 1
                }
                itemCell.addView(nameView)

                currentRow?.addView(itemCell)
            }

            // Pad last row if fewer than 3 items
            val remainder = filtered.size % 3
            if (remainder != 0 && currentRow != null) {
                for (j in 0 until (3 - remainder)) {
                    val dummy = View(context).apply {
                        val p = LinearLayout.LayoutParams(0, 1, 1f).apply {
                            if (j != (2 - remainder)) rightMargin = dp(context, 6f)
                        }
                        layoutParams = p
                    }
                    currentRow.addView(dummy)
                }
            }
        }

        populateGrid("")

        searchEditText.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                populateGrid(s?.toString() ?: "")
            }
            override fun afterTextChanged(s: Editable?) {}
        })

        // Continue Button
        val continueBtn = Button(context).apply {
            text = "Continue to Remarks →"
            textSize = 15f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#0F172A"))
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(Color.parseColor("#D4AF37"))
                cornerRadius = dp(context, 14f).toFloat()
            })
            val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(context, 48f)).apply {
                topMargin = dp(context, 12f)
            }
            layoutParams = p
            setOnClickListener {
                if (selectedCategory == null && relevantCategories.isNotEmpty()) {
                    selectedCategory = relevantCategories[0]
                }
                showStep3Note(context, cardLayout, stepContainer)
            }
        }
        stepView.addView(continueBtn)

        stepContainer.addView(stepView)
    }

    // ==========================================
    // STEP 3: NOTE, PAYMENT MODE & APPLY
    // ==========================================

    private fun showStep3Note(context: Context, cardLayout: LinearLayout, stepContainer: FrameLayout) {
        stepContainer.removeAllViews()

        val stepView = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
        }

        // Header with Back Button
        val headerRow = RelativeLayout(context)
        val backBtn = ImageView(context).apply {
            setImageResource(android.R.drawable.ic_media_previous)
            setColorFilter(Color.parseColor("#0F172A"))
            val p = dp(context, 4f)
            setPadding(p, p, p, p)
            setOnClickListener {
                showStep2Category(context, cardLayout, stepContainer)
            }
        }
        val backParams = RelativeLayout.LayoutParams(dp(context, 32f), dp(context, 32f)).apply {
            addRule(RelativeLayout.ALIGN_PARENT_LEFT)
            addRule(RelativeLayout.CENTER_VERTICAL)
        }
        val titleView = TextView(context).apply {
            text = "REMARKS & PAYMENT MODE"
            textSize = 15.5f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#0F172A"))
            val p = RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.WRAP_CONTENT, RelativeLayout.LayoutParams.WRAP_CONTENT).apply {
                addRule(RelativeLayout.CENTER_IN_PARENT)
            }
            layoutParams = p
        }
        headerRow.addView(backBtn, backParams)
        headerRow.addView(titleView)
        stepView.addView(headerRow)

        // Progress Indicator
        stepView.addView(buildProgressIndicator(context, 3))

        val isIncome = currentTransactionType == "income"

        // Selected Summary Badge (Type + Amount + Category)
        val summaryBadge = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(if (isIncome) Color.parseColor("#F0FDF4") else Color.parseColor("#FDF3D6"))
                cornerRadius = dp(context, 14f).toFloat()
                setStroke(dp(context, 1.2f), if (isIncome) Color.parseColor("#10B981") else Color.parseColor("#D4AF37"))
            })
            val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(context, 8f)
                bottomMargin = dp(context, 8f)
            }
            layoutParams = p
            val pad = dp(context, 10f)
            setPadding(pad, pad, pad, pad)
        }

        val catEmoji = TextView(context).apply {
            text = getCategoryEmoji(selectedCategory?.name ?: "")
            textSize = 22f
            setPadding(0, 0, dp(context, 10f), 0)
        }
        val summaryCol = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
        }
        val catNameView = TextView(context).apply {
            text = "${if (isIncome) "[INCOME]" else "[EXPENSE]"} ${selectedCategory?.name ?: "General"}"
            textSize = 13.5f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#0F172A"))
        }
        val amountView = TextView(context).apply {
            text = "$currencySymbol${if (currentAmount % 1 == 0.0) currentAmount.toInt().toString() else String.format(Locale.US, "%.2f", currentAmount)}"
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(if (isIncome) Color.parseColor("#10B981") else Color.parseColor("#E11D48"))
        }
        summaryCol.addView(catNameView)
        summaryCol.addView(amountView)
        summaryBadge.addView(catEmoji)
        summaryBadge.addView(summaryCol)
        stepView.addView(summaryBadge)

        // Payment Mode Label
        val modeLabel = TextView(context).apply {
            text = "PAYMENT MODE"
            textSize = 11f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#64748B"))
            letterSpacing = 0.06f
            val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(context, 4f)
                bottomMargin = dp(context, 4f)
            }
            layoutParams = p
        }
        stepView.addView(modeLabel)

        // Payment Mode Chips
        val modeScroll = HorizontalScrollView(context).apply {
            isHorizontalScrollBarEnabled = false
            overScrollMode = View.OVER_SCROLL_NEVER
        }
        val modeRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
        }
        val paymentModes = listOf("UPI", "Cash", "Credit Card", "Debit Card", "Bank Transfer", "Other")

        fun renderPaymentChips() {
            modeRow.removeAllViews()
            for (pm in paymentModes) {
                val isSelected = selectedPaymentMode == pm
                val chip = TextView(context).apply {
                    text = pm
                    textSize = 12f
                    typeface = if (isSelected) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
                    setTextColor(if (isSelected) Color.parseColor("#0F172A") else Color.parseColor("#64748B"))
                    setBackgroundDrawable(GradientDrawable().apply {
                        setColor(if (isSelected) Color.parseColor("#D4AF37") else Color.parseColor("#F1F5F9"))
                        cornerRadius = dp(context, 10f).toFloat()
                    })
                    setPadding(dp(context, 10f), dp(context, 6f), dp(context, 10f), dp(context, 6f))
                    val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                        rightMargin = dp(context, 6f)
                    }
                    layoutParams = p
                    setOnClickListener {
                        selectedPaymentMode = pm
                        renderPaymentChips()
                    }
                }
                modeRow.addView(chip)
            }
        }
        renderPaymentChips()
        modeScroll.addView(modeRow)
        stepView.addView(modeScroll)

        // Note Input Field
        val noteEditText = EditText(context).apply {
            hint = if (isIncome) "Remarks (e.g. Monthly salary, Client payout...)" else "Remarks (e.g. Lunch with team, Fuel...)"
            textSize = 13.5f
            setTextColor(Color.parseColor("#0F172A"))
            setHintTextColor(Color.parseColor("#94A3B8"))
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(Color.parseColor("#F8F9FA"))
                cornerRadius = dp(context, 12f).toFloat()
                setStroke(dp(context, 1.2f), Color.parseColor("#E2E8F0"))
            })
            val pad = dp(context, 10f)
            setPadding(pad, pad, pad, pad)
            minLines = 2
            maxLines = 2
            gravity = Gravity.TOP or Gravity.START
            if (currentNote.isNotEmpty()) {
                setText(currentNote)
            }
            val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(context, 8f)
            }
            layoutParams = p
        }
        stepView.addView(noteEditText)

        // Quick Tag Chips
        val tagsScroll = HorizontalScrollView(context).apply {
            isHorizontalScrollBarEnabled = false
            overScrollMode = View.OVER_SCROLL_NEVER
        }
        val tagsRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(context, 6f), 0, 0)
        }
        val quickTags = if (isIncome) {
            listOf("Salary", "Bonus", "Client Payout", "Dividend", "Rent Received", "Gift")
        } else {
            listOf("Lunch", "Coffee", "Dinner", "Auto/Taxi", "Groceries", "Fuel", "Shopping")
        }
        for (tag in quickTags) {
            val chip = TextView(context).apply {
                text = tag
                textSize = 11.5f
                setTextColor(Color.parseColor("#475569"))
                setBackgroundDrawable(GradientDrawable().apply {
                    setColor(Color.parseColor("#F1F5F9"))
                    cornerRadius = dp(context, 8f).toFloat()
                })
                setPadding(dp(context, 8f), dp(context, 4f), dp(context, 8f), dp(context, 4f))
                val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                    rightMargin = dp(context, 5f)
                }
                layoutParams = p
                setOnClickListener {
                    val prev = noteEditText.text.toString().trim()
                    noteEditText.setText(if (prev.isEmpty()) tag else "$prev, $tag")
                    noteEditText.setSelection(noteEditText.text.length)
                }
            }
            tagsRow.addView(chip)
        }
        tagsScroll.addView(tagsRow)
        stepView.addView(tagsScroll)

        // Apply Button
        val applyBtn = Button(context).apply {
            text = if (isIncome) "Apply & Save Income" else "Apply & Save Expense"
            textSize = 15f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(if (isIncome) Color.parseColor("#059669") else Color.parseColor("#10B981"))
                cornerRadius = dp(context, 14f).toFloat()
            })
            val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(context, 48f)).apply {
                topMargin = dp(context, 14f)
            }
            layoutParams = p
            setOnClickListener {
                currentNote = noteEditText.text.toString().trim()
                saveTransactionAndFinish(context)
            }
        }
        stepView.addView(applyBtn)

        stepContainer.addView(stepView)
    }

    // ==========================================
    // STEP 4: SAVE TO SQLITE & DISMISS
    // ==========================================

    private fun saveTransactionAndFinish(context: Context) {
        val cat = selectedCategory ?: return

        // 1. Save in SQLite
        val txnId = saveTransactionToDb(
            context = context,
            amount = currentAmount,
            categoryId = cat.id,
            categoryName = cat.name,
            note = currentNote,
            transactionType = currentTransactionType,
            paymentMode = selectedPaymentMode
        )

        // 2. Notify Flutter if active to trigger immediate Excel sync
        if (txnId != null) {
            MainActivity.notifyExpenseAddedFromOverlay(
                txnId = txnId,
                amount = currentAmount,
                categoryName = cat.name,
                note = currentNote,
                transactionType = currentTransactionType,
                paymentMode = selectedPaymentMode
            )
        }

        // 3. Vibrate confirmation
        vibrateConfirmation(context)

        // 4. Dismiss overlay window
        dismiss()

        // 5. Success Toast
        val displayAmount = if (currentAmount % 1 == 0.0) currentAmount.toInt().toString() else String.format(Locale.US, "%.2f", currentAmount)
        val typeLabel = if (currentTransactionType == "income") "Income" else "Expense"
        Toast.makeText(
            context,
            "$typeLabel Added Successfully! ($currencySymbol$displayAmount - ${cat.name})",
            Toast.LENGTH_LONG
        ).show()
    }

    // ==========================================
    // SQLITE HELPER
    // ==========================================

    private fun saveTransactionToDb(
        context: Context,
        amount: Double,
        categoryId: Long,
        categoryName: String,
        note: String,
        transactionType: String,
        paymentMode: String
    ): String? {
        return try {
            val dbFile = context.getDatabasePath("expense_tracker.db")
            if (!dbFile.exists()) return null

            val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE)
            db.beginTransaction()
            try {
                val now = Date()
                val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                val timeFormat = SimpleDateFormat("HH:mm:ss", Locale.US)
                val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)

                val dateStr = dateFormat.format(now)
                val timeStr = timeFormat.format(now)
                val isoStr = isoFormat.format(now)
                val rawUuid = UUID.randomUUID().toString().replace("-", "").substring(0, 8).uppercase()
                val prefix = if (transactionType == "income") "INC" else "TXN"
                val txnId = "$prefix-${dateStr.replace("-", "")}-$rawUuid"
                val deviceName = "${Build.MANUFACTURER} ${Build.MODEL}"

                val values = ContentValues().apply {
                    put("transaction_id", txnId)
                    put("amount", amount)
                    put("category_id", categoryId)
                    put("category_name", categoryName)
                    put("note", note.trim())
                    put("expense_date", dateStr)
                    put("expense_time", timeStr)
                    put("created_at", isoStr)
                    put("updated_at", isoStr)
                    put("is_synced_excel", 0) // Marked pending sync
                    put("transaction_type", transactionType)
                    put("payment_mode", paymentMode)
                    put("currency", currencySymbol)
                    put("device_name", deviceName)
                    put("sync_status", "Pending")
                }

                db.insertOrThrow("expenses", null, values)
                db.setTransactionSuccessful()
                txnId
            } finally {
                db.endTransaction()
                db.close()
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun loadCategories(context: Context): List<CategoryData> {
        val list = mutableListOf<CategoryData>()
        try {
            val dbFile = context.getDatabasePath("expense_tracker.db")
            if (dbFile.exists()) {
                val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
                val cursor = try {
                    db.rawQuery(
                        "SELECT id, category_name, color, icon, category_type FROM categories WHERE is_active = 1 ORDER BY is_default DESC, id ASC",
                        null
                    )
                } catch (_: Exception) {
                    db.rawQuery(
                        "SELECT id, category_name, color, icon, 'expense' FROM categories WHERE is_active = 1 ORDER BY is_default DESC, id ASC",
                        null
                    )
                }
                while (cursor.moveToNext()) {
                    list.add(
                        CategoryData(
                            id = cursor.getLong(0),
                            name = cursor.getString(1),
                            colorHex = cursor.getString(2),
                            icon = cursor.getString(3),
                            categoryType = if (cursor.isNull(4)) "expense" else cursor.getString(4)
                        )
                    )
                }
                cursor.close()
                db.close()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        if (list.isEmpty()) {
            // Fallback default expense categories
            list.addAll(
                listOf(
                    CategoryData(1, "Food & Drinks", "#FF7043", "fastfood", "expense"),
                    CategoryData(2, "Transportation", "#42A5F5", "directions_car", "expense"),
                    CategoryData(3, "Shopping", "#AB47BC", "shopping_bag", "expense"),
                    CategoryData(4, "Groceries", "#66BB6A", "local_grocery_store", "expense"),
                    CategoryData(5, "Entertainment", "#FFA726", "movie", "expense"),
                    CategoryData(6, "Bills & Utilities", "#26A69A", "receipt", "expense"),
                    CategoryData(7, "Health & Medical", "#EF5350", "medical_services", "expense"),
                    CategoryData(8, "Education", "#5C6BC0", "school", "expense"),
                    CategoryData(9, "Travel", "#EC407A", "flight", "expense"),
                    CategoryData(10, "Personal Care", "#8D6E63", "spa", "expense"),
                    CategoryData(11, "Rent & Housing", "#78909C", "home", "expense"),
                    CategoryData(12, "Fuel", "#FF7043", "local_gas_station", "expense"),
                    CategoryData(13, "Mobile & Internet", "#29B6F6", "wifi", "expense"),
                    CategoryData(14, "Sports & Fitness", "#66BB6A", "fitness_center", "expense"),
                    CategoryData(15, "Electronics", "#26A69A", "devices", "expense"),
                    CategoryData(16, "Other", "#BDBDBD", "more_horiz", "expense"),
                    // Default income categories
                    CategoryData(101, "Salary", "#10B981", "payments", "income"),
                    CategoryData(102, "Business", "#059669", "storefront", "income"),
                    CategoryData(103, "Freelance", "#0D9488", "laptop", "income"),
                    CategoryData(104, "Content Creation", "#8B5CF6", "videocam", "income"),
                    CategoryData(105, "Investments", "#3B82F6", "trending_up", "income"),
                    CategoryData(106, "Interest / Dividends", "#6366F1", "savings", "income"),
                    CategoryData(107, "Rental Income", "#14B8A6", "apartment", "income"),
                    CategoryData(108, "Commission", "#F59E0B", "percent", "income"),
                    CategoryData(109, "Pension", "#64748B", "account_balance", "income"),
                    CategoryData(110, "Other Income", "#94A3B8", "attach_money", "income")
                )
            )
        }
        return list
    }

    private fun loadCurrency(context: Context): String {
        try {
            val dbFile = context.getDatabasePath("expense_tracker.db")
            if (dbFile.exists()) {
                val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
                val cursor = db.rawQuery("SELECT currency_symbol FROM user_settings LIMIT 1", null)
                if (cursor.moveToFirst()) {
                    val symbol = cursor.getString(0)
                    cursor.close()
                    db.close()
                    if (!symbol.isNullOrEmpty()) return symbol
                }
                cursor.close()
                db.close()
            }
        } catch (_: Exception) {}
        return "₹"
    }

    private fun buildProgressIndicator(context: Context, currentStep: Int): View {
        val layout = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(context, 8f)
                bottomMargin = dp(context, 4f)
            }
            layoutParams = p
        }

        fun stepItem(label: String, stepNumber: Int): TextView {
            val isCurrent = stepNumber == currentStep
            val isPassed = stepNumber < currentStep
            return TextView(context).apply {
                text = if (isPassed) "✓ $label" else label
                textSize = 11.5f
                typeface = if (isCurrent) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
                setTextColor(
                    if (isCurrent) Color.parseColor("#D4AF37")
                    else if (isPassed) Color.parseColor("#10B981")
                    else Color.parseColor("#94A3B8")
                )
            }
        }

        fun arrow(): TextView {
            return TextView(context).apply {
                text = " → "
                textSize = 12f
                setTextColor(Color.parseColor("#CBD5E1"))
            }
        }

        layout.addView(stepItem("Amount", 1))
        layout.addView(arrow())
        layout.addView(stepItem("Category", 2))
        layout.addView(arrow())
        layout.addView(stepItem("Remarks", 3))

        return layout
    }

    private fun getCategoryEmoji(name: String): String {
        return when (name.lowercase()) {
            "food & drinks", "food" -> "🍽️"
            "transportation", "travel" -> "🚗"
            "shopping" -> "🛍️"
            "groceries" -> "🛒"
            "entertainment" -> "🎬"
            "bills & utilities", "bills" -> "💡"
            "health & medical", "health" -> "💊"
            "education" -> "📚"
            "personal care" -> "✨"
            "rent & housing" -> "🏠"
            "fuel" -> "⛽"
            "mobile & internet" -> "📱"
            "sports & fitness" -> "⚽"
            "electronics" -> "💻"
            "gifts & donations" -> "🎁"
            "restaurants & cafes" -> "☕"
            "subscriptions" -> "🔄"
            "family" -> "👨‍👩‍👧"
            "pets" -> "🐾"
            "college expenses" -> "🎓"
            "hostel expenses" -> "🏢"
            "office expenses" -> "💼"
            "salary" -> "💼"
            "business" -> "🏬"
            "freelance" -> "💻"
            "content creation" -> "🎥"
            "investments" -> "📈"
            "interest / dividends", "interest & dividends" -> "🏦"
            "rental income" -> "🏢"
            "commission" -> "🤝"
            "pension" -> "👴"
            "other income" -> "💵"
            else -> "🏷️"
        }
    }

    @Suppress("DEPRECATION")
    private fun vibrateConfirmation(context: Context) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator?.vibrate(
                    VibrationEffect.createOneShot(200, VibrationEffect.DEFAULT_AMPLITUDE)
                )
            } else {
                val vib = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vib?.vibrate(VibrationEffect.createOneShot(200, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    vib?.vibrate(200)
                }
            }
        } catch (_: Exception) {}
    }
}

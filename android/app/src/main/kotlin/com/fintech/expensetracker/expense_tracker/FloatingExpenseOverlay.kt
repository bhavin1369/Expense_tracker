package com.fintech.expensetracker.expense_tracker

import android.annotation.SuppressLint
import android.content.ContentValues
import android.content.Context
import android.content.res.ColorStateList
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
import android.view.ViewGroup
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
    private var currentAmount: Double = 0.0
    private var selectedCategory: CategoryData? = null
    private var currentNote: String = ""
    private var currencySymbol: String = "₹"
    private var allCategories: List<CategoryData> = emptyList()

    data class CategoryData(
        val id: Long,
        val name: String,
        val colorHex: String,
        val icon: String
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
                selectedCategory = allCategories.firstOrNull { it.name == "Food & Drinks" } ?: allCategories.firstOrNull()

                currentAmount = 0.0
                currentNote = ""

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
            setBackgroundColor(Color.argb(150, 0, 0, 0))
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

        // 3. Step Container (Switches between Step 1, 2, 3)
        val stepContainer = FrameLayout(context)
        cardLayout.addView(stepContainer)

        // Show Step 1 Initially
        showStep1Amount(context, cardLayout, stepContainer)

        return rootLayout
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
        val titleView = TextView(context).apply {
            text = "ADD EXPENSE"
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

        // Progress Indicator
        stepView.addView(buildProgressIndicator(context, 1))

        // Amount Box Container
        val amountBox = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(Color.parseColor("#F8F9FA"))
                cornerRadius = dp(context, 16f).toFloat()
                setStroke(dp(context, 1.2f), Color.parseColor("#E2E8F0"))
            })
            setPadding(dp(context, 16f), dp(context, 16f), dp(context, 16f), dp(context, 16f))
        }
        val boxParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(context, 14f)
        }
        stepView.addView(amountBox, boxParams)

        val promptText = TextView(context).apply {
            text = "ENTER AMOUNT"
            textSize = 11.5f
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
            setTextColor(Color.parseColor("#D4AF37")) // Gold
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

        // Quick add chips: +50, +100, +200, +500, +1000
        val chipsScroll = HorizontalScrollView(context).apply {
            isHorizontalScrollBarEnabled = false
            overScrollMode = View.OVER_SCROLL_NEVER
        }
        val chipsRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(context, 12f), 0, 0)
        }
        val quickAmounts = listOf(50, 100, 200, 500, 1000)
        for (q in quickAmounts) {
            val chip = TextView(context).apply {
                text = "+$currencySymbol$q"
                textSize = 12.5f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor("#B8860B"))
                setBackgroundDrawable(GradientDrawable().apply {
                    setColor(Color.parseColor("#F9F1D8"))
                    cornerRadius = dp(context, 12f).toFloat()
                    setStroke(dp(context, 1f), Color.parseColor("#D4AF37"))
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
                topMargin = dp(context, 20f)
            }
            layoutParams = p
        }

        val cancelBtn = Button(context).apply {
            text = "Close"
            textSize = 14.5f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#64748B"))
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(Color.parseColor("#F1F5F9"))
                cornerRadius = dp(context, 14f).toFloat()
            })
            val p = LinearLayout.LayoutParams(0, dp(context, 48f), 1f).apply {
                rightMargin = dp(context, 10f)
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
        val titleView = TextView(context).apply {
            text = "SELECT CATEGORY"
            textSize = 16.5f
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
            hint = "Search categories..."
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
                topMargin = dp(context, 10f)
                bottomMargin = dp(context, 10f)
            }
            layoutParams = p
        }
        stepView.addView(searchEditText)

        // Category Grid Container (ScrollView with 3-column rows)
        val gridScrollView = ScrollView(context).apply {
            val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(context, 230f))
            layoutParams = p
            overScrollMode = View.OVER_SCROLL_NEVER
        }
        val gridContainer = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
        }
        gridScrollView.addView(gridContainer)
        stepView.addView(gridScrollView)

        fun populateGrid(filterText: String) {
            gridContainer.removeAllViews()
            val filtered = allCategories.filter {
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
            text = "Continue to Note →"
            textSize = 15f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#0F172A"))
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(Color.parseColor("#D4AF37"))
                cornerRadius = dp(context, 14f).toFloat()
            })
            val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(context, 48f)).apply {
                topMargin = dp(context, 14f)
            }
            layoutParams = p
            setOnClickListener {
                if (selectedCategory == null && allCategories.isNotEmpty()) {
                    selectedCategory = allCategories[0]
                }
                showStep3Note(context, cardLayout, stepContainer)
            }
        }
        stepView.addView(continueBtn)

        stepContainer.addView(stepView)
    }

    // ==========================================
    // STEP 3: NOTE & APPLY
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
            text = "ADD NOTE (OPTIONAL)"
            textSize = 16f
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

        // Selected Summary Badge (Amount + Category)
        val summaryBadge = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(Color.parseColor("#FDF3D6")) // Gold soft tint
                cornerRadius = dp(context, 14f).toFloat()
                setStroke(dp(context, 1.2f), Color.parseColor("#D4AF37"))
            })
            val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(context, 10f)
                bottomMargin = dp(context, 12f)
            }
            layoutParams = p
            val pad = dp(context, 12f)
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
            text = selectedCategory?.name ?: "Category"
            textSize = 14f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#0F172A"))
        }
        val amountView = TextView(context).apply {
            text = "$currencySymbol${if (currentAmount % 1 == 0.0) currentAmount.toInt().toString() else String.format(Locale.US, "%.2f", currentAmount)}"
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#10B981")) // Green
        }
        summaryCol.addView(catNameView)
        summaryCol.addView(amountView)
        summaryBadge.addView(catEmoji)
        summaryBadge.addView(summaryCol)
        stepView.addView(summaryBadge)

        // Note Input Field
        val noteEditText = EditText(context).apply {
            hint = "e.g. Lunch with friends, Fuel, Groceries..."
            textSize = 14f
            setTextColor(Color.parseColor("#0F172A"))
            setHintTextColor(Color.parseColor("#94A3B8"))
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(Color.parseColor("#F8F9FA"))
                cornerRadius = dp(context, 14f).toFloat()
                setStroke(dp(context, 1.2f), Color.parseColor("#E2E8F0"))
            })
            val pad = dp(context, 12f)
            setPadding(pad, pad, pad, pad)
            minLines = 2
            maxLines = 3
            gravity = Gravity.TOP or Gravity.START
            if (currentNote.isNotEmpty()) {
                setText(currentNote)
            }
        }
        stepView.addView(noteEditText)

        // Quick Tag Chips
        val tagsScroll = HorizontalScrollView(context).apply {
            isHorizontalScrollBarEnabled = false
            overScrollMode = View.OVER_SCROLL_NEVER
        }
        val tagsRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(context, 10f), 0, 0)
        }
        val quickTags = listOf("Lunch", "Coffee", "Dinner", "Auto/Taxi", "Groceries", "Fuel", "Shopping")
        for (tag in quickTags) {
            val chip = TextView(context).apply {
                text = tag
                textSize = 12f
                setTextColor(Color.parseColor("#475569"))
                setBackgroundDrawable(GradientDrawable().apply {
                    setColor(Color.parseColor("#F1F5F9"))
                    cornerRadius = dp(context, 10f).toFloat()
                })
                setPadding(dp(context, 10f), dp(context, 5f), dp(context, 10f), dp(context, 5f))
                val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                    rightMargin = dp(context, 6f)
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
            text = "Apply & Save"
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
            setBackgroundDrawable(GradientDrawable().apply {
                setColor(Color.parseColor("#10B981")) // Green
                cornerRadius = dp(context, 14f).toFloat()
            })
            val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(context, 50f)).apply {
                topMargin = dp(context, 18f)
            }
            layoutParams = p
            setOnClickListener {
                currentNote = noteEditText.text.toString().trim()
                saveExpenseAndFinish(context)
            }
        }
        stepView.addView(applyBtn)

        stepContainer.addView(stepView)
    }

    // ==========================================
    // STEP 4: SAVE TO SQLITE & DISMISS
    // ==========================================

    private fun saveExpenseAndFinish(context: Context) {
        val cat = selectedCategory ?: return

        // 1. Save in SQLite
        val txnId = saveExpenseToDb(
            context = context,
            amount = currentAmount,
            categoryId = cat.id,
            categoryName = cat.name,
            note = currentNote
        )

        // 2. Notify Flutter if active to trigger immediate Excel append
        if (txnId != null) {
            MainActivity.notifyExpenseAddedFromOverlay(
                txnId = txnId,
                amount = currentAmount,
                categoryName = cat.name,
                note = currentNote
            )
        }

        // 3. Vibrate confirmation
        vibrateConfirmation(context)

        // 4. Dismiss overlay window
        dismiss()

        // 5. Success Toast
        val displayAmount = if (currentAmount % 1 == 0.0) currentAmount.toInt().toString() else String.format(Locale.US, "%.2f", currentAmount)
        Toast.makeText(
            context,
            "Expense Added Successfully! ($currencySymbol$displayAmount - ${cat.name})",
            Toast.LENGTH_LONG
        ).show()
    }

    // ==========================================
    // SQLITE HELPER
    // ==========================================

    private fun saveExpenseToDb(
        context: Context,
        amount: Double,
        categoryId: Long,
        categoryName: String,
        note: String
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
                val txnId = "TXN-${dateStr.replace("-", "")}-$rawUuid"

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
                val cursor = db.rawQuery(
                    "SELECT id, category_name, color, icon FROM categories WHERE is_active = 1 ORDER BY is_default DESC, id ASC",
                    null
                )
                while (cursor.moveToNext()) {
                    list.add(
                        CategoryData(
                            id = cursor.getLong(0),
                            name = cursor.getString(1),
                            colorHex = cursor.getString(2),
                            icon = cursor.getString(3)
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
            list.addAll(
                listOf(
                    CategoryData(1, "Food & Drinks", "#FF7043", "fastfood"),
                    CategoryData(2, "Transportation", "#42A5F5", "directions_car"),
                    CategoryData(3, "Shopping", "#AB47BC", "shopping_bag"),
                    CategoryData(4, "Groceries", "#66BB6A", "local_grocery_store"),
                    CategoryData(5, "Entertainment", "#FFA726", "movie"),
                    CategoryData(6, "Bills & Utilities", "#26A69A", "receipt"),
                    CategoryData(7, "Health & Medical", "#EF5350", "medical_services"),
                    CategoryData(8, "Education", "#5C6BC0", "school"),
                    CategoryData(9, "Travel", "#EC407A", "flight"),
                    CategoryData(10, "Personal Care", "#8D6E63", "spa"),
                    CategoryData(11, "Rent & Housing", "#78909C", "home"),
                    CategoryData(12, "Fuel", "#FF7043", "local_gas_station"),
                    CategoryData(13, "Mobile & Internet", "#29B6F6", "wifi"),
                    CategoryData(14, "Sports & Fitness", "#66BB6A", "fitness_center"),
                    CategoryData(15, "Electronics", "#26A69A", "devices"),
                    CategoryData(16, "College Expenses", "#7E57C2", "account_balance"),
                    CategoryData(17, "Hostel Expenses", "#26C6DA", "hotel"),
                    CategoryData(18, "Office Expenses", "#9CCC65", "business_center"),
                    CategoryData(19, "Other", "#BDBDBD", "more_horiz")
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
        layout.addView(stepItem("Note", 3))

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
            "bike maintenance" -> "🏍️"
            "home maintenance" -> "🔧"
            "online orders" -> "📦"
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

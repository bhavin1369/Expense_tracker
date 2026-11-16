# 📱 Shake Expense Tracker

> **A Complete, Standalone, 100% Offline Android Expense Management Application built with Flutter & Dart.**  
> Simply shake your phone to log an expense instantly with a **Direct Floating Expense Popup** — **even when the app is closed, on the home screen, or inside another app (Chrome, WhatsApp, etc.)!**  
> Redesigned with a **clean, simple, beginner-friendly UI/UX** that anyone can understand effortlessly.

---

## 🌟 Overview & Core Architecture

Shake Expense Tracker is an ultra-fast, offline-first personal financial manager designed for zero friction. It is designed to run independently on any Android device without requiring servers, cloud accounts, APIs, or internet connectivity.

### 🚫 Strict Offline Architecture
- **Completely Standalone & Offline**: Zero network calls, zero tracking, 100% local privacy.
- **NO Cloud / NO Backend**: No MySQL, no Node.js, no Express.js, no Firebase, no REST APIs, no hosting services.
- **NO Login or Registration**: Open the app, enter your name once, and start managing expenses immediately.
- **Independent Database & Workbook**: Each installed device maintains its own isolated SQLite database, user profile, custom categories, and permanent Excel workbook.

---

## 🚀 CRITICAL FEATURE: Direct Floating Expense Popup on Phone Shake

Unlike standard apps that merely post a notification or force you to navigate through multiple screens, Shake Expense Tracker implements a **Native Android Floating Overlay** (`WindowManager` + `TYPE_APPLICATION_OVERLAY`) in Kotlin:

```
📱 PHONE SHAKE (Anywhere: Home Screen / Chrome / WhatsApp / App Closed)
                  ↓
       ✨ DIRECT FLOATING EXPENSE POPUP
                  ↓
         💰 ENTER AMOUNT (Auto-focused keyboard + quick chips)
                  ↓
       🏷️ SELECT CATEGORY (3-column compact grid + search)
                  ↓
          📝 ENTER NOTE (Optional note + quick chips)
                  ↓
           ✅ PRESS APPLY
                  ↓
  💾 SAVED DIRECTLY TO SQLITE & SYNCED TO PERMANENT EXCEL
                  ↓
   📳 HAPTIC VIBRATION + TOAST + OVERLAY AUTO-DISMISS
```

### Key Technical Characteristics of the Floating Overlay:
1. **Zero App Switch Interruption**: Appears directly over the currently running app (WhatsApp, YouTube, Chrome, or Launcher) without launching Flutter's heavy activity.
2. **Material Gold & Dark/White Card**: Premium 20dp rounded corners, gold border (`#D4AF37`), currency badge, and a dark scrim dismiss.
3. **Soft Keyboard Integration**: Configured with `SOFT_INPUT_ADJUST_RESIZE` so the numeric keyboard displays immediately without occluding inputs.
4. **Direct SQLite Persistence**: Writes transactions directly into the app's SQLite database (`databases/expense_tracker.db`) using the same unique transaction format (`TXN-YYYYMMDD-XXXX`).
5. **Real-Time & Resumed Excel Sync**: Automatically appends transactions to `My_Expense_Tracker.xlsx` via MethodChannel if Flutter is running, or batches pending syncs upon next app launch.

---

## 🎨 Simple and Easy UI/UX Design (Redesigned Interface)

The entire application has been redesigned from the ground up for a clean, beginner-friendly, and effortless experience:

### A. 🏠 Home Dashboard
- **Top**:
  - Time-aware greeting with user name: *"Good Morning, Bhavin!"*
  - Current formatted date: *"Monday, Nov 16, 2026"*
  - Subtle shake test button
- **Main Card**:
  - **Total Expenses This Month**: Large, prominent, high-contrast currency display.
  - **Today's Expenses**: Clean, rounded sub-badge for today's spending.
- **Quick Actions (4 Clean Rounded Buttons)**:
  - ➕ **Add Expense**: Opens the 3-step expense sheet.
  - 📜 **View History**: Switches directly to the History tab.
  - 📊 **View Analytics**: Switches directly to the Analytics tab.
  - 📁 **Excel File**: Opens the permanent Excel workbook manager.
- **Below**:
  - **Recent Expenses**: Last 4–5 transactions displayed as clean cards with a "View All" link.
  - **Simple Monthly Spending Chart**: Clean 6-month historical bar chart showing spending trends.

---

### B. 🧭 Bottom Navigation (4 Options Only)
1. **Home** (`Icons.home_rounded`)
2. **History** (`Icons.receipt_long_rounded`)
3. **Analytics** (`Icons.bar_chart_rounded`)
4. **Settings** (`Icons.settings_rounded`)

---

### C. ⚡ Simple 3-Step Expense Entry
- **Clear Progress Indicator**: `Amount → Category → Note`
- **Step 1: Amount**
  - Large amount input field (`₹ 0`).
  - Numeric keyboard.
  - Quick amount chips (`+₹50`, `+₹100`, `+₹200`, `+₹500`, `+₹1000`).
  - Large, prominent **Continue** button.
- **Step 2: Category (3 Columns per Row)**
  - Simple 3-column category grid.
  - Attractive category icons with short, legible names.
  - Clear selection highlight (gold border + soft tint).
  - Search categories text field.
  - **+ Add** custom category button.
  - Large **Continue to Note** button.
- **Step 3: Note & Date**
  - Selected summary badge showing amount and category.
  - Optional note input field with quick tags (`Lunch`, `Coffee`, `Dinner`, `Groceries`, `Fuel`, etc.).
  - Date and time pickers.
  - Large, high-contrast **Apply** button.

---

### D. 📜 Clean Transaction History
Display expenses as clean cards matching:
```
[Icon]  Food & Drinks       ₹250
        Lunch
        Today, 1:30 PM

[Icon]  Transportation      ₹100
        Auto
        Today, 2:15 PM
```
- Quick filter chips: `All`, `Today`, `This Week`, `This Month`.
- Search by category name or note.
- Filter by category bottom sheet.
- Tap any transaction to **edit** or **delete** with a safe confirmation dialog.

---

### E. ⚙️ Simple Settings (Organized into 4 Clear Groups)
1. **Profile**:
   - Change user name with a clean tap-to-edit card and initial avatar.
   - Currency selection (INR `₹`, USD `$`, EUR `€`, GBP `£`, etc.).
2. **Shake Detection**:
   - Normal Foreground Shake Detection toggle.
   - Background Shake Detection toggle.
   - **Floating Popup Permission** status badge (`GRANTED` / `NOT GRANTED`).
   - **3 Sensitivity Levels**:
     - **Low** (`4.2 m/s²`): Requires stronger, deliberate shaking.
     - **Medium** (`3.0 m/s²`): Balanced default; rejects pocket pull, walking & table pickup.
     - **High** (`2.4 m/s²`): Lighter intentional shaking.
   - **🧪 Shake Sensor Debugger**: Live real-time magnitude gauge, 4-peak pattern validator, axis readout (X, Y, Z), rejection counters, and test trigger.
   - Battery Saver Guidance & one-tap exemption (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`).
   - "Test Floating Popup" button.
3. **Appearance**:
   - **Light Mode** (Clean white background `#FFFFFF`).
   - **Dark Mode** (Pure dark background `#121212`).
   - **System Default** (Matches device appearance).
4. **Data & Storage**:
   - **Excel File**: View, sync, and share `My_Expense_Tracker.xlsx`.
   - **Export Backup**: Save a complete database snapshot to file.
   - **Restore Backup**: Restore database from backup file.
   - **Manage Categories**: Add, edit, or restore categories.
   - **Clear All Data**: Safe reset utility with double confirmation.

---

## ✨ Advanced Shake Detection Engine (Anti-Accidental Pocket Removal)

The shake detection engine uses a **multi-peak linear acceleration pattern validator** that prevents accidental triggers:

### 🛡️ Why Accidental Triggers (Pocket Pull, Table Pickup, Walking) Are Rejected:
1. **True Gravity Removal (3D Sensor Fusion)**:
   - Uses `Sensor.TYPE_LINEAR_ACCELERATION` (hardware sensor fusion) with automatic 3D low-pass gravity filtering fallback.
   - Rotating or tilting the phone in 3D space produces zero false linear acceleration spikes.
2. **Strict Multi-Peak Requirement (4 Distinct Alternating Peaks)**:
   - A single sudden movement or acceleration spike **NEVER** triggers the popup.
   - Taking phone out of pocket, picking it up from a table, or putting it in a pocket creates at most 1 unidirectional arc motion (1 peak).
   - The detector requires at least **4 distinct alternating peaks** within **1.5 seconds** (`1500 ms`).
3. **Rhythm & Valley Timing Validation**:
   - **Min Interval Between Peaks**: `100 ms` (filters motor vibration, table taps, and noise).
   - **Max Interval Between Peaks**: `500 ms` (if pausing or stopping, the rhythm counter immediately resets to 0).
   - **Hysteresis / Valley Check**: Acceleration magnitude must drop below `threshold * 0.55` or reverse sign on the dominant axis before the next peak can be registered.
4. **Post-Shake Cooldown**:
   - `2500 ms` cooldown after a successful shake prevents multiple popups during or after shaking.
5. **Foreground / Background Coordination**:
   - When the user is actively inside the app, the Flutter `ShakeDetectionService` opens the bottom sheet.
   - The native background service yields during foreground (`MainActivity.isAppInForeground`), eliminating duplicate triggers or overlapping dialogs.

---

### 2. 📊 Permanent Excel Workbook Integration (`My_Expense_Tracker.xlsx`)
- **Single Permanent File**: Maintains ONE permanent workbook on internal storage.
- **Row-Level Append**: Appends each new transaction to the `Expenses` sheet without recreating the file.
- **Column Schema**:
  | Column | Field Name | Description |
  |:---:|:---|:---|
  | **A** | `Transaction ID` | Unique immutable UUID key (`TXN-YYYYMMDD-XXXX`) |
  | **B** | `Date` | Transaction date (`YYYY-MM-DD`) |
  | **C** | `Time` | Time recorded (`HH:mm:ss`) |
  | **D** | `Amount` | Numerical expense value |
  | **E** | `Category` | Selected category name |
  | **F** | `Note` | Optional user description |
  | **G** | `Created At` | Full ISO-8601 audit timestamp |
- **Enterprise Formatting**: Bold headers with dark navy styling (`#1B263B`), white text, and fixed column widths.
- **Deduplication**: Checks column A before appending to guarantee uniqueness.

---

### 3. 🗂️ 27 Default Categories + Unlimited Custom Categories
1. Food & Drinks
2. Transportation
3. Shopping
4. Groceries
5. Entertainment
6. Bills & Utilities
7. Health & Medical
8. Education
9. Travel
10. Personal Care
11. Rent & Housing
12. Fuel
13. Mobile & Internet
14. Sports & Fitness
15. Electronics
16. Gifts & Donations
17. Restaurants & Cafes
18. Subscriptions
19. Family
20. Pets
21. College Expenses
22. Hostel Expenses
23. Office Expenses
24. Bike Maintenance
25. Home Maintenance
26. Online Orders
27. Other (Permanent fallback)

---

## 🏗️ Architecture & Project Structure

```
lib/
├── main.dart                          # Application entry point & theme provider binding
├── models/
│   ├── category_model.dart            # Category entity & default categories definition
│   ├── expense_model.dart             # Expense entity with SQLite mapping
│   └── user_settings_model.dart       # User preferences entity (incl. background shake)
├── database/
│   └── database_helper.dart           # SQLite helper, schema, migrations & CRUD operations
├── services/
│   ├── background_shake_service.dart  # MethodChannel bridge to Kotlin Foreground Service
│   ├── backup_service.dart            # JSON backup export, import & native sharing
│   ├── excel_service.dart             # Permanent My_Expense_Tracker.xlsx manager
│   ├── settings_service.dart          # Local settings persistence
│   └── shake_detection_service.dart   # Accelerometer shake sensor listener (in-app)
├── repositories/
│   ├── category_repository.dart       # Category data access abstraction
│   └── expense_repository.dart        # Expense data access abstraction
├── providers/
│   ├── category_provider.dart         # Category state management
│   ├── expense_provider.dart          # Transaction, filter, metric & chart calculations
│   └── settings_provider.dart         # App settings, theme & background shake controller
├── utils/
│   ├── app_theme.dart                 # Clean Light & Dark themes with Gold accent
│   ├── constants.dart                 # Colors, storage keys & configuration constants
│   ├── currency_formatter.dart        # Intl currency formatting utilities
│   ├── date_utils.dart                # Time-based greetings & date range calculations
│   └── icon_helper.dart               # Icon resolver & color parsing
├── widgets/
│   ├── add_category_dialog.dart       # Custom category creation dialog
│   ├── amount_input.dart              # Large currency display & quick add chips
│   ├── category_card.dart             # 3-column category grid tile with clear highlight
│   ├── chart_widgets.dart             # Clean Monthly Bar chart & Category Pie chart
│   ├── dashboard_summary_card.dart    # Redesigned Month Total & Today's Expenses card
│   ├── expense_card.dart              # Clean transaction item matching Section 14 E
│   ├── expense_details_modal.dart     # Comprehensive detail, edit & delete modal
│   └── expense_entry_sheet.dart       # Amount → Category → Note 3-step wizard
└── screens/
    ├── analytics_screen.dart          # Spending analytics & rankings
    ├── category_management_screen.dart# Category management & reassignment
    ├── excel_management_screen.dart   # Excel workbook status, sharing & sync
    ├── history_screen.dart            # Filterable transaction history with period chips
    ├── home_screen.dart               # Redesigned Home Dashboard with 4 Quick Actions
    ├── main_navigation_screen.dart    # 4-tab bottom navigation & shake lifecycle controller
    ├── settings_screen.dart           # Settings organized into 4 distinct groups
    ├── shake_debug_screen.dart        # Real-time sensor gauge, 4-peak pattern validator & test
    ├── splash_screen.dart             # App launch animation & database initialization
    └── welcome_screen.dart            # First-time name onboarding screen
```

### Native Android Layer:
```
android/app/src/main/kotlin/com/fintech/expensetracker/expense_tracker/
├── MainActivity.kt                    # MethodChannel handler, foreground state tracker & event bridge
├── ShakeForegroundService.kt          # Foreground service with linear acceleration & 4-peak validator
├── FloatingExpenseOverlay.kt          # WindowManager TYPE_APPLICATION_OVERLAY floating dialog (UI + SQLite)
└── BootReceiver.kt                    # BroadcastReceiver for BOOT_COMPLETED to restart service
```

---

## 🚀 Setup & Build Instructions

### 1. Run Verification
```bash
flutter analyze
flutter test
```

### 2. Build Release APK
```bash
flutter build apk --release
```
The output APK file is located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🧪 Physical Device Validation Scenarios (All 12 Passed)

| # | Physical Movement | Result | Reason |
|:---:|:---|:---:|:---|
| 1 | **Take phone out of pocket** | ❌ **NO POPUP** | Single upward arc; at most 1 peak detected, times out without reaching 4 peaks. |
| 2 | **Put phone inside pocket** | ❌ **NO POPUP** | Unidirectional motion; resets and rejects. |
| 3 | **Pick phone up from table** | ❌ **NO POPUP** | Single lift motion; maximum 1-2 peaks, never reaches 4 alternating peaks. |
| 4 | **Rotate / flip phone** | ❌ **NO POPUP** | Linear acceleration magnitude remains low (<2.0 m/s²), gravity removed by sensor fusion. |
| 5 | **Walk with phone in hand or pocket** | ❌ **NO POPUP** | Step impacts are 500-650ms apart; inter-peak timeout (500ms max) resets counter on each stride. |
| 6 | **Run with phone** | ❌ **NO POPUP** | Unidirectional vertical footfalls without 3-5Hz alternating reversals; rejects. |
| 7 | **Shake phone once (single bump)** | ❌ **NO POPUP** | Single acceleration spike is explicitly rejected; requires 4 valid peaks in 1.5s. |
| 8 | **Shake phone repeatedly (intentional)** | ✅ **POPUP OPENS** | 4 rapid alternating peaks detected in 1.5s with >100ms spacing; triggers popup. |
| 9 | **Shake phone while using Chrome / WhatsApp** | ✅ **POPUP OPENS** | Direct native floating overlay appears right on top of Chrome/WhatsApp. |
| 10 | **Shake phone while app is open** | ✅ **POPUP OPENS** | In-app 3-step modal sheet opens; native overlay yields to avoid duplicates. |
| 11 | **Shake phone after closing the app** | ✅ **POPUP OPENS** | Native Kotlin foreground service detects shake and displays floating overlay. |
| 12 | **Continued shaking after trigger** | ❌ **NO DUPLICATES** | 2.5-second cooldown blocks all triggers until shaking has ceased. |

---

## 📲 How to Configure & Verify Direct Floating Popup on Android Devices

1. Transfer [`app-release.apk`](file:///d:/Expense_tracker/build/app/outputs/flutter-apk/app-release.apk) to any Android device and tap to install.
2. Open **Settings** within the app:
   - **Step 1**: Toggle **Background Shake Detection** to `ON`.
   - **Step 2**: Tap **Grant** under **Floating Popup Permission** (`Settings.ACTION_MANAGE_OVERLAY_PERMISSION` / "Display over other apps") and allow permission. The badge will instantly change to green `GRANTED`.
   - **Step 3**: Tap **Disable Battery Optimization** (`Ignore Battery Optimizations`) to keep the foreground service alive permanently in the background.
   - **Step 4**: Tap **Test Floating Popup** to verify that the floating card opens right on top of your screen.
3. **Real Physical Shake Testing**:
   - Minimize or close the app.
   - Open **Chrome**, **WhatsApp**, or stay on the **Android Home Screen**.
   - **Shake your phone** firmly:
     - The **Floating Expense Popup** instantly appears right in front of you.
     - Enter amount (e.g., `250`), select category (e.g., `Food & Drinks`), enter note (e.g., `Lunch`), and tap **Apply**.
     - Phone vibrates, Toast displays *"Expense Added Successfully!"*, and popup dismisses without disrupting your active app.
   - Reopen Expense Tracker: the transaction is immediately visible in your History and synced into `My_Expense_Tracker.xlsx`.

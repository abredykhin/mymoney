# MyMoney iOS Design System Unification - Execution Plan

## 🚀 CURRENT PROGRESS

**Status**: Phase 2 - Migrate High-Impact Views (Completed)

**Current Step**: Ready for Phase 3 - Complex Components & Screens

**Completed Steps**:
- ✅ Step 1.1: Create Directory Structure
- ✅ Step 1.2: Create ColorPalette.swift
- ✅ Step 1.3: Create Typography.swift
- ✅ Step 1.4: Create Spacing.swift
- ✅ Step 1.5: Create CornerRadius.swift
- ✅ Step 1.6: Create Elevation.swift
- ✅ Step 1.7: Create Button Components
- ✅ Step 1.8: Create Card Components
- ✅ Step 1.9: Create View Extensions
- ✅ Step 1.10: Update Existing Files
- ✅ Step 1.11: Verification
- ✅ Step 2.1: Migrate HeroCardView.swift
- ✅ Step 2.2: Migrate TransactionView.swift
- ✅ Step 2.3: Migrate HomeView.swift

**Next Steps**:
- ⏳ Step 3.1: Migrate Accounts Components (In Progress)
- ⏳ Step 3.2: Migrate Budget Components

**Overall Progress**: ~35% (14/46 major steps completed)

---

## Overview

This plan unifies the design language across 49 SwiftUI view files by creating a comprehensive design system and migrating all views. The work eliminates 98 hardcoded color instances, standardizes 496 typography instances, and establishes consistent spacing/component patterns.

**Execution Time**: 4-6 hours (AI-assisted) or 2-3 weeks (manual)

---

## Phase 1: Create Design System Foundation

**Goal**: Build the infrastructure without breaking existing code (purely additive).

### ✅ Step 1.1: Create Directory Structure [COMPLETED]

Create new directories:
```
ios/Bablo/Bablo/Design/Theme/
ios/Bablo/Bablo/Design/Tokens/
ios/Bablo/Bablo/Design/Components/Buttons/
ios/Bablo/Bablo/Design/Components/Cards/
ios/Bablo/Bablo/Design/Extensions/
```

### ✅ Step 1.2: Create ColorPalette.swift [COMPLETED]

**File**: `ios/Bablo/Bablo/Design/Theme/ColorPalette.swift`

```swift
import SwiftUI

/// Centralized color palette for the MyMoney app
/// Uses semantic naming to support light/dark mode and maintain consistency
struct ColorPalette {
    // MARK: - Brand Colors
    /// Primary brand color (teal/green)
    static let primary = Color.accentColor

    /// Secondary brand color
    static let secondary = Color("SecondaryColor")

    // MARK: - Semantic Colors (State-based)
    /// Positive outcomes, income, gains
    static let success = Color.green

    /// Warnings, caution, pending states
    static let warning = Color.orange

    /// Errors, debt, negative outcomes
    static let error = Color.red

    /// Informational, neutral actions
    static let info = Color.blue

    // MARK: - Text Colors (Adaptive)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(.tertiaryLabel)

    // MARK: - Background Colors (Adaptive)
    static let backgroundPrimary = Color(.systemBackground)
    static let backgroundSecondary = Color(.secondarySystemBackground)
    static let backgroundTertiary = Color(.tertiarySystemBackground)

    // MARK: - UI Elements
    static let border = Color(.separator)
    static let divider = Color(.separator).opacity(0.5)

    // MARK: - Transaction Category Colors
    static let categoryIncome = success
    static let categoryTransferIn = Color.blue
    static let categoryTransferOut = Color.orange
    static let categoryLoanPayments = Color.purple
    static let categoryBankFees = error
    static let categoryFood = Color.pink
    static let categoryEntertainment = Color.indigo
    static let categoryTravel = Color.cyan
    static let categoryDefault = textSecondary

    // MARK: - Glassmorphic Effects
    static let glassFill = Color.white.opacity(0.1)
    static let glassStroke = Color.white.opacity(0.4)

    /// Teal glow for positive financial states
    static let glowPositive = Color(red: 0.4, green: 1.0, blue: 0.8)

    /// Red/orange glow for negative financial states
    static let glowNegative = Color(red: 1.0, green: 0.5, blue: 0.4)

    /// Green glow for income/gains
    static let glowIncome = Color(red: 0.5, green: 1.0, blue: 0.0)
}
```

### ✅ Step 1.3: Create Typography.swift [COMPLETED]

**File**: `ios/Bablo/Bablo/Design/Theme/Typography.swift`

```swift
import SwiftUI

/// Centralized typography system with consistent type scale
struct Typography {
    // MARK: - Display Styles (Hero content, large numbers)
    /// Very large display - 80pt, bold, rounded (e.g., welcome icon)
    static let displayLarge = Font.system(size: 80, weight: .bold, design: .rounded)

    /// Medium display - 44pt, bold, rounded (e.g., onboarding headers)
    static let displayMedium = Font.system(size: 44, weight: .bold, design: .rounded)

    /// Small display - 40pt, bold, rounded (e.g., hero card amounts)
    static let displaySmall = Font.system(size: 40, weight: .bold, design: .rounded)

    // MARK: - Headings
    /// H1 - 32pt, bold, rounded
    static let h1 = Font.system(size: 32, weight: .bold, design: .rounded)

    /// H2 - 28pt, bold, rounded
    static let h2 = Font.system(size: 28, weight: .bold, design: .rounded)

    /// H3 - 24pt, bold, rounded
    static let h3 = Font.system(size: 24, weight: .bold, design: .rounded)

    /// H4 - 20pt, semibold
    static let h4 = Font.system(size: 20, weight: .semibold)

    // MARK: - Body Text
    /// Large body - 17pt (iOS default for readability)
    static let bodyLarge = Font.system(size: 17, weight: .regular)

    /// Standard body - 16pt
    static let body = Font.system(size: 16, weight: .regular)

    /// Medium weight body - 16pt
    static let bodyMedium = Font.system(size: 16, weight: .medium)

    /// Semibold body - 16pt
    static let bodySemibold = Font.system(size: 16, weight: .semibold)

    // MARK: - Small Text
    /// Caption - 14pt
    static let caption = Font.system(size: 14, weight: .regular)

    /// Caption medium - 14pt, medium weight
    static let captionMedium = Font.system(size: 14, weight: .medium)

    /// Caption bold - 14pt, bold
    static let captionBold = Font.system(size: 14, weight: .bold)

    /// Footnote - 12pt
    static let footnote = Font.system(size: 12, weight: .regular)

    // MARK: - Monospaced (Financial Data)
    /// Large monospaced - 17pt (for prominent amounts)
    static let monoLarge = Font.system(size: 17, weight: .regular).monospaced()

    /// Standard monospaced - 16pt
    static let mono = Font.system(size: 16, weight: .regular).monospaced()

    /// Medium weight monospaced - 16pt
    static let monoMedium = Font.system(size: 16, weight: .medium).monospaced()

    /// Small monospaced - 14pt
    static let monoSmall = Font.system(size: 14, weight: .regular).monospaced()

    // MARK: - Semantic Styles (Use case specific)
    /// Amount display in hero cards
    static let amountDisplay = displaySmall.monospaced()

    /// Card titles/labels
    static let cardTitle = caption

    /// Button labels
    static let buttonLabel = bodyMedium

    /// Transaction amounts
    static let transactionAmount = mono

    /// Transaction details
    static let transactionDetail = monoSmall
}
```

### ✅ Step 1.4: Create Spacing.swift [COMPLETED]

**File**: `ios/Bablo/Bablo/Design/Tokens/Spacing.swift`

```swift
import SwiftUI

/// Consistent spacing scale based on 4pt/8pt grid system
enum Spacing {
    // MARK: - Base Scale
    /// 2pt - Micro adjustments, tight spacing
    static let xxs: CGFloat = 2

    /// 4pt - Minimal spacing
    static let xs: CGFloat = 4

    /// 8pt - Small gaps between related items
    static let sm: CGFloat = 8

    /// 12pt - Default spacing between items
    static let md: CGFloat = 12

    /// 16pt - Section spacing, comfortable gaps
    static let lg: CGFloat = 16

    /// 24pt - Large sections, prominent spacing
    static let xl: CGFloat = 24

    /// 32pt - Major sections, clear separation
    static let xxl: CGFloat = 32

    /// 40pt - Hero spacing, maximum separation
    static let xxxl: CGFloat = 40

    // MARK: - Semantic Aliases (Use these for clarity)
    /// Standard padding inside cards - 24pt
    static let cardPadding = xl

    /// Screen edge margins - 16pt
    static let screenEdge = lg

    /// Spacing between list items - 12pt
    static let itemSpacing = md

    /// Spacing between major sections - 24pt
    static let sectionSpacing = xl

    /// Button padding (vertical) - 12pt
    static let buttonVertical = md

    /// Button padding (horizontal) - 24pt
    static let buttonHorizontal = xl
}
```

### ✅ Step 1.5: Create CornerRadius.swift [COMPLETED]

**File**: `ios/Bablo/Bablo/Design/Tokens/CornerRadius.swift`

```swift
import SwiftUI

/// Consistent corner radius values for UI elements
enum CornerRadius {
    /// 4pt - Minimal rounding
    static let xs: CGFloat = 4

    /// 8pt - Small elements, text fields
    static let sm: CGFloat = 8

    /// 12pt - Medium elements
    static let md: CGFloat = 12

    /// 16pt - Standard cards
    static let lg: CGFloat = 16

    /// 24pt - Hero cards, prominent elements
    static let xl: CGFloat = 24

    /// 100pt - Fully rounded (pills, buttons)
    static let pill: CGFloat = 100

    // MARK: - Semantic Aliases
    /// Standard card corner radius - 16pt
    static let card = lg

    /// Hero card corner radius - 24pt
    static let heroCard = xl

    /// Button corner radius - 100pt (pill shape)
    static let button = pill

    /// Text field corner radius - 8pt
    static let textField = sm
}
```

### ✅ Step 1.6: Create Elevation.swift [COMPLETED]

**File**: `ios/Bablo/Bablo/Design/Tokens/Elevation.swift`

```swift
import SwiftUI

/// Shadow configuration for depth/elevation system
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

/// Consistent shadow/elevation system
enum Elevation {
    // MARK: - Standard Elevations
    /// Level 1 - Subtle depth (e.g., floating buttons)
    static let level1 = ShadowStyle(
        color: Color.black.opacity(0.1),
        radius: 2,
        x: 0,
        y: 1
    )

    /// Level 2 - Cards, standard elevation
    static let level2 = ShadowStyle(
        color: Color.black.opacity(0.15),
        radius: 4,
        x: 0,
        y: 2
    )

    /// Level 3 - Raised cards, modals
    static let level3 = ShadowStyle(
        color: Color.black.opacity(0.2),
        radius: 8,
        x: 0,
        y: 4
    )

    /// Level 4 - Maximum elevation, overlays
    static let level4 = ShadowStyle(
        color: Color.black.opacity(0.25),
        radius: 16,
        x: 0,
        y: 8
    )

    // MARK: - Special Effects
    /// Glassmorphic glow (positive/teal)
    static let glowPositive = ShadowStyle(
        color: ColorPalette.glowPositive.opacity(0.5),
        radius: 20,
        x: 0,
        y: 10
    )

    /// Glassmorphic glow (negative/red)
    static let glowNegative = ShadowStyle(
        color: ColorPalette.glowNegative.opacity(0.5),
        radius: 20,
        x: 0,
        y: 10
    )

    /// Income glow (green)
    static let glowIncome = ShadowStyle(
        color: ColorPalette.glowIncome.opacity(0.3),
        radius: 8,
        x: 0,
        y: 0
    )
}

// MARK: - View Extension for Easy Shadow Application
extension View {
    func shadow(_ style: ShadowStyle) -> some View {
        self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }
}
```

### ⏳ Step 1.7: Create Button Components [NEXT]

**File**: `ios/Bablo/Bablo/Design/Components/Buttons/PrimaryButton.swift`

```swift
import SwiftUI

/// Primary button style - full color background, prominent CTA
struct PrimaryButton: ViewModifier {
    let isLoading: Bool
    let isDisabled: Bool

    init(isLoading: Bool = false, isDisabled: Bool = false) {
        self.isLoading = isLoading
        self.isDisabled = isDisabled
    }

    func body(content: Content) -> some View {
        content
            .font(Typography.buttonLabel)
            .foregroundColor(.white)
            .padding(.vertical, Spacing.buttonVertical)
            .padding(.horizontal, Spacing.buttonHorizontal)
            .frame(maxWidth: .infinity)
            .background(ColorPalette.primary)
            .cornerRadius(CornerRadius.button)
            .opacity(isLoading || isDisabled ? 0.6 : 1.0)
    }
}

extension View {
    func primaryButton(isLoading: Bool = false, isDisabled: Bool = false) -> some View {
        modifier(PrimaryButton(isLoading: isLoading, isDisabled: isDisabled))
    }
}
```

**File**: `ios/Bablo/Bablo/Design/Components/Buttons/SecondaryButton.swift`

```swift
import SwiftUI

/// Secondary button style - outlined/bordered, less prominent
struct SecondaryButton: ViewModifier {
    let isDisabled: Bool

    init(isDisabled: Bool = false) {
        self.isDisabled = isDisabled
    }

    func body(content: Content) -> some View {
        content
            .font(Typography.buttonLabel)
            .foregroundColor(ColorPalette.primary)
            .padding(.vertical, Spacing.buttonVertical)
            .padding(.horizontal, Spacing.buttonHorizontal)
            .frame(maxWidth: .infinity)
            .background(ColorPalette.primary.opacity(0.1))
            .cornerRadius(CornerRadius.button)
            .opacity(isDisabled ? 0.6 : 1.0)
    }
}

extension View {
    func secondaryButton(isDisabled: Bool = false) -> some View {
        modifier(SecondaryButton(isDisabled: isDisabled))
    }
}
```

**File**: `ios/Bablo/Bablo/Design/Components/Buttons/TertiaryButton.swift`

```swift
import SwiftUI

/// Tertiary button style - text only, minimal
struct TertiaryButton: ViewModifier {
    let isDisabled: Bool

    init(isDisabled: Bool = false) {
        self.isDisabled = isDisabled
    }

    func body(content: Content) -> some View {
        content
            .font(Typography.buttonLabel)
            .foregroundColor(ColorPalette.primary)
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.md)
            .opacity(isDisabled ? 0.6 : 1.0)
    }
}

extension View {
    func tertiaryButton(isDisabled: Bool = false) -> some View {
        modifier(TertiaryButton(isDisabled: isDisabled))
    }
}
```

### Step 1.8: Create Card Components

**File**: `ios/Bablo/Bablo/Design/Components/Cards/CardModifier.swift`

```swift
import SwiftUI

/// Standard card style - solid background with shadow
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ColorPalette.backgroundPrimary)
            .cornerRadius(CornerRadius.card)
            .shadow(Elevation.level2)
            .padding(Spacing.sm)
    }
}

extension View {
    /// Applies standard card styling
    func card() -> some View {
        modifier(CardModifier())
    }
}
```

**File**: `ios/Bablo/Bablo/Design/Components/Cards/GlassCardModifier.swift`

```swift
import SwiftUI

/// Glassmorphic hero card style - translucent with blur effect
struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.cardPadding)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
            .background {
                RoundedRectangle(
                    cornerRadius: CornerRadius.heroCard,
                    style: .continuous
                )
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(
                        cornerRadius: CornerRadius.heroCard,
                        style: .continuous
                    )
                    .stroke(ColorPalette.glassStroke, lineWidth: 1)
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
    }
}

extension View {
    /// Applies glassmorphic card styling (for hero cards)
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
}
```

### Step 1.9: Create View Extensions

**File**: `ios/Bablo/Bablo/Design/Extensions/View+DesignSystem.swift`

```swift
import SwiftUI

// MARK: - Design System View Extensions
// Centralized convenience modifiers for consistent styling

extension View {
    // Note: Button and Card modifiers are defined in their respective files
    // This file is reserved for additional shared modifiers

    /// Applies standard screen edge padding (16pt)
    func screenPadding() -> some View {
        self.padding(.horizontal, Spacing.screenEdge)
    }

    /// Applies section spacing (24pt bottom padding)
    func sectionSpacing() -> some View {
        self.padding(.bottom, Spacing.sectionSpacing)
    }
}

// MARK: - Legacy Support (Deprecated)
extension View {
    /// Legacy card background modifier
    /// - Warning: Deprecated, use `.card()` instead
    @available(*, deprecated, renamed: "card", message: "Use .card() instead")
    func cardBackground() -> some View {
        self.card()
    }
}
```

### Step 1.10: Update Existing Files

**File**: `ios/Bablo/Bablo/Util/Modifiers.swift`

Add deprecation warning to existing CardBackground:

```swift
// At the top of the file, add:
import SwiftUI

// Mark the existing CardBackground as deprecated
@available(*, deprecated, message: "Use .card() from the design system instead")
struct CardBackground: ViewModifier {
    // ... existing implementation
}
```

### Step 1.11: Verification

**Verify foundation is complete:**
1. Build the project: `xcodebuild -scheme Bablo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
2. Check for compilation errors
3. Ensure no existing UI is broken
4. Verify all new files are included in Xcode project

**Success Criteria:**
- ✅ All 11 new files created
- ✅ Project builds successfully
- ✅ No visual changes to existing UI
- ✅ Design system is ready for adoption

---

## Phase 2: Migrate High-Impact Views (Critical Path)

**Goal**: Update the most visible screens to demonstrate design system value.

### Step 2.1: Migrate HeroCardView.swift

**File**: `ios/Bablo/Bablo/UI/Home/HeroCardView.swift`

**Current Issues**:
- Line 70: `.font(.system(size: 40, weight: .bold, design: .rounded))`
- Line 75-77: Hardcoded `.green` and `.red` colors
- Line 64: `spacing: 12` hardcoded
- Line 99-104: Inline glassmorphic card definition

**Changes**:

1. Replace line 70:
```swift
// OLD
.font(.system(size: 40, weight: .bold, design: .rounded))
.monospaced()

// NEW
.font(Typography.amountDisplay)
```

2. Replace lines 75-77 (color logic):
```swift
// OLD
.foregroundColor(amount >= 0 ? .green : .red)

// NEW
.foregroundColor(amount >= 0 ? ColorPalette.success : ColorPalette.error)
```

3. Replace line 64:
```swift
// OLD
VStack(alignment: .leading, spacing: 12) {

// NEW
VStack(alignment: .leading, spacing: Spacing.md) {
```

4. Replace inline card styling (lines 99-106) by extracting content and applying `.glassCard()`:
```swift
// OLD
.padding(24)
.frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
.background {
    RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        }
}
.padding(.horizontal, 16)

// NEW
.glassCard()
```

5. Replace line 72 (`spacing: 6`):
```swift
// OLD
HStack(spacing: 6) {

// NEW
HStack(spacing: Spacing.xs) {
```

6. Update any other spacing values to use `Spacing.*`

### Step 2.2: Migrate TransactionView.swift

**File**: `ios/Bablo/Bablo/UI/Transaction/TransactionView.swift`

**Current Issues**:
- Lines 52-87: `getCategoryColor()` function with 9 hardcoded colors
- Line 17: `.font(.callout)`
- Line 23, 31, 44: `.monospaced()` fonts
- Line 36: `.font(.footnote)`

**Changes**:

1. Replace `getCategoryColor()` function (lines 52-87):
```swift
// OLD
private func getCategoryColor(for category: String?) -> Color {
    guard let category = category else { return .gray }

    switch category {
    case "INCOME": return .green
    case "TRANSFER_IN": return .blue
    case "TRANSFER_OUT": return .orange
    case "LOAN_PAYMENTS": return .purple
    case "BANK_FEES": return .red
    case "FOOD_AND_DRINK": return .pink
    case "ENTERTAINMENT": return .indigo
    case "TRAVEL": return .cyan
    default: return .teal
    }
}

// NEW
private func getCategoryColor(for category: String?) -> Color {
    guard let category = category else { return ColorPalette.categoryDefault }

    switch category {
    case "INCOME": return ColorPalette.categoryIncome
    case "TRANSFER_IN": return ColorPalette.categoryTransferIn
    case "TRANSFER_OUT": return ColorPalette.categoryTransferOut
    case "LOAN_PAYMENTS": return ColorPalette.categoryLoanPayments
    case "BANK_FEES": return ColorPalette.categoryBankFees
    case "FOOD_AND_DRINK": return ColorPalette.categoryFood
    case "ENTERTAINMENT": return ColorPalette.categoryEntertainment
    case "TRAVEL": return ColorPalette.categoryTravel
    default: return ColorPalette.categoryDefault
    }
}
```

2. Replace line 17:
```swift
// OLD
.font(.callout)

// NEW
.font(Typography.body)
```

3. Replace lines 23, 31, 44:
```swift
// OLD
Text(formattedAmount).monospaced()

// NEW
Text(formattedAmount).font(Typography.transactionAmount)
```

4. Replace line 36:
```swift
// OLD
.font(.footnote)

// NEW
.font(Typography.transactionDetail)
```

5. Replace line 49 (if exists):
```swift
// OLD
.padding(1)

// NEW
.padding(Spacing.xxs)
```

### Step 2.3: Migrate HomeView.swift

**File**: `ios/Bablo/Bablo/UI/Home/HomeView.swift`

**Current Issues**:
- Line 24: `spacing: 20`
- Line 41: `Color.yellow.opacity(0.2)`
- Line 52: `spacing: 16`
- Line 88: `.font(.headline)`

**Changes**:

1. Replace line 24:
```swift
// OLD
VStack(spacing: 20) {

// NEW
VStack(spacing: Spacing.xl) {
```

2. Replace line 41:
```swift
// OLD
.background(Color.yellow.opacity(0.2))

// NEW
.background(ColorPalette.warning.opacity(0.2))
```

3. Replace line 52:
```swift
// OLD
VStack(alignment: .leading, spacing: 16) {

// NEW
VStack(alignment: .leading, spacing: Spacing.lg) {
```

4. Replace line 88:
```swift
// OLD
.font(.headline)

// NEW
.font(Typography.h4)
```

5. Look for any `.cornerRadius()` calls and replace with `CornerRadius.*`
6. Look for any `.padding()` values and replace with `Spacing.*`

### Step 2.4: Migrate WelcomeView.swift

**File**: `ios/Bablo/Bablo/UI/Auth/WelcomeView.swift`

**Current Issues**:
- Line 25: `.font(.system(size: 80))`
- Line 30: `.largeTitle` with `.fontWeight(.black)`
- Line 20: `spacing: 32` and `spacing: 24`
- Lines 49, 70: Button styling with hardcoded corner radius 8
- Line 50: `.padding(.horizontal, 40)`

**Changes**:

1. Replace line 25:
```swift
// OLD
.font(.system(size: 80))

// NEW
.font(Typography.displayLarge)
```

2. Replace line 30:
```swift
// OLD
.font(.largeTitle)
.fontWeight(.black)

// NEW
.font(Typography.h1)
```

3. Replace line 20:
```swift
// OLD
VStack(spacing: 32) {
    VStack(spacing: 24) {

// NEW
VStack(spacing: Spacing.xxl) {
    VStack(spacing: Spacing.xl) {
```

4. Replace primary button (around line 49):
```swift
// OLD
Button {
    showEmailAuth = true
} label: {
    Text("Sign in with Email")
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.accentColor)
        .cornerRadius(8)
}
.padding(.horizontal, 40)

// NEW
Button {
    showEmailAuth = true
} label: {
    Text("Sign in with Email")
}
.primaryButton()
.screenPadding()
```

5. Replace secondary button (around line 70):
```swift
// OLD
Button {
    // Sign in with Apple
} label: {
    Text("Sign in with Apple")
        .font(.headline)
        .foregroundColor(.accentColor)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(8)
}
.padding(.horizontal, 40)

// NEW
Button {
    // Sign in with Apple
} label: {
    Text("Sign in with Apple")
}
.secondaryButton()
.screenPadding()
```

### Step 2.5: Migrate TotalBalanceView.swift

**File**: `ios/Bablo/Bablo/UI/Budget/TotalBalanceView.swift`

**Current Issues**:
- Line 21: `.monospaced()` font
- Line 25: `.font(.title2)`

**Changes**:

1. Replace line 21:
```swift
// OLD
Text(formattedBalance).monospaced()

// NEW
Text(formattedBalance).font(Typography.monoLarge)
```

2. Replace line 25:
```swift
// OLD
.font(.title2)

// NEW
.font(Typography.h3)
```

3. Replace any spacing/padding values with `Spacing.*`

### Step 2.6: Verification

**Test high-impact views:**
1. Run app in simulator: Light mode
2. Run app in simulator: Dark mode
3. Navigate to Home screen - verify HeroCard looks correct
4. Scroll transactions - verify colors and fonts
5. Go to Welcome screen - verify buttons
6. Check budget view - verify numbers display correctly

**Success Criteria:**
- ✅ All 5 high-impact views migrated
- ✅ Visual consistency improved
- ✅ No layout breaks
- ✅ Light/dark mode work correctly

---

## Phase 3: Migrate Remaining Views by Directory

**Goal**: Complete migration across all 49 files systematically.

### General Migration Pattern (For Each File)

**Step-by-step process to apply to each view:**

1. **Read the file** to understand structure
2. **Search and replace patterns**:
   - `.padding(N)` → `Spacing.*` (choose appropriate size)
   - `.font(.system(size: N))` → `Typography.*`
   - `.cornerRadius(N)` → `CornerRadius.*`
   - Color literals (`.blue`, `.green`, `.red`) → `ColorPalette.*`
   - `.monospaced()` → Use `Typography.mono*` variants
3. **Update button patterns** to `.primaryButton()`, `.secondaryButton()`, etc.
4. **Test in preview** if available
5. **Build and verify** no compilation errors

### Step 3.1: Migrate Onboarding Views (11 files)

**Priority order** (highest impact first):

1. **OnboardingBudgetView.swift**:
   - Line 17: `Color(red: 0.5, green: 1.0, blue: 0.0).opacity(0.1)` → `ColorPalette.glowIncome.opacity(0.1)`
   - Line 24: `.font(.system(size: 32, weight: .bold, design: .rounded))` → `Typography.h1`
   - Line 62: `.font(.system(size: 44, weight: .bold, design: .rounded))` → `Typography.displayMedium`
   - Line 36: `.font(.system(size: 20, weight: .medium))` → `Typography.h4`
   - Line 32: `.font(.system(size: 14, weight: .bold))` → `Typography.captionBold`
   - All spacing values (22, 39, 54, 75, 77, 79) → `Spacing.*`
   - Line 77: Corner radius 24 → `CornerRadius.heroCard`

2. **IncomeInputView.swift**:
   - Line 16: `spacing: 8` → `Spacing.sm`
   - Line 28: `.background(Color.systemBackground)` → `ColorPalette.backgroundPrimary`
   - Line 29: `.cornerRadius(12)` → `CornerRadius.md`

3. **BudgetRowView.swift**:
   - Line 39: `.green` color → `ColorPalette.success`
   - Any font/spacing values → Design system

4. **CategoryRowView.swift, DiscretionarySpendingView.swift, ExpenseSection.swift**:
   - Apply general migration pattern

5. **OnboardingWizard.swift**:
   - Update all button styles to use `.primaryButton()`, `.secondaryButton()`
   - Replace spacing/padding values

6. **Remaining files**: OnboardingStartView, OnboardingWalletView, OnboardingAccountsView, OnboardingCategoriesView, OnboardingBudgetHeaderView, OnboardingBudgetFooterView, PeriodPickerView, CurrencyTextField
   - Apply general migration pattern to each

### Step 3.2: Migrate Auth Views (7 files)

1. **EmailAuthView.swift**:
   - Line 28: Button styling → `.primaryButton()`
   - Line 53, 71: `.cornerRadius(8)` → `CornerRadius.textField`
   - All spacing/padding → `Spacing.*`

2. **EmailOTPVerificationView.swift**:
   - Update button styles
   - Replace spacing values

3. **PhoneSignUpView.swift, OTPVerificationView.swift, AuthenticationView.swift, BiometricsEnrollmentView.swift**:
   - Apply general migration pattern

### Step 3.3: Migrate Bank Views (7 files)

1. **BankView.swift**:
   - Line 13-15: Keep dynamic hex color (from database) but add fallback:
     ```swift
     Color(hex: bank.primary_color) ?? ColorPalette.primary
     ```
   - Line 19: `spacing: 12` → `Spacing.md`

2. **BankListView.swift, BankListTabView.swift, BankDetailView.swift**:
   - Apply general migration pattern

3. **BankAccount/BankAccountView.swift, BankAccountDetailView.swift**:
   - Apply general migration pattern

### Step 3.4: Migrate Transaction Views (5 remaining files)

1. **AllTransactionsView.swift**:
   - Apply general migration pattern

2. **RecentTransactionsView.swift**:
   - Line 16: `.font(.headline)` → `Typography.h4`
   - Update spacing values

3. **Transaction+Extensions.swift**:
   - Review for any UI-related code
   - May not need changes (mostly logic)

4. **ListComponents/DayHeaderView.swift**:
   - Line 15: `spacing: 1` → `Spacing.xxs`
   - Line 24: `spacing: 4` → `Spacing.xs`
   - Line 56: `.padding(.vertical, 6)` → `Spacing.xs`
   - Line 57: `.padding(16)` → `Spacing.lg`

5. **ListComponents/MonthHeaderView.swift, EmptyTransactionsView.swift, TransactionsListView.swift**:
   - Apply general migration pattern

### Step 3.5: Migrate Spend Views (2 files)

1. **SpendView.swift**:
   - Lines 54-73: Keep dynamic HSV color generation for bar charts (visual feature)
   - Line 144: `.padding(12)` → `Spacing.md`
   - Line 147: `.cornerRadius(8)` → `CornerRadius.sm`
   - Update other spacing/fonts

2. **CategorySpendDetailView.swift**:
   - Apply general migration pattern

### Step 3.6: Migrate Remaining Views

1. **ProfileView.swift**:
   - Apply general migration pattern

2. **HeroCarouselView.swift**:
   - Line 18: `spacing: 0` → Keep as `0` (deliberate tight spacing)
   - Line 21: `.cornerRadius(24)` → `CornerRadius.heroCard`

3. **HeroBudgetEmptyStateView.swift**:
   - Line 7: `spacing: 16` → `Spacing.lg`
   - Update other values

### Step 3.7: Update LargeButton Component

**File**: `ios/Bablo/Bablo/Design/Components/LargeButton.swift`

Refactor to use design system:

```swift
import SwiftUI

struct LargeButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .primaryButton(isLoading: isLoading, isDisabled: isDisabled)
    }
}
```

### Step 3.8: Verification (Per Directory)

**After completing each directory:**
1. Build project: `xcodebuild -scheme Bablo build`
2. Run on simulator
3. Navigate to screens in that section
4. Verify light/dark mode
5. Take screenshots for comparison

**Success Criteria:**
- ✅ All 49 view files migrated
- ✅ No compilation errors
- ✅ Visual consistency across entire app
- ✅ No regressions in functionality

---

## Phase 4: Cleanup and Refinement

**Goal**: Remove deprecated code, audit for missed instances, polish.

### Step 4.1: Remove Deprecated Code

1. **Delete old CardBackground** from `ios/Bablo/Bablo/Util/Modifiers.swift`:
   - Remove the entire `CardBackground` struct
   - Update imports if needed

2. **Update View+Extensions.swift** (`ios/Bablo/Bablo/Util/View+Extensions.swift`):
   - Remove old `.cardBackground()` extension if it exists

3. **Search for deprecated usage**:
   ```bash
   grep -r "cardBackground()" ios/Bablo/Bablo/UI/
   ```
   - Should return no results

### Step 4.2: Audit for Hardcoded Values

Run these grep commands to find any remaining issues:

```bash
# Find hardcoded colors
grep -rn "\.blue\|\.green\|\.red\|\.orange\|\.purple\|\.pink\|\.indigo\|\.cyan" ios/Bablo/Bablo/UI/ | grep -v "ColorPalette"

# Find hardcoded font sizes
grep -rn "\.system(size:" ios/Bablo/Bablo/UI/ | grep -v "Typography"

# Find hardcoded padding/spacing
grep -rn "\.padding([0-9]" ios/Bablo/Bablo/UI/ | grep -v "Spacing"

# Find hardcoded corner radius
grep -rn "\.cornerRadius([0-9]" ios/Bablo/Bablo/UI/ | grep -v "CornerRadius"
```

**Action**: Fix any remaining instances found.

### Step 4.3: Documentation

Add comments to design system files explaining usage:

1. **ColorPalette.swift**: Add usage examples at top:
```swift
/// Centralized color palette for the MyMoney app
///
/// Usage:
/// ```swift
/// Text("Hello").foregroundColor(ColorPalette.textPrimary)
/// Rectangle().fill(ColorPalette.success)
/// ```
///
/// All colors support light/dark mode automatically.
struct ColorPalette {
```

2. **Typography.swift**: Add hierarchy explanation
3. **Spacing.swift**: Add grid system explanation

### Step 4.4: Xcode Project Organization

Ensure all design system files are organized in Xcode:
1. Open Xcode project
2. Create folder structure matching file system
3. Verify all files are in correct groups
4. Update file references if needed

### Step 4.5: Final Build and Test

1. **Clean build**:
   ```bash
   xcodebuild clean -scheme Bablo
   xcodebuild build -scheme Bablo -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
   ```

2. **Run full app test**:
   - Launch on iPhone SE (small screen)
   - Launch on iPhone Pro Max (large screen)
   - Test light mode
   - Test dark mode
   - Navigate through all major screens
   - Verify animations/transitions
   - Check for any layout warnings in console

3. **Performance check**:
   - Profile with Instruments (Time Profiler)
   - Ensure no performance regressions
   - Check memory usage

### Step 4.6: Before/After Comparison

**Create screenshot comparison**:
1. Take screenshots of key screens
2. Compare with pre-migration screenshots (if available)
3. Document visual improvements

**Success Criteria:**
- ✅ Zero hardcoded values remaining
- ✅ Clean build with no warnings
- ✅ All screens tested in light/dark mode
- ✅ Performance is maintained or improved

---

## Phase 5: Git Commit Strategy

**Goal**: Create clean, reviewable git history.

### Commit Structure

**Commit 1: Add design system foundation**
```bash
git add ios/Bablo/Bablo/Design/
git commit -m "Add design system foundation

- Add ColorPalette with semantic colors and category colors
- Add Typography with consistent type scale
- Add Spacing tokens (8pt grid system)
- Add CornerRadius and Elevation tokens
- Add PrimaryButton, SecondaryButton, TertiaryButton components
- Add CardModifier and GlassCardModifier
- Add View+DesignSystem extensions
- Deprecate old CardBackground modifier

This establishes the infrastructure for unified design language
across the app without breaking existing UI."
```

**Commit 2: Migrate high-impact views**
```bash
git add ios/Bablo/Bablo/UI/Home/HeroCardView.swift
git add ios/Bablo/Bablo/UI/Transaction/TransactionView.swift
git add ios/Bablo/Bablo/UI/Home/HomeView.swift
git add ios/Bablo/Bablo/UI/Auth/WelcomeView.swift
git add ios/Bablo/Bablo/UI/Budget/TotalBalanceView.swift
git commit -m "Migrate high-impact views to design system

- HeroCardView: Use Typography.amountDisplay, ColorPalette, .glassCard()
- TransactionView: Use ColorPalette for category colors, Typography.transactionAmount
- HomeView: Use Spacing tokens, Typography.h4
- WelcomeView: Use .primaryButton(), .secondaryButton(), Typography.displayLarge
- TotalBalanceView: Use Typography.monoLarge

These views represent the most visible parts of the app and
demonstrate the design system in action."
```

**Commit 3: Migrate onboarding views**
```bash
git add ios/Bablo/Bablo/UI/Onboarding/
git commit -m "Migrate onboarding views to design system

Update all 11 onboarding-related views to use:
- Typography scale instead of custom font sizes
- ColorPalette for consistent colors
- Spacing tokens for layout
- Standard button components"
```

**Commit 4: Migrate auth views**
```bash
git add ios/Bablo/Bablo/UI/Auth/
git commit -m "Migrate auth views to design system

Update authentication flow screens with consistent styling"
```

**Commit 5: Migrate bank and transaction views**
```bash
git add ios/Bablo/Bablo/UI/Bank/
git add ios/Bablo/Bablo/UI/Transaction/
git commit -m "Migrate bank and transaction views to design system

Standardize financial data display with monospaced fonts,
consistent spacing, and semantic colors"
```

**Commit 6: Migrate remaining views**
```bash
git add ios/Bablo/Bablo/UI/Spend/
git add ios/Bablo/Bablo/UI/Profile/
git add ios/Bablo/Bablo/UI/Home/HeroCarouselView.swift
git add ios/Bablo/Bablo/UI/Home/HeroBudgetEmptyStateView.swift
git commit -m "Migrate remaining views to design system

Complete migration of all 49 UI files"
```

**Commit 7: Cleanup**
```bash
git add ios/Bablo/Bablo/Design/Components/LargeButton.swift
git add ios/Bablo/Bablo/Util/Modifiers.swift
git commit -m "Remove deprecated design code

- Delete old CardBackground modifier
- Update LargeButton to use design system
- Remove legacy code from utilities"
```

---

## Verification Checklist

### Design System Foundation
- [ ] All 11 foundation files created
- [ ] Project builds without errors
- [ ] No visual changes to existing UI
- [ ] All files added to Xcode project

### High-Impact Views
- [ ] HeroCardView uses glassmorphic card modifier
- [ ] Transaction colors use ColorPalette
- [ ] HomeView spacing is consistent
- [ ] WelcomeView buttons use design system
- [ ] Numbers display with monospaced fonts

### Complete Migration
- [ ] All 49 view files updated
- [ ] Zero hardcoded colors (except bank hex from DB)
- [ ] Zero hardcoded font sizes
- [ ] Zero hardcoded spacing values
- [ ] All buttons use button components

### Quality Assurance
- [ ] App builds without warnings
- [ ] Light mode displays correctly
- [ ] Dark mode displays correctly
- [ ] iPhone SE (small screen) works
- [ ] iPhone Pro Max (large screen) works
- [ ] No layout constraint errors in console
- [ ] Performance is maintained

### Git History
- [ ] 7 logical commits created
- [ ] Commit messages are clear
- [ ] Each commit builds successfully
- [ ] History is reviewable

---

## Success Metrics

**Quantitative Goals:**
- ✅ 98 hardcoded color instances → 0 (except dynamic bank colors)
- ✅ 496 typography instances → Use Typography.*
- ✅ 15+ unique spacing values → 8 consistent tokens
- ✅ 5+ button variants → 3 standard components
- ✅ 49 view files migrated

**Qualitative Goals:**
- ✅ Visual consistency across entire app
- ✅ Proper light/dark mode support
- ✅ Easier to maintain and extend
- ✅ Better onboarding for new developers
- ✅ Professional, polished appearance

---

## Critical File Paths Reference

### Design System Files (To Create)
- `/ios/Bablo/Bablo/Design/Theme/ColorPalette.swift`
- `/ios/Bablo/Bablo/Design/Theme/Typography.swift`
- `/ios/Bablo/Bablo/Design/Tokens/Spacing.swift`
- `/ios/Bablo/Bablo/Design/Tokens/CornerRadius.swift`
- `/ios/Bablo/Bablo/Design/Tokens/Elevation.swift`
- `/ios/Bablo/Bablo/Design/Components/Buttons/PrimaryButton.swift`
- `/ios/Bablo/Bablo/Design/Components/Buttons/SecondaryButton.swift`
- `/ios/Bablo/Bablo/Design/Components/Buttons/TertiaryButton.swift`
- `/ios/Bablo/Bablo/Design/Components/Cards/CardModifier.swift`
- `/ios/Bablo/Bablo/Design/Components/Cards/GlassCardModifier.swift`
- `/ios/Bablo/Bablo/Design/Extensions/View+DesignSystem.swift`

### High-Priority Views (Migrate First)
- `/ios/Bablo/Bablo/UI/Home/HeroCardView.swift`
- `/ios/Bablo/Bablo/UI/Transaction/TransactionView.swift`
- `/ios/Bablo/Bablo/UI/Home/HomeView.swift`
- `/ios/Bablo/Bablo/UI/Auth/WelcomeView.swift`
- `/ios/Bablo/Bablo/UI/Budget/TotalBalanceView.swift`

### Files to Deprecate
- `/ios/Bablo/Bablo/Util/Modifiers.swift` (CardBackground)
- `/ios/Bablo/Bablo/Design/Components/LargeButton.swift` (refactor)

---

## Notes for Execution

1. **Each step is independent**: Can be executed by different models or in different sessions
2. **Build verification**: Run build after each major phase
3. **Visual testing**: Use simulator for manual verification
4. **Git discipline**: Commit frequently, one logical change per commit
5. **Rollback strategy**: Each commit should be revertable without breaking the build
6. **Parallel work**: Phase 3 migration can be parallelized by directory

**Estimated Execution Time**:
- Phase 1 (Foundation): 30-45 minutes
- Phase 2 (High-Impact): 30-45 minutes
- Phase 3 (Remaining Views): 2-3 hours
- Phase 4 (Cleanup): 30 minutes
- Phase 5 (Git): 15 minutes

**Total: 4-5.5 hours of focused work**
# Hero Card Implementation Plan

This document outlines the steps to replace the existing `TotalBalanceView` with a new, interactive hero card carousel, as detailed in the provided mockup.

## Phase 1: Create the Core `HeroCardView` Component

The goal of this phase is to create a reusable SwiftUI view for a single card.

1.  **Create New File**: Create a new SwiftUI View file named `HeroCardView.swift` in `ios/Bablo/Bablo/UI/Home/`.
2.  **Define Data Model**: Create a `struct` or `ViewModel` to represent the data for a single card. This model should include:
    *   `title`: String (e.g., "Net Available Cash")
    *   `amount`: Double
    *   `monthlyChange`: Double (e.g., +$320)
    *   `isPositive`: Bool (to determine if the change is a surplus or deficit)
3.  **Build Static UI**:
    *   Use a `VStack` for the main vertical layout of the card.
    *   Add a `Text` view for the `title`.
    *   Add a `Text` view for the `amount`, styled with a larger, bold font.
    *   Add an `HStack` for the bottom "surplus" line, containing:
        *   An `Image` for the up/down arrow (`Image(systemName: isPositive ? "arrow.up" : "arrow.down")`).
        *   A `Text` view to describe the status (e.g., "Healthy Surplus").
        *   A `Text` view for the monthly change amount.
4.  **Apply Styling**:
    *   Use a `RoundedRectangle` as the background.
    *   Apply the "glassmorphism" effect using a background material: `.background(.ultraThinMaterial)`.
    *   Match the fonts, colors, and padding from the mockup. Use the existing design system for colors where possible.

## Phase 2: Implement the Conditional Glow and Card Stack Effect

This phase focuses on the dynamic visual effects.

1.  **Implement Conditional Glow**:
    *   In `HeroCardView`, create a view modifier or a computed property for the background glow.
    *   The glow should be a `RadialGradient` or a `.shadow()` effect applied to the container.
    *   The color of the glow will be **green** if `isPositive` is `true`, and **red** otherwise.
    .
2.  **Create Card Stack Illusion**:
    *   The pager will display one card at a time. To hint that there are other cards, we can use a `ZStack`.
    *   The main `TabView` will sit on top.
    *   Behind it, add one or two slightly offset and scaled-down `RoundedRectangle` views to mimic the appearance of cards underneath.

## Phase 3: Create the Swipeable Carousel View

This phase will create the container that manages the different hero cards.

1.  **Create New File**: Create a new SwiftUI View file named `HeroCarouselView.swift` in `ios/Bablo/Bablo/UI/Home/`.
2.  **Implement TabView Pager**:
    *   Use a `TabView` as the root component.
    *   Apply the `.tabViewStyle(.page(indexDisplayMode: .always))` modifier. This creates the swipeable pager and displays the page indicator dots at the bottom.
3.  **Populate with Data**:
    *   Create a sample array of the `HeroCardViewModel` you defined in Phase 1.
    *   The first card should represent "Net Available Cash".
    *   Add 1-2 placeholder cards with "TBD" as the title, as their content is not yet defined.
4.  **Render Cards**:
    *   Inside the `TabView`, use a `ForEach` loop to iterate over the array of card data.
    *   For each item, create an instance of `HeroCardView`, passing in the corresponding data.

## Phase 4: Integrate into the Home Screen

This final phase involves replacing the old view with the new carousel.

1.  **Locate Home View**: Open `HomeView.swift`.
2.  **Replace `TotalBalanceView`**:
    *   Find the line(s) where `TotalBalanceView` is being used.
    *   Comment out or delete the `TotalBalanceView`.
    *   In its place, add the newly created `HeroCarouselView`.
3.  **Wire Up Real Data**:
    *   Instead of using the sample data from Phase 3, fetch the actual financial data (total balance, monthly surplus/deficit) from the appropriate service (e.g., `BankAccountsService` or `UserAccount`).
    *   Pass this live data to the `HeroCarouselView` to display on the main card.
4.  **Test and Refine**:
    *   Build and run the app.
    *   Verify that the new hero carousel appears correctly.
    *   Test the swipe gesture.
    *   Confirm that the glow color changes based on whether the monthly change is positive or negative.
    *   Adjust layout, padding, and styling as needed to ensure it fits perfectly within the `HomeView` design.

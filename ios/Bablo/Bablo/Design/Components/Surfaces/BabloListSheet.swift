import SwiftUI

/// Representing a single category filter pill/chip.
struct BabloFilterChip<Value: Hashable>: Identifiable {
    let id: Value
    let title: String
    let count: Int?
}

/// Representing an option in the sorting selector.
struct BabloSortOption<Value: Hashable>: Identifiable {
    let id: Value
    let title: String
}

/// A generic, highly-reusable bottom sheet list template designed to conform to the new design system.
/// This container takes care of:
/// 1. Top drag bar, top category label, bold title, dynamic subtitle, close button, and optional period control.
/// 2. Clean, custom styled search bar with search query bindings and a clear button.
/// 3. Scrollable filter chips (dark active pills, bordered inactive capsules).
/// 4. Results counts & sort options bar with context menu.
/// 5. Custom `@ViewBuilder` content for the scrollable list.
struct BabloListSheet<FilterValue: Hashable, SortValue: Hashable, Content: View>: View {
    let categoryLabel: String
    let title: String
    let subtitle: String
    let searchPlaceholder: String
    @Binding var searchQuery: String
    
    let filterChips: [BabloFilterChip<FilterValue>]
    @Binding var selectedFilter: FilterValue
    
    let sortOptions: [BabloSortOption<SortValue>]
    @Binding var selectedSort: SortValue
    
    let resultsCountLabel: String
    let dismissAction: () -> Void
    var periodSelector: AnyView? = nil
    
    // Custom configurations
    let showDragHandle: Bool
    let showCloseButton: Bool
    let showBackButton: Bool
    
    @ViewBuilder let content: () -> Content
    
    @Environment(\.babloTheme) private var theme
    
    init(
        categoryLabel: String,
        title: String,
        subtitle: String,
        searchPlaceholder: String,
        searchQuery: Binding<String>,
        filterChips: [BabloFilterChip<FilterValue>],
        selectedFilter: Binding<FilterValue>,
        sortOptions: [BabloSortOption<SortValue>],
        selectedSort: Binding<SortValue>,
        resultsCountLabel: String,
        dismissAction: @escaping () -> Void,
        periodSelector: AnyView? = nil,
        showDragHandle: Bool = true,
        showCloseButton: Bool = true,
        showBackButton: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.categoryLabel = categoryLabel
        self.title = title
        self.subtitle = subtitle
        self.searchPlaceholder = searchPlaceholder
        self._searchQuery = searchQuery
        self.filterChips = filterChips
        self._selectedFilter = selectedFilter
        self.sortOptions = sortOptions
        self._selectedSort = selectedSort
        self.resultsCountLabel = resultsCountLabel
        self.dismissAction = dismissAction
        self.periodSelector = periodSelector
        self.showDragHandle = showDragHandle
        self.showCloseButton = showCloseButton
        self.showBackButton = showBackButton
        self.content = content
    }
    
    var body: some View {
        let isPopArt = theme.effects.isPopArt
        
        VStack(spacing: 0) {
            if showDragHandle {
                // Drag Indicator Handle
                Capsule()
                    .fill(theme.colors.textSecondary.color.opacity(0.2))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
            } else {
                Spacer()
                    .frame(height: 16)
            }
            
            // Header: Category, Title, Subtitle, Close Button & Optional Period Control
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    HStack(alignment: .center, spacing: 12) {
                        if showBackButton {
                            Button(action: dismissAction) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(theme.colors.textPrimary.color)
                                    .frame(width: 32, height: 32)
                                    .background(theme.colors.surfaceMuted.color)
                                    .clipShape(Circle())
                                    .overlay {
                                        if isPopArt {
                                            Circle()
                                                .stroke(theme.colors.lineStrong.color, lineWidth: 1.5)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Back")
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(categoryLabel)
                                .font(theme.typography.mono(size: 11, weight: .bold))
                                .tracking(theme.typography.labelTracking)
                                .textCase(.uppercase)
                                .foregroundStyle(theme.colors.textTertiary.color)
                            
                            Text(title)
                                .font(theme.typography.title(size: 26, weight: isPopArt ? .black : .bold))
                                .foregroundStyle(theme.colors.textPrimary.color)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        if let periodSelector {
                            periodSelector
                        }
                        
                        if showCloseButton {
                            Button(action: dismissAction) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(theme.colors.textPrimary.color)
                                    .frame(width: 32, height: 32)
                                    .background(theme.colors.surfaceMuted.color)
                                    .clipShape(Circle())
                                    .overlay {
                                        if isPopArt {
                                            Circle()
                                                .stroke(theme.colors.lineStrong.color, lineWidth: 1.5)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Close")
                        }
                    }
                }
                
                Text(subtitle)
                    .font(theme.typography.body(size: 13, weight: .medium))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            
            Divider()
                .overlay(theme.colors.line.color)
            
            // Search Box (Rounded, surfaceMuted background)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.textTertiary.color)
                
                TextField(searchPlaceholder, text: $searchQuery)
                    .font(theme.typography.body(size: 14, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .tint(theme.colors.textPrimary.color)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.colors.textTertiary.color)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(theme.colors.surfaceMuted.color)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                if isPopArt {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.colors.lineStrong.color, lineWidth: 1.5)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            
            // Horizontal scroll of category chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filterChips) { chip in
                        let isSelected = chip.id == selectedFilter
                        Button {
                            selectedFilter = chip.id
                        } label: {
                            HStack(spacing: 4) {
                                Text(chip.title)
                                    .font(theme.typography.body(size: 13, weight: .bold))
                                
                                if let count = chip.count {
                                    Text("\(count)")
                                        .font(theme.typography.body(size: 11, weight: .semibold))
                                        .foregroundStyle(isSelected ? theme.colors.surface.color.opacity(0.8) : theme.colors.textTertiary.color)
                                }
                            }
                            .foregroundStyle(isSelected ? theme.colors.surface.color : theme.colors.textSecondary.color)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(isSelected ? theme.colors.textPrimary.color : theme.colors.surface.color)
                            .clipShape(Capsule())
                            .overlay {
                                if !isSelected {
                                    Capsule()
                                        .stroke(theme.colors.lineStrong.color, lineWidth: 1)
                                } else if isPopArt {
                                    Capsule()
                                        .stroke(theme.colors.lineStrong.color, lineWidth: 1.5)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 16)
            
            // Section Header: Results count and dynamic sorting trigger
            HStack {
                Text(resultsCountLabel)
                    .font(theme.typography.mono(size: 11, weight: .bold))
                    .tracking(theme.typography.labelTracking)
                    .foregroundStyle(theme.colors.textTertiary.color)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.colors.textSecondary.color)
                    
                    Menu {
                        Picker("Sort by", selection: $selectedSort) {
                            ForEach(sortOptions) { option in
                                Text(option.title).tag(option.id)
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text("Sort:")
                                .font(theme.typography.body(size: 13, weight: .semibold))
                                .foregroundStyle(theme.colors.textSecondary.color)
                            
                            let activeTitle = sortOptions.first(where: { $0.id == selectedSort })?.title ?? ""
                            Text(activeTitle)
                                .font(theme.typography.body(size: 13, weight: .bold))
                                .foregroundStyle(theme.colors.textPrimary.color)
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(theme.colors.textSecondary.color)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            Divider()
                .overlay(theme.colors.line.color)
            
            // Content
            ScrollView {
                VStack(spacing: 0) {
                    content()
                }
                .padding(.bottom, 32)
            }
        }
        .background(theme.colors.surface.color)
        .ignoresSafeArea(edges: .bottom)
    }
}

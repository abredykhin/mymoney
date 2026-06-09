import SwiftUI

struct BabloSegmentedControl<Selection: Hashable>: View {
    struct Item: Identifiable {
        let id: Selection
        let title: String
    }

    enum Size {
        case regular
        case compact
        case mini
    }

    let items: [Item]
    @Binding var selection: Selection
    let size: Size
    @Environment(\.babloTheme) private var theme

    init(items: [Item], selection: Binding<Selection>, size: Size = .regular) {
        self.items = items
        self._selection = selection
        self.size = size
    }

    var body: some View {
        HStack(spacing: theme.effects.isPopArt ? 0 : spacing) {
            ForEach(items) { item in
                Button {
                    selection = item.id
                } label: {
                    Text(item.title)
                        .font(theme.typography.body(size: fontSize, weight: .bold))
                        .tracking(theme.effects.isPopArt ? theme.typography.labelTracking : 0)
                        .textCase(theme.effects.isPopArt ? .uppercase : nil)
                        .foregroundStyle(foreground(for: item))
                        .frame(minWidth: minSegmentWidth, minHeight: minSegmentHeight)
                        .padding(.horizontal, horizontalPadding)
                        .background(background(for: item))
                        .clipShape(RoundedRectangle(cornerRadius: segmentCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(theme.effects.isPopArt ? 0 : outerPadding)
        .background(theme.colors.surfaceMuted.color)
        .clipShape(RoundedRectangle(cornerRadius: theme.effects.isPopArt ? theme.metrics.controlCornerRadius : 999, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.effects.isPopArt ? theme.metrics.controlCornerRadius : 999, style: .continuous)
                .stroke(theme.colors.line.color, lineWidth: theme.effects.isPopArt ? theme.metrics.borderWidth : theme.metrics.borderWidth)
        }
    }

    private var segmentCornerRadius: CGFloat {
        theme.effects.isPopArt ? theme.metrics.controlCornerRadius : 999
    }

    private var fontSize: CGFloat {
        switch size {
        case .regular: 13
        case .compact: 11.5
        case .mini: 10.5
        }
    }

    private var minSegmentWidth: CGFloat {
        switch size {
        case .regular: 62
        case .compact: 48
        case .mini: 42
        }
    }

    private var minSegmentHeight: CGFloat {
        switch size {
        case .regular: 36
        case .compact: 26
        case .mini: 23
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .regular: 8
        case .compact: 6
        case .mini: 5
        }
    }

    private var outerPadding: CGFloat {
        switch size {
        case .regular: 4
        case .compact: 3
        case .mini: 2
        }
    }

    private var spacing: CGFloat {
        switch size {
        case .regular: 4
        case .compact: 3
        case .mini: 2
        }
    }

    private func foreground(for item: Item) -> Color {
        guard item.id == selection else { return theme.colors.textSecondary.color }
        return theme.effects.isPopArt ? theme.colors.surface.color : theme.colors.textPrimary.color
    }

    private func background(for item: Item) -> Color {
        guard item.id == selection else { return .clear }
        return theme.effects.isPopArt ? theme.colors.textPrimary.color : theme.colors.surface.color
    }
}

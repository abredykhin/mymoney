//
//  HomeWidgetCard.swift
//  Bablo
//

import SwiftUI

struct HomeWidgetCard<Content: View>: View {
    let title: String
    let badge: String?
    let badgeColor: Color?
    let titleIconName: String?
    let titleIconColor: Color?
    let content: Content

    @Environment(\.babloTheme) private var theme

    init(
        title: String,
        badge: String? = nil,
        badgeColor: Color? = nil,
        titleIconName: String? = nil,
        titleIconColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.badge = badge
        self.badgeColor = badgeColor
        self.titleIconName = titleIconName
        self.titleIconColor = titleIconColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row: Title, Optional Badge, Spacer, Optional Icon
            HStack(alignment: .center, spacing: 5) {
                Text(title.uppercased())
                    .font(theme.typography.mono(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(theme.colors.textTertiary.color)

                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor ?? theme.colors.danger.color)
                        .cornerRadius(6)
                }

                Spacer()

                if let icon = titleIconName {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(titleIconColor ?? theme.colors.textSecondary.color)
                }
            }

            // Inner Content
            content
        }
        .babloCard(tone: .surface, padding: 14)
    }
}

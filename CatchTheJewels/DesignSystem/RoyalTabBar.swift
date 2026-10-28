import SwiftUI

/// Custom four-tab bottom navigation: translucent dark emerald with a fine gold top
/// border and an animated rounded indicator behind the selected tab.
struct RoyalTabBar: View {
    let selection: AppTab
    let onSelect: (AppTab) -> Void

    @Environment(\.prefersReducedMotion) private var reduceMotion
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.top, Theme.Spacing.xs)
        .padding(.bottom, Theme.Spacing.xxs)
        .frame(maxWidth: Theme.Layout.maxContentWidth)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(Theme.Colors.emeraldDeep.opacity(0.82))
                Rectangle()
                    .fill(LinearGradient(colors: [Theme.Colors.gold.opacity(0.2), Theme.Colors.gold, Theme.Colors.gold.opacity(0.2)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
            }
            // Extend the background under the home indicator; the buttons stay above it.
            .ignoresSafeArea(edges: .bottom)
        }
        .environment(\.colorScheme, .dark)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tab bar")
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        return Button {
            guard !isSelected else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.75)) {
                onSelect(tab)
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 21, weight: .semibold))
                    .frame(height: 26)
                    .scaleEffect(isSelected && !reduceMotion ? 1.08 : 1)
                Text(tab.title)
                    .font(.system(.caption2, design: .rounded).weight(isSelected ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isSelected ? Theme.Colors.gold : Theme.Colors.textSecondary.opacity(0.75))
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                        .fill(Theme.Colors.gold.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                                .strokeBorder(Theme.Colors.gold.opacity(0.55), lineWidth: 1)
                        )
                        .matchedGeometryEffect(id: "indicator", in: indicator)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier("tab.\(tab.rawValue)")
    }
}

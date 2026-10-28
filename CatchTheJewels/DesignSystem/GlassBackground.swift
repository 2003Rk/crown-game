import SwiftUI

/// The app's 3D glass surface: frosted blur of whatever is behind, an emerald tint,
/// a glossy top highlight, a darker lower edge for thickness, a light-catching rim
/// and layered shadows. Every card, chip and secondary control uses it so the whole
/// app shares one material.
struct GlassBackground<S: InsettableShape>: View {
    enum Emphasis {
        /// Standard card.
        case regular
        /// Selected or important: brighter gold rim and a warm glow.
        case highlighted
        /// Small chips and capsules: lighter shadow.
        case subtle
    }

    let shape: S
    var emphasis: Emphasis = .regular

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            // Frosted glass.
            shape.fill(.ultraThinMaterial)
            // Emerald tint, deeper toward the bottom-right. Increase Contrast makes
            // the glass more opaque so text stays crisp.
            shape.fill(LinearGradient(
                colors: [Theme.Colors.royalGreen.opacity(contrast == .increased ? 0.75 : 0.42),
                         Theme.Colors.emerald.opacity(contrast == .increased ? 0.85 : 0.6),
                         Theme.Colors.emeraldDeep.opacity(contrast == .increased ? 0.95 : 0.78)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            // Glossy reflection across the top.
            shape.fill(LinearGradient(
                stops: [.init(color: .white.opacity(0.2), location: 0),
                        .init(color: .white.opacity(0.07), location: 0.32),
                        .init(color: .white.opacity(0), location: 0.55)],
                startPoint: .top, endPoint: .bottom))
            // Thickness: the lower edge falls into shade.
            shape.fill(LinearGradient(
                stops: [.init(color: .black.opacity(0), location: 0.6),
                        .init(color: .black.opacity(0.28), location: 1)],
                startPoint: .top, endPoint: .bottom))
            // Light-catching outer rim.
            shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(0.6),
                                        Theme.Colors.gold.opacity(emphasis == .highlighted ? 0.95 : 0.35),
                                        .white.opacity(0.06),
                                        Theme.Colors.gold.opacity(emphasis == .highlighted ? 0.6 : 0.15)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: emphasis == .highlighted ? 1.6 : 1.1)
            // Inner bevel highlight just inside the rim.
            shape.inset(by: 2).strokeBorder(
                LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0)], startPoint: .top, endPoint: .center),
                lineWidth: 1)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(emphasis == .subtle ? 0.3 : 0.45),
                radius: emphasis == .subtle ? 6 : 16, x: 0, y: emphasis == .subtle ? 4 : 10)
        .shadow(color: emphasis == .highlighted ? Theme.Colors.gold.opacity(0.28) : Theme.Colors.royalGreen.opacity(0.18),
                radius: emphasis == .highlighted ? 14 : 8)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Places a 3D glass surface behind the view.
    func glassBackground<S: InsettableShape>(_ shape: S, emphasis: GlassBackground<S>.Emphasis = .regular) -> some View {
        background(GlassBackground(shape: shape, emphasis: emphasis))
    }

    /// Glass rounded-rectangle background with the standard card radius.
    func glassCard(cornerRadius: CGFloat = Theme.Radius.medium, highlighted: Bool = false) -> some View {
        glassBackground(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                        emphasis: highlighted ? .highlighted : .regular)
    }
}

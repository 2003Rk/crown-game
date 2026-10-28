import CoreGraphics
import Foundation

/// An sRGB color for artwork drawing, independent of UIKit so the same painter can
/// run on macOS (to render the app icon) and on iOS (to render game textures).
struct ArtColor: Equatable {
    var r: CGFloat
    var g: CGFloat
    var b: CGFloat

    init(r: CGFloat, g: CGFloat, b: CGFloat) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(hex: UInt32) {
        r = CGFloat((hex >> 16) & 0xFF) / 255
        g = CGFloat((hex >> 8) & 0xFF) / 255
        b = CGFloat(hex & 0xFF) / 255
    }

    func cg(_ alpha: CGFloat = 1) -> CGColor {
        CGColor(red: r, green: g, blue: b, alpha: alpha)
    }

    func mixed(with other: ArtColor, _ amount: CGFloat) -> ArtColor {
        let t = min(1, max(0, amount))
        return ArtColor(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    func lighter(_ amount: CGFloat) -> ArtColor { mixed(with: .white, amount) }
    func darker(_ amount: CGFloat) -> ArtColor { mixed(with: .black, amount) }

    static let white = ArtColor(r: 1, g: 1, b: 1)
    static let black = ArtColor(r: 0, g: 0, b: 0)
}

/// The game's artwork palette.
enum ArtPalette {
    static let ruby = ArtColor(hex: 0xE9273E)
    static let sapphire = ArtColor(hex: 0x258BFF)
    static let emeraldGem = ArtColor(hex: 0x19C77A)
    static let amethyst = ArtColor(hex: 0x9D4EDD)
    static let gold = ArtColor(hex: 0xF7C94B)
    static let goldGem = ArtColor(hex: 0xFFB81C)
    static let goldDeep = ArtColor(hex: 0xA8761F)
    static let goldLight = ArtColor(hex: 0xFFE7A0)
    static let velvet = ArtColor(hex: 0x7A0F22)
    static let bomb = ArtColor(hex: 0x2B3038)
    static let heart = ArtColor(hex: 0xFF4F7B)
    static let pearl = ArtColor(hex: 0xFFF8E7)
    static let backgroundTop = ArtColor(hex: 0x003B24)
    static let backgroundBottom = ArtColor(hex: 0x002518)
    static let backgroundGlow = ArtColor(hex: 0x087A3C)

    static func color(for kind: JewelKind) -> ArtColor {
        switch kind {
        case .ruby: return ruby
        case .sapphire: return sapphire
        case .emerald: return emeraldGem
        case .amethyst: return amethyst
        case .gold: return goldGem
        }
    }
}

/// Draws all of the game's original artwork with Core Graphics.
///
/// All drawing assumes a top-left origin (y grows downward), which is what
/// `UIGraphicsImageRenderer` provides. Callers on macOS flip the context first.
enum ArtworkPainter {
    private static let colorSpace = CGColorSpaceCreateDeviceRGB()

    // MARK: - Jewels

    /// Unit-space outline (roughly -1...1) for each jewel's distinct silhouette.
    static func outline(for kind: JewelKind) -> [CGPoint] {
        switch kind {
        case .ruby:
            return regularPolygon(sides: 8, radius: 1, startAngle: -.pi / 8 - .pi / 2)
        case .sapphire:
            return [
                CGPoint(x: -0.52, y: -0.66), CGPoint(x: 0.52, y: -0.66), CGPoint(x: 0.98, y: -0.14),
                CGPoint(x: 0, y: 0.98), CGPoint(x: -0.98, y: -0.14),
            ]
        case .emerald:
            return [
                CGPoint(x: -0.42, y: -0.96), CGPoint(x: 0.42, y: -0.96), CGPoint(x: 0.7, y: -0.68),
                CGPoint(x: 0.7, y: 0.68), CGPoint(x: 0.42, y: 0.96), CGPoint(x: -0.42, y: 0.96),
                CGPoint(x: -0.7, y: 0.68), CGPoint(x: -0.7, y: -0.68),
            ]
        case .amethyst:
            return regularPolygon(sides: 6, radius: 1, startAngle: -.pi / 2).map { CGPoint(x: $0.x * 0.94, y: $0.y) }
        case .gold:
            return star(points: 5, outer: 1.05, inner: 0.5, startAngle: -.pi / 2).map { CGPoint(x: $0.x, y: $0.y + 0.08) }
        }
    }

    static func drawJewel(_ kind: JewelKind, in ctx: CGContext, rect: CGRect, glow: Bool = true) {
        let tableScale: CGFloat
        switch kind {
        case .emerald: tableScale = 0.56
        case .gold: tableScale = 0.42
        case .sapphire: tableScale = 0.46
        default: tableScale = 0.5
        }
        drawFacetedGem(outline: outline(for: kind), base: ArtPalette.color(for: kind), tableScale: tableScale, in: ctx, rect: rect, glow: glow)
    }

    static func drawFacetedGem(outline unit: [CGPoint], base: ArtColor, tableScale: CGFloat, in ctx: CGContext, rect: CGRect, glow: Bool) {
        guard unit.count >= 3 else { return }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let scale = min(rect.width, rect.height) / 2 * 0.86
        let points = unit.map { CGPoint(x: center.x + $0.x * scale, y: center.y + $0.y * scale) }
        let tableCenter = CGPoint(x: center.x, y: center.y - scale * 0.06)
        let table = points.map { CGPoint(x: tableCenter.x + ($0.x - center.x) * tableScale, y: tableCenter.y + ($0.y - center.y) * tableScale) }
        let outlinePath = polygonPath(points)
        let lineWidth = max(1, scale * 0.045)

        // Soft colored glow behind the gem.
        if glow {
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: scale * 0.35, color: base.lighter(0.2).cg(0.75))
            ctx.addPath(outlinePath)
            ctx.setFillColor(base.cg())
            ctx.fillPath()
            ctx.restoreGState()
        }

        // Body gradient, lit from the top-left.
        fillLinearGradient(ctx, path: outlinePath,
                           colors: [base.lighter(0.3).cg(), base.cg(), base.darker(0.45).cg()],
                           start: CGPoint(x: center.x - scale, y: center.y - scale),
                           end: CGPoint(x: center.x + scale, y: center.y + scale))

        // Crown facets: shade each facet by how much it faces the light.
        let light = CGVector(dx: -0.6, dy: -0.8)
        for index in points.indices {
            let next = (index + 1) % points.count
            let facet = polygonPath([points[index], points[next], table[next], table[index]])
            let mid = CGPoint(x: (points[index].x + points[next].x) / 2, y: (points[index].y + points[next].y) / 2)
            let nx = mid.x - center.x
            let ny = mid.y - center.y
            let length = max(0.001, (nx * nx + ny * ny).squareRoot())
            let facing = (nx * light.dx + ny * light.dy) / length
            let shade = facing > 0 ? base.lighter(0.5 * facing) : base.darker(0.45 * -facing)
            ctx.addPath(facet)
            ctx.setFillColor(shade.cg(0.62))
            ctx.fillPath()
        }

        // Table (top face).
        let tablePath = polygonPath(table)
        fillLinearGradient(ctx, path: tablePath,
                           colors: [base.lighter(0.55).cg(), base.lighter(0.12).cg()],
                           start: CGPoint(x: tableCenter.x - scale * 0.5, y: tableCenter.y - scale * 0.5),
                           end: CGPoint(x: tableCenter.x + scale * 0.5, y: tableCenter.y + scale * 0.5))

        // Facet edges.
        ctx.setStrokeColor(ArtColor.white.cg(0.38))
        ctx.setLineWidth(lineWidth * 0.45)
        for index in points.indices {
            ctx.move(to: points[index])
            ctx.addLine(to: table[index])
        }
        ctx.strokePath()
        ctx.addPath(tablePath)
        ctx.setStrokeColor(ArtColor.white.cg(0.5))
        ctx.strokePath()

        // Outline.
        ctx.addPath(outlinePath)
        ctx.setStrokeColor(base.darker(0.55).cg())
        ctx.setLineWidth(lineWidth)
        ctx.setLineJoin(.round)
        ctx.strokePath()

        // Glint.
        let glint = CGPoint(x: tableCenter.x - scale * 0.22, y: tableCenter.y - scale * 0.2)
        drawSparkle(in: ctx, center: glint, radius: scale * 0.26, color: .white, alpha: 0.95)
    }

    // MARK: - Hazards and bonuses

    static func drawBomb(in ctx: CGContext, rect: CGRect) {
        let size = min(rect.width, rect.height)
        let radius = size * 0.34
        let center = CGPoint(x: rect.midX - size * 0.02, y: rect.midY + size * 0.08)

        // Red warning halo so the hazard reads instantly against dark backgrounds.
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: size * 0.12, color: ArtColor(hex: 0xFF3B30).cg(0.85))
        ctx.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        ctx.setFillColor(ArtPalette.bomb.cg())
        ctx.fillPath()
        ctx.restoreGState()

        let body = CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2), transform: nil)
        ctx.saveGState()
        ctx.addPath(body)
        ctx.clip()
        if let gradient = CGGradient(colorsSpace: colorSpace,
                                     colors: [ArtColor(hex: 0x6B7385).cg(), ArtPalette.bomb.cg(), ArtColor(hex: 0x0E1014).cg()] as CFArray,
                                     locations: [0, 0.45, 1]) {
            ctx.drawRadialGradient(gradient,
                                   startCenter: CGPoint(x: center.x - radius * 0.35, y: center.y - radius * 0.4), startRadius: 0,
                                   endCenter: center, endRadius: radius * 1.05,
                                   options: [.drawsAfterEndLocation])
        }
        ctx.restoreGState()

        // Warning band with a bold X, so the bomb isn't identified by color alone.
        ctx.saveGState()
        ctx.setStrokeColor(ArtColor(hex: 0xFFD166).cg(0.95))
        ctx.setLineWidth(size * 0.05)
        ctx.setLineCap(.round)
        let arm = radius * 0.32
        ctx.move(to: CGPoint(x: center.x - arm, y: center.y - arm))
        ctx.addLine(to: CGPoint(x: center.x + arm, y: center.y + arm))
        ctx.move(to: CGPoint(x: center.x + arm, y: center.y - arm))
        ctx.addLine(to: CGPoint(x: center.x - arm, y: center.y + arm))
        ctx.strokePath()
        ctx.restoreGState()

        // Cap.
        let capCenter = CGPoint(x: center.x + radius * 0.55, y: center.y - radius * 0.78)
        ctx.saveGState()
        ctx.translateBy(x: capCenter.x, y: capCenter.y)
        ctx.rotate(by: .pi / 4)
        let capRect = CGRect(x: -size * 0.075, y: -size * 0.05, width: size * 0.15, height: size * 0.1)
        ctx.addPath(CGPath(roundedRect: capRect, cornerWidth: size * 0.02, cornerHeight: size * 0.02, transform: nil))
        ctx.setFillColor(ArtColor(hex: 0x8A93A6).cg())
        ctx.fillPath()
        ctx.restoreGState()

        // Fuse and spark.
        let fuseStart = CGPoint(x: capCenter.x + size * 0.03, y: capCenter.y - size * 0.03)
        let fuseEnd = CGPoint(x: fuseStart.x + size * 0.12, y: fuseStart.y - size * 0.12)
        ctx.setStrokeColor(ArtColor(hex: 0xC9A66B).cg())
        ctx.setLineWidth(size * 0.035)
        ctx.setLineCap(.round)
        ctx.move(to: fuseStart)
        ctx.addQuadCurve(to: fuseEnd, control: CGPoint(x: fuseStart.x + size * 0.1, y: fuseStart.y + size * 0.01))
        ctx.strokePath()
        drawSparkle(in: ctx, center: fuseEnd, radius: size * 0.11, color: ArtColor(hex: 0xFFB020), alpha: 1)
        drawSparkle(in: ctx, center: fuseEnd, radius: size * 0.06, color: .white, alpha: 1)

        // Specular highlight.
        ctx.addEllipse(in: CGRect(x: center.x - radius * 0.62, y: center.y - radius * 0.66, width: radius * 0.42, height: radius * 0.26))
        ctx.setFillColor(ArtColor.white.cg(0.35))
        ctx.fillPath()
    }

    static func heartPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY
        path.move(to: CGPoint(x: x + w * 0.5, y: y + h * 0.92))
        path.addCurve(to: CGPoint(x: x + w * 0.04, y: y + h * 0.36),
                      control1: CGPoint(x: x + w * 0.22, y: y + h * 0.72),
                      control2: CGPoint(x: x + w * 0.02, y: y + h * 0.56))
        path.addCurve(to: CGPoint(x: x + w * 0.5, y: y + h * 0.2),
                      control1: CGPoint(x: x + w * 0.06, y: y + h * 0.06),
                      control2: CGPoint(x: x + w * 0.4, y: y + h * 0.04))
        path.addCurve(to: CGPoint(x: x + w * 0.96, y: y + h * 0.36),
                      control1: CGPoint(x: x + w * 0.6, y: y + h * 0.04),
                      control2: CGPoint(x: x + w * 0.94, y: y + h * 0.06))
        path.addCurve(to: CGPoint(x: x + w * 0.5, y: y + h * 0.92),
                      control1: CGPoint(x: x + w * 0.98, y: y + h * 0.56),
                      control2: CGPoint(x: x + w * 0.78, y: y + h * 0.72))
        path.closeSubpath()
        return path
    }

    static func drawHeart(in ctx: CGContext, rect: CGRect) {
        let inset = rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.1)
        let path = heartPath(in: inset)
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: rect.width * 0.12, color: ArtPalette.heart.cg(0.8))
        ctx.addPath(path)
        ctx.setFillColor(ArtPalette.heart.cg())
        ctx.fillPath()
        ctx.restoreGState()
        fillLinearGradient(ctx, path: path,
                           colors: [ArtPalette.heart.lighter(0.4).cg(), ArtPalette.heart.cg(), ArtPalette.heart.darker(0.4).cg()],
                           start: CGPoint(x: inset.minX, y: inset.minY), end: CGPoint(x: inset.maxX, y: inset.maxY))
        ctx.addPath(path)
        ctx.setStrokeColor(ArtPalette.goldLight.cg())
        ctx.setLineWidth(rect.width * 0.045)
        ctx.strokePath()
        // A small plus marks it as a life, independent of color.
        let c = CGPoint(x: inset.midX, y: inset.minY + inset.height * 0.48)
        let arm = inset.width * 0.13
        ctx.setStrokeColor(ArtColor.white.cg(0.95))
        ctx.setLineWidth(inset.width * 0.09)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: c.x - arm, y: c.y))
        ctx.addLine(to: CGPoint(x: c.x + arm, y: c.y))
        ctx.move(to: CGPoint(x: c.x, y: c.y - arm))
        ctx.addLine(to: CGPoint(x: c.x, y: c.y + arm))
        ctx.strokePath()
    }

    // MARK: - Crown

    /// Draws the royal crown. The catcher variant is used in gameplay; the emblem adds
    /// a glow and a richer jewel setting for branding.
    static func drawCrown(in ctx: CGContext, rect: CGRect, emblem: Bool) {
        let w = rect.width
        let h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * w, y: rect.minY + y * h) }

        if emblem {
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: w * 0.12, color: ArtPalette.gold.cg(0.55))
            ctx.addEllipse(in: CGRect(origin: p(0.1, 0.3), size: CGSize(width: w * 0.8, height: h * 0.55)))
            ctx.setFillColor(ArtPalette.gold.cg(0.25))
            ctx.fillPath()
            ctx.restoreGState()
        }

        // Velvet cap visible between the points.
        fillLinearGradient(ctx, path: CGPath(ellipseIn: CGRect(origin: p(0.1, 0.34), size: CGSize(width: w * 0.8, height: h * 0.34)), transform: nil),
                           colors: [ArtPalette.velvet.lighter(0.25).cg(), ArtPalette.velvet.darker(0.4).cg()],
                           start: p(0.5, 0.34), end: p(0.5, 0.68))

        // Points.
        let body = CGMutablePath()
        body.move(to: p(0.07, 0.64))
        body.addLine(to: p(0.04, 0.18))
        body.addLine(to: p(0.17, 0.46))
        body.addLine(to: p(0.275, 0.25))
        body.addLine(to: p(0.385, 0.46))
        body.addLine(to: p(0.5, 0.07))
        body.addLine(to: p(0.615, 0.46))
        body.addLine(to: p(0.725, 0.25))
        body.addLine(to: p(0.83, 0.46))
        body.addLine(to: p(0.96, 0.18))
        body.addLine(to: p(0.93, 0.64))
        body.closeSubpath()
        fillLinearGradient(ctx, path: body,
                           colors: [ArtPalette.goldLight.cg(), ArtPalette.gold.cg(), ArtPalette.goldDeep.cg()],
                           start: p(0.5, 0.05), end: p(0.5, 0.66))
        ctx.addPath(body)
        ctx.setStrokeColor(ArtPalette.goldDeep.darker(0.25).cg())
        ctx.setLineWidth(max(1, w * 0.014))
        ctx.setLineJoin(.round)
        ctx.strokePath()

        // Inner bevel lines on the points.
        ctx.setStrokeColor(ArtPalette.goldLight.cg(0.7))
        ctx.setLineWidth(max(0.5, w * 0.006))
        for (topX, topY, bottomX) in [(0.05, 0.25, 0.072), (0.275, 0.31, 0.275), (0.5, 0.13, 0.5), (0.725, 0.31, 0.725), (0.95, 0.25, 0.928)] {
            ctx.move(to: p(topX, topY))
            ctx.addLine(to: p(bottomX, 0.58))
        }
        ctx.strokePath()

        // Band.
        let bandRect = CGRect(origin: p(0.03, 0.6), size: CGSize(width: w * 0.94, height: h * 0.32))
        let band = CGPath(roundedRect: bandRect, cornerWidth: h * 0.06, cornerHeight: h * 0.06, transform: nil)
        fillLinearGradient(ctx, path: band,
                           colors: [ArtPalette.goldLight.cg(), ArtPalette.gold.cg(), ArtPalette.goldDeep.cg()],
                           start: CGPoint(x: bandRect.midX, y: bandRect.minY), end: CGPoint(x: bandRect.midX, y: bandRect.maxY))
        ctx.addPath(band)
        ctx.setStrokeColor(ArtPalette.goldDeep.darker(0.3).cg())
        ctx.setLineWidth(max(1, w * 0.014))
        ctx.strokePath()
        ctx.setStrokeColor(ArtColor.white.cg(0.55))
        ctx.setLineWidth(max(0.5, w * 0.008))
        ctx.move(to: CGPoint(x: bandRect.minX + w * 0.05, y: bandRect.minY + h * 0.04))
        ctx.addLine(to: CGPoint(x: bandRect.maxX - w * 0.05, y: bandRect.minY + h * 0.04))
        ctx.strokePath()

        // Band jewels.
        let gemSize = h * (emblem ? 0.24 : 0.22)
        let gems: [(CGFloat, JewelKind)] = emblem
            ? [(0.2, .sapphire), (0.5, .ruby), (0.8, .emerald)]
            : [(0.22, .emerald), (0.5, .ruby), (0.78, .emerald)]
        for (x, kind) in gems {
            let c = p(x, 0.76)
            drawJewel(kind, in: ctx, rect: CGRect(x: c.x - gemSize / 2, y: c.y - gemSize / 2, width: gemSize, height: gemSize), glow: false)
        }

        // Pearls on the peaks.
        let pearlRadius = w * (emblem ? 0.035 : 0.04)
        for (peakX, peakY) in [(0.04, 0.18), (0.275, 0.25), (0.5, 0.07), (0.725, 0.25), (0.96, 0.18)] {
            drawPearl(in: ctx, center: p(peakX, peakY), radius: pearlRadius)
        }
    }

    static func drawPearl(in ctx: CGContext, center: CGPoint, radius: CGFloat) {
        let pearlRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        ctx.saveGState()
        ctx.addEllipse(in: pearlRect)
        ctx.clip()
        if let gradient = CGGradient(colorsSpace: colorSpace,
                                     colors: [ArtColor.white.cg(), ArtPalette.pearl.cg(), ArtPalette.pearl.darker(0.3).cg()] as CFArray,
                                     locations: [0, 0.5, 1]) {
            ctx.drawRadialGradient(gradient,
                                   startCenter: CGPoint(x: center.x - radius * 0.35, y: center.y - radius * 0.35), startRadius: 0,
                                   endCenter: center, endRadius: radius,
                                   options: [.drawsAfterEndLocation])
        }
        ctx.restoreGState()
        ctx.addEllipse(in: pearlRect)
        ctx.setStrokeColor(ArtPalette.goldDeep.cg())
        ctx.setLineWidth(max(0.5, radius * 0.18))
        ctx.strokePath()
    }

    // MARK: - Backgrounds and particles

    /// Deep emerald vertical gradient with a soft central glow and a faint lattice.
    static func drawPlayfieldBackground(in ctx: CGContext, rect: CGRect, lattice: Bool = true) {
        if let gradient = CGGradient(colorsSpace: colorSpace,
                                     colors: [ArtPalette.backgroundTop.cg(), ArtPalette.backgroundBottom.cg()] as CFArray,
                                     locations: [0, 1]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
        }
        if let glow = CGGradient(colorsSpace: colorSpace,
                                 colors: [ArtPalette.backgroundGlow.cg(0.55), ArtPalette.backgroundGlow.cg(0)] as CFArray,
                                 locations: [0, 1]) {
            let center = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.35)
            ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center,
                                   endRadius: max(rect.width, rect.height) * 0.6, options: [])
        }
        guard lattice else { return }
        let spacing = max(rect.width, rect.height) / 14
        ctx.setStrokeColor(ArtPalette.gold.cg(0.05))
        ctx.setLineWidth(max(1, spacing * 0.02))
        var offset = -rect.height
        while offset < rect.width + rect.height {
            ctx.move(to: CGPoint(x: rect.minX + offset, y: rect.minY))
            ctx.addLine(to: CGPoint(x: rect.minX + offset + rect.height, y: rect.maxY))
            ctx.move(to: CGPoint(x: rect.minX + offset + rect.height, y: rect.minY))
            ctx.addLine(to: CGPoint(x: rect.minX + offset, y: rect.maxY))
            offset += spacing
        }
        ctx.strokePath()
    }

    /// Soft round particle used by emitters.
    static func drawSpark(in ctx: CGContext, rect: CGRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        if let gradient = CGGradient(colorsSpace: colorSpace,
                                     colors: [ArtColor.white.cg(), ArtColor.white.cg(0.6), ArtColor.white.cg(0)] as CFArray,
                                     locations: [0, 0.35, 1]) {
            ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center,
                                   endRadius: min(rect.width, rect.height) / 2, options: [])
        }
    }

    /// Four-pointed twinkle.
    static func drawSparkle(in ctx: CGContext, center: CGPoint, radius: CGFloat, color: ArtColor, alpha: CGFloat) {
        let path = CGMutablePath()
        let pinch = radius * 0.22
        path.move(to: CGPoint(x: center.x, y: center.y - radius))
        path.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y), control: CGPoint(x: center.x + pinch, y: center.y - pinch))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + radius), control: CGPoint(x: center.x + pinch, y: center.y + pinch))
        path.addQuadCurve(to: CGPoint(x: center.x - radius, y: center.y), control: CGPoint(x: center.x - pinch, y: center.y + pinch))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius), control: CGPoint(x: center.x - pinch, y: center.y - pinch))
        path.closeSubpath()
        ctx.addPath(path)
        ctx.setFillColor(color.cg(alpha))
        ctx.fillPath()
    }

    // MARK: - App icon

    static func drawAppIcon(in ctx: CGContext, rect: CGRect) {
        drawPlayfieldBackground(in: ctx, rect: rect, lattice: false)
        let size = rect.width

        // Subtle gold rays.
        let rayCenter = CGPoint(x: rect.midX, y: rect.minY + size * 0.62)
        ctx.saveGState()
        for index in 0..<16 {
            let angle = CGFloat(index) / 16 * .pi * 2
            let ray = CGMutablePath()
            ray.move(to: rayCenter)
            ray.addLine(to: CGPoint(x: rayCenter.x + cos(angle - 0.06) * size, y: rayCenter.y + sin(angle - 0.06) * size))
            ray.addLine(to: CGPoint(x: rayCenter.x + cos(angle + 0.06) * size, y: rayCenter.y + sin(angle + 0.06) * size))
            ray.closeSubpath()
            ctx.addPath(ray)
        }
        ctx.setFillColor(ArtPalette.gold.cg(0.06))
        ctx.fillPath()
        ctx.restoreGState()

        // Falling jewels with motion trails.
        let jewels: [(JewelKind, CGFloat, CGFloat, CGFloat)] = [
            (.ruby, 0.24, 0.2, 0.17),
            (.gold, 0.5, 0.13, 0.15),
            (.sapphire, 0.77, 0.22, 0.16),
        ]
        for (kind, x, y, s) in jewels {
            let c = CGPoint(x: rect.minX + x * size, y: rect.minY + y * size)
            let trail = CGMutablePath()
            trail.move(to: CGPoint(x: c.x - s * size * 0.18, y: c.y - s * size * 0.2))
            trail.addLine(to: CGPoint(x: c.x + s * size * 0.18, y: c.y - s * size * 0.2))
            trail.addLine(to: CGPoint(x: c.x, y: c.y - s * size * 1.1))
            trail.closeSubpath()
            fillLinearGradient(ctx, path: trail,
                               colors: [ArtPalette.color(for: kind).lighter(0.4).cg(0.5), ArtPalette.color(for: kind).cg(0)],
                               start: c, end: CGPoint(x: c.x, y: c.y - s * size * 1.1))
            drawJewel(kind, in: ctx, rect: CGRect(x: c.x - s * size / 2, y: c.y - s * size / 2, width: s * size, height: s * size))
        }

        let crownWidth = size * 0.7
        let crownHeight = crownWidth * 0.72
        drawCrown(in: ctx, rect: CGRect(x: rect.midX - crownWidth / 2, y: rect.minY + size * 0.36, width: crownWidth, height: crownHeight), emblem: true)
    }

    // MARK: - Geometry helpers

    static func regularPolygon(sides: Int, radius: CGFloat, startAngle: CGFloat) -> [CGPoint] {
        (0..<sides).map { index in
            let angle = startAngle + CGFloat(index) / CGFloat(sides) * .pi * 2
            return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        }
    }

    static func star(points: Int, outer: CGFloat, inner: CGFloat, startAngle: CGFloat) -> [CGPoint] {
        (0..<(points * 2)).map { index in
            let angle = startAngle + CGFloat(index) / CGFloat(points * 2) * .pi * 2
            let radius = index.isMultiple(of: 2) ? outer : inner
            return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        }
    }

    static func polygonPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points)
        path.closeSubpath()
        return path
    }

    static func fillLinearGradient(_ ctx: CGContext, path: CGPath, colors: [CGColor], start: CGPoint, end: CGPoint) {
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil) else { return }
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }
}

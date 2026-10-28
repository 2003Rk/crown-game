import SwiftUI
import UIKit

/// The pieces of artwork the app renders at runtime.
enum ArtworkKind: Hashable {
    case jewel(JewelKind)
    case bomb
    case heart
    case catcher
    case crownEmblem
    case spark

    init(_ object: FallingObjectKind) {
        switch object {
        case .jewel(let kind): self = .jewel(kind)
        case .bomb: self = .bomb
        case .heart: self = .heart
        }
    }

    /// Width / height of the artwork's natural frame.
    var aspectRatio: CGFloat {
        switch self {
        case .catcher, .crownEmblem: return 1.45
        default: return 1
        }
    }
}

/// Renders `ArtworkPainter` drawings into cached `UIImage`s, shared by SwiftUI views
/// and SpriteKit textures.
@MainActor
enum ArtworkRenderer {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(_ kind: ArtworkKind, height: CGFloat) -> UIImage {
        let size = CGSize(width: (height * kind.aspectRatio).rounded(.up), height: height.rounded(.up))
        let key = "\(kind)-\(Int(size.width))x\(Int(size.height))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            draw(kind, in: context.cgContext, rect: CGRect(origin: .zero, size: size))
        }
        cache.setObject(image, forKey: key)
        return image
    }

    static func backgroundImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = true
        // The background is soft; rendering at 1x keeps texture memory low on large iPads.
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            ArtworkPainter.drawPlayfieldBackground(in: context.cgContext, rect: CGRect(origin: .zero, size: size))
        }
    }

    private static func draw(_ kind: ArtworkKind, in ctx: CGContext, rect: CGRect) {
        switch kind {
        case .jewel(let jewel): ArtworkPainter.drawJewel(jewel, in: ctx, rect: rect)
        case .bomb: ArtworkPainter.drawBomb(in: ctx, rect: rect)
        case .heart: ArtworkPainter.drawHeart(in: ctx, rect: rect)
        case .catcher: ArtworkPainter.drawCrown(in: ctx, rect: rect, emblem: false)
        case .crownEmblem: ArtworkPainter.drawCrown(in: ctx, rect: rect, emblem: true)
        case .spark: ArtworkPainter.drawSpark(in: ctx, rect: rect)
        }
    }
}

/// SwiftUI wrapper for runtime artwork.
struct ArtworkView: View {
    let kind: ArtworkKind
    var height: CGFloat

    var body: some View {
        Image(uiImage: ArtworkRenderer.image(kind, height: height))
            .resizable()
            .interpolation(.high)
            .frame(width: height * kind.aspectRatio, height: height)
            .accessibilityHidden(true)
    }
}

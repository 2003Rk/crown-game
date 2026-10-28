import SpriteKit
import UIKit

/// Caches SpriteKit textures generated from the shared artwork painter.
@MainActor
final class TextureCache {
    private var textures: [String: SKTexture] = [:]

    func texture(_ kind: ArtworkKind, height: CGFloat) -> SKTexture {
        let key = "\(kind)-\(Int(height.rounded()))"
        if let texture = textures[key] { return texture }
        let texture = SKTexture(image: ArtworkRenderer.image(kind, height: height))
        texture.filteringMode = .linear
        textures[key] = texture
        return texture
    }

    func removeAll() {
        textures.removeAll()
    }
}

/// One falling jewel, bomb or heart.
final class FallingItemNode: SKSpriteNode {
    /// The drawn artwork fills ~86% of its frame; scale the sprite so the visible
    /// object matches the collision radius.
    static let artworkFill: CGFloat = 0.86

    let kind: FallingObjectKind
    let radius: CGFloat
    let speedMultiplier: Double
    let spin: CGFloat

    init(kind: FallingObjectKind, radius: CGFloat, texture: SKTexture, speedMultiplier: Double, spin: CGFloat) {
        self.kind = kind
        self.radius = radius
        self.speedMultiplier = speedMultiplier
        self.spin = spin
        let side = radius * 2 / Self.artworkFill
        super.init(texture: texture, color: .clear, size: CGSize(width: side, height: side))
        name = "item"
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }
}

/// The player's crown catcher.
final class CatcherNode: SKNode {
    private let sprite = SKSpriteNode()
    private let glow = SKSpriteNode()
    private(set) var size: CGSize = .zero

    override init() {
        super.init()
        name = "catcher"
        glow.alpha = 0.55
        glow.color = UIColor(red: 0.95, green: 0.76, blue: 0.31, alpha: 1)
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        addChild(glow)
        addChild(sprite)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    func configure(width: CGFloat, textures: TextureCache) {
        let height = width / ArtworkKind.catcher.aspectRatio
        size = CGSize(width: width, height: height)
        sprite.texture = textures.texture(.catcher, height: height)
        sprite.size = size
        glow.texture = textures.texture(.spark, height: 64)
        glow.size = CGSize(width: width * 1.3, height: height * 0.7)
        glow.position = CGPoint(x: 0, y: -height * 0.3)
    }

    /// The area at the top of the crown where objects are caught (scene coordinates).
    var catchZone: CGRect {
        CGRect(x: position.x - size.width * 0.44,
               y: position.y - size.height * 0.05,
               width: size.width * 0.88,
               height: size.height * 0.5)
    }

    func celebrate(reduceMotion: Bool) {
        guard !reduceMotion else { return }
        sprite.removeAction(forKey: "bounce")
        let up = SKAction.scale(to: 1.08, duration: 0.07)
        let down = SKAction.scale(to: 1, duration: 0.12)
        up.timingMode = .easeOut
        down.timingMode = .easeIn
        sprite.run(.sequence([up, down]), withKey: "bounce")
    }

    /// Flashes while the post-hit protection window is active.
    func showHit(duration: TimeInterval, reduceMotion: Bool) {
        sprite.removeAction(forKey: "hit")
        if reduceMotion {
            sprite.color = .red
            sprite.colorBlendFactor = 0.45
            sprite.run(.sequence([.wait(forDuration: duration), .run { [weak sprite] in sprite?.colorBlendFactor = 0 }]), withKey: "hit")
        } else {
            let blink = SKAction.sequence([.fadeAlpha(to: 0.35, duration: 0.1), .fadeAlpha(to: 1, duration: 0.1)])
            let count = max(1, Int(duration / 0.2))
            sprite.run(.sequence([.repeat(blink, count: count), .fadeAlpha(to: 1, duration: 0)]), withKey: "hit")
        }
    }

    func resetAppearance() {
        sprite.removeAllActions()
        sprite.alpha = 1
        sprite.setScale(1)
        sprite.colorBlendFactor = 0
    }
}

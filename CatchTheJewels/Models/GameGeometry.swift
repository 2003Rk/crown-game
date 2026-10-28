import CoreGraphics

/// Pure layout and collision math shared by the scene and the tests.
enum GameGeometry {
    /// Horizontal margin kept between objects and the screen edges.
    static let edgePadding: CGFloat = 6

    /// Converts a lane fraction (0...1) into an x position that keeps the whole
    /// object inside the playfield.
    static func spawnX(fraction: Double, playfieldWidth: CGFloat, objectRadius: CGFloat) -> CGFloat {
        let minX = objectRadius + edgePadding
        let maxX = playfieldWidth - objectRadius - edgePadding
        guard maxX > minX else { return playfieldWidth / 2 }
        let clamped = CGFloat(min(1, max(0, fraction)))
        return minX + (maxX - minX) * clamped
    }

    /// Keeps the catcher fully on screen.
    static func clampCatcherX(_ x: CGFloat, catcherWidth: CGFloat, playfieldWidth: CGFloat) -> CGFloat {
        let half = catcherWidth / 2
        guard playfieldWidth > catcherWidth else { return playfieldWidth / 2 }
        return min(playfieldWidth - half, max(half, x))
    }

    /// Catcher width scales with the screen but stays within comfortable bounds.
    static func catcherWidth(for size: CGSize, enlarged: Bool) -> CGFloat {
        let base = min(150, max(84, min(size.width, size.height) * 0.22))
        return enlarged ? base * 1.3 : base
    }

    static func objectRadius(for size: CGSize) -> CGFloat {
        min(32, max(17, min(size.width, size.height) * 0.043))
    }

    /// True when a circular object overlaps the catcher's catch zone.
    static func intersects(center: CGPoint, radius: CGFloat, zone: CGRect) -> Bool {
        let nearestX = min(max(center.x, zone.minX), zone.maxX)
        let nearestY = min(max(center.y, zone.minY), zone.maxY)
        let dx = center.x - nearestX
        let dy = center.y - nearestY
        return dx * dx + dy * dy <= radius * radius
    }
}

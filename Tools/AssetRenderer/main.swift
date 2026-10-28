// Renders preview images (drawn icon, crown, artwork sheet) from the same Core Graphics
// painter the game uses at runtime. Run via Tools/generate_assets.sh.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write("usage: AssetRenderer <output-directory>\n".data(using: .utf8) ?? Data())
    exit(1)
}
let outputDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func render(width: Int, height: Int, opaque: Bool, to name: String, draw: (CGContext, CGRect) -> Void) throws {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    let alphaInfo: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: colorSpace, bitmapInfo: alphaInfo.rawValue) else {
        throw NSError(domain: "AssetRenderer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create context"])
    }
    // The painter draws with a top-left origin.
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    draw(context, CGRect(x: 0, y: 0, width: width, height: height))

    guard let image = context.makeImage() else {
        throw NSError(domain: "AssetRenderer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot make image"])
    }
    let url = outputDirectory.appendingPathComponent(name)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "AssetRenderer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot write \(name)"])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "AssetRenderer", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cannot finalize \(name)"])
    }
    print("wrote \(name) (\(width)x\(height))")
}

// App icon: opaque 1024 × 1024 as required by App Store Connect.
try render(width: 1024, height: 1024, opaque: true, to: "AppIcon-1024.png") { ctx, rect in
    ArtworkPainter.drawAppIcon(in: ctx, rect: rect)
}

// Launch crown at 1x/2x/3x (base size 180 × 130 pt).
for scale in 1...3 {
    let suffix = scale == 1 ? "" : "@\(scale)x"
    try render(width: 180 * scale, height: 130 * scale, opaque: false, to: "LaunchCrown\(suffix).png") { ctx, rect in
        ArtworkPainter.drawCrown(in: ctx, rect: rect.insetBy(dx: rect.width * 0.02, dy: rect.height * 0.02), emblem: true)
    }
}

// Preview sheet for visual review (not shipped).
try render(width: 1400, height: 360, opaque: true, to: "ArtworkPreview.png") { ctx, rect in
    ArtworkPainter.drawPlayfieldBackground(in: ctx, rect: rect)
    var x: CGFloat = 20
    for kind in JewelKind.allCases {
        ArtworkPainter.drawJewel(kind, in: ctx, rect: CGRect(x: x, y: 40, width: 140, height: 140))
        x += 160
    }
    ArtworkPainter.drawBomb(in: ctx, rect: CGRect(x: x, y: 40, width: 140, height: 140))
    x += 160
    ArtworkPainter.drawHeart(in: ctx, rect: CGRect(x: x, y: 40, width: 140, height: 140))
    ArtworkPainter.drawCrown(in: ctx, rect: CGRect(x: 20, y: 200, width: 210, height: 140), emblem: false)
    ArtworkPainter.drawCrown(in: ctx, rect: CGRect(x: 300, y: 200, width: 210, height: 140), emblem: true)
}

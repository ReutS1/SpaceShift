import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let variants: [(name: String, points: Int, scale: Int)] = [
    ("icon_16x16.png", 16, 1),
    ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1),
    ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1),
    ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1),
    ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1),
    ("icon_512x512@2x.png", 512, 2)
]

for variant in variants {
    let pixels = variant.points * variant.scale
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext else { continue }

    let s = CGFloat(pixels)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let tile = CGRect(x: s * 0.06, y: s * 0.06, width: s * 0.88, height: s * 0.88)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: s * 0.22, cornerHeight: s * 0.22, transform: nil)
    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    let colors = [
        NSColor(calibratedRed: 0.39, green: 0.31, blue: 1.0, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.08, green: 0.55, blue: 1.0, alpha: 1).cgColor
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: s * 0.18, y: s * 0.9), end: CGPoint(x: s * 0.86, y: s * 0.12), options: [])
    context.restoreGState()

    context.setShadow(offset: CGSize(width: 0, height: -s * 0.018), blur: s * 0.045, color: NSColor.black.withAlphaComponent(0.22).cgColor)
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.96).cgColor)
    context.setLineWidth(s * 0.065)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    let left = CGRect(x: s * 0.20, y: s * 0.29, width: s * 0.37, height: s * 0.43)
    let right = CGRect(x: s * 0.43, y: s * 0.29, width: s * 0.37, height: s * 0.43)
    context.addPath(CGPath(roundedRect: left, cornerWidth: s * 0.055, cornerHeight: s * 0.055, transform: nil))
    context.strokePath()
    context.addPath(CGPath(roundedRect: right, cornerWidth: s * 0.055, cornerHeight: s * 0.055, transform: nil))
    context.strokePath()

    context.setShadow(offset: .zero, blur: 0)
    context.setStrokeColor(NSColor.white.cgColor)
    context.setLineWidth(s * 0.07)
    context.move(to: CGPoint(x: s * 0.43, y: s * 0.50))
    context.addLine(to: CGPoint(x: s * 0.59, y: s * 0.50))
    context.move(to: CGPoint(x: s * 0.54, y: s * 0.56))
    context.addLine(to: CGPoint(x: s * 0.60, y: s * 0.50))
    context.addLine(to: CGPoint(x: s * 0.54, y: s * 0.44))
    context.strokePath()

    if let png = bitmap.representation(using: .png, properties: [:]) {
        try png.write(to: outputURL.appendingPathComponent(variant.name))
    }
}

if CommandLine.arguments.count > 2 {
    let chunks: [(String, String)] = [
        ("icp4", "icon_16x16.png"),
        ("icp5", "icon_32x32.png"),
        ("icp6", "icon_32x32@2x.png"),
        ("ic07", "icon_128x128.png"),
        ("ic08", "icon_256x256.png"),
        ("ic09", "icon_512x512.png"),
        ("ic10", "icon_512x512@2x.png")
    ]

    func bigEndianData(_ value: UInt32) -> Data {
        var bigEndian = value.bigEndian
        return Data(bytes: &bigEndian, count: MemoryLayout<UInt32>.size)
    }

    var body = Data()
    for (type, file) in chunks {
        let png = try Data(contentsOf: outputURL.appendingPathComponent(file))
        body.append(type.data(using: .ascii)!)
        body.append(bigEndianData(UInt32(png.count + 8)))
        body.append(png)
    }

    var icon = Data("icns".utf8)
    icon.append(bigEndianData(UInt32(body.count + 8)))
    icon.append(body)
    try icon.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
}

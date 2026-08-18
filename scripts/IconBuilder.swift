// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import Foundation

guard CommandLine.arguments.count >= 3 else {
    fputs("Usage: swift IconBuilder.swift <master.png> <iconset-dir> [output.icns]\n", stderr)
    exit(2)
}

let masterURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)

guard let source = NSImage(contentsOf: masterURL) else {
    fputs("Could not load master icon: \(masterURL.path)\n", stderr)
    exit(1)
}

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
    ) else { continue }

    bitmap.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        NSGraphicsContext.restoreGraphicsState()
        continue
    }
    NSGraphicsContext.current = graphicsContext
    graphicsContext.imageInterpolation = .high
    source.draw(
        in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
        from: NSRect(origin: .zero, size: source.size),
        operation: .copy,
        fraction: 1
    )
    graphicsContext.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    if let png = bitmap.representation(using: .png, properties: [:]) {
        try png.write(to: outputURL.appendingPathComponent(variant.name))
    }
}

if CommandLine.arguments.count > 3 {
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
    try icon.write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
}

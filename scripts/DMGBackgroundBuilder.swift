import AppKit
import Foundation

guard CommandLine.arguments.count == 3,
      let source = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
    fputs("Usage: DMGBackgroundBuilder input.png output.png\n", stderr)
    exit(1)
}

// Finder displays the 800 x 400 window at 2x on Retina screens. Keeping the
// artwork at 1600 x 800 mirrors production DMGs such as LuLu and prevents
// Tahoe from dropping a low-resolution background alias.
let canvasSize = NSSize(width: 1600, height: 800)
let image = NSImage(size: canvasSize)
image.lockFocus()

let sourceRatio = source.size.width / source.size.height
let canvasRatio = canvasSize.width / canvasSize.height
let crop: NSRect
if sourceRatio > canvasRatio {
    let width = source.size.height * canvasRatio
    crop = NSRect(x: (source.size.width - width) / 2, y: 0, width: width, height: source.size.height)
} else {
    let height = source.size.width / canvasRatio
    crop = NSRect(x: 0, y: (source.size.height - height) / 2, width: source.size.width, height: height)
}
source.draw(in: NSRect(origin: .zero, size: canvasSize), from: crop, operation: .copy, fraction: 1)

let title = "SpaceShift"
title.draw(
    in: NSRect(x: 76, y: 652, width: 700, height: 72),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 54, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.16, green: 0.32, blue: 0.78, alpha: 0.94)
    ]
)

"Drag to Applications".draw(
    in: NSRect(x: 80, y: 606, width: 700, height: 42),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 25, weight: .medium),
        .foregroundColor: NSColor(calibratedWhite: 0.24, alpha: 0.72)
    ]
)

let path = NSBezierPath()
path.lineWidth = 18
path.lineCapStyle = .round
path.lineJoinStyle = .round
path.move(to: NSPoint(x: 690, y: 385))
path.line(to: NSPoint(x: 910, y: 385))
path.move(to: NSPoint(x: 855, y: 440))
path.line(to: NSPoint(x: 914, y: 385))
path.line(to: NSPoint(x: 855, y: 330))
NSGraphicsContext.current?.cgContext.setShadow(
    offset: CGSize(width: 0, height: -6),
    blur: 14,
    color: NSColor(calibratedRed: 0.16, green: 0.36, blue: 0.92, alpha: 0.22).cgColor
)
NSColor(calibratedRed: 0.20, green: 0.43, blue: 0.96, alpha: 0.88).setStroke()
path.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      ({ bitmap.size = NSSize(width: 800, height: 400); return true })(),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    exit(2)
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))

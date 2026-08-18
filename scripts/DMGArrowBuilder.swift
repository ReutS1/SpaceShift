import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else { exit(1) }

let size = NSSize(width: 512, height: 512)
let image = NSImage(size: size)
image.lockFocus()
NSColor.clear.setFill()
NSRect(origin: .zero, size: size).fill()

let path = NSBezierPath()
path.lineWidth = 42
path.lineCapStyle = .round
path.lineJoinStyle = .round
path.move(to: NSPoint(x: 90, y: 256))
path.line(to: NSPoint(x: 405, y: 256))
path.move(to: NSPoint(x: 315, y: 346))
path.line(to: NSPoint(x: 410, y: 256))
path.line(to: NSPoint(x: 315, y: 166))

NSGraphicsContext.current?.cgContext.setShadow(
    offset: CGSize(width: 0, height: -8),
    blur: 18,
    color: NSColor(calibratedRed: 0.18, green: 0.36, blue: 0.90, alpha: 0.25).cgColor
)
NSColor(calibratedRed: 0.18, green: 0.43, blue: 0.98, alpha: 1).setStroke()
path.stroke()
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { exit(2) }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))

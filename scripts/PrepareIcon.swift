// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: swift PrepareIcon.swift <input.png> <output.png>\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let size = 1024

guard let source = NSImage(contentsOf: inputURL),
      let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
      ),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Could not prepare icon bitmap\n", stderr)
    exit(1)
}

bitmap.size = NSSize(width: size, height: size)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()
source.draw(
    in: NSRect(x: 0, y: 0, width: size, height: size),
    from: NSRect(origin: .zero, size: source.size),
    operation: .copy,
    fraction: 1
)
context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let pixels = bitmap.bitmapData else {
    fputs("Could not access icon pixels\n", stderr)
    exit(1)
}

let bytesPerRow = bitmap.bytesPerRow
let pixelCount = size * size
var visited = [UInt8](repeating: 0, count: pixelCount)
var queue = [Int]()
queue.reserveCapacity(pixelCount / 3)

func isBackgroundCandidate(_ index: Int) -> Bool {
    let y = index / size
    let x = index - y * size
    let offset = y * bytesPerRow + x * 4
    return min(pixels[offset], pixels[offset + 1], pixels[offset + 2]) >= 160
}

func enqueue(_ index: Int) {
    guard visited[index] == 0, isBackgroundCandidate(index) else { return }
    visited[index] = 1
    queue.append(index)
}

for x in 0..<size {
    enqueue(x)
    enqueue((size - 1) * size + x)
}
for y in 0..<size {
    enqueue(y * size)
    enqueue(y * size + size - 1)
}

var head = 0
while head < queue.count {
    let index = queue[head]
    head += 1
    let y = index / size
    let x = index - y * size
    if x > 0 { enqueue(index - 1) }
    if x + 1 < size { enqueue(index + 1) }
    if y > 0 { enqueue(index - size) }
    if y + 1 < size { enqueue(index + size) }
}

for index in queue {
    let y = index / size
    let x = index - y * size
    let offset = y * bytesPerRow + x * 4
    let red = Int(pixels[offset])
    let green = Int(pixels[offset + 1])
    let blue = Int(pixels[offset + 2])
    let lightnessDelta = max(255 - red, 255 - green, 255 - blue)
    let chroma = max(red, green, blue) - min(red, green, blue)
    let alpha = chroma < 16 ? lightnessDelta : max(lightnessDelta, min(255, chroma * 2))

    if alpha <= 3 {
        pixels[offset] = 0
        pixels[offset + 1] = 0
        pixels[offset + 2] = 0
        pixels[offset + 3] = 0
        continue
    }

    if chroma < 16 {
        pixels[offset] = 0
        pixels[offset + 1] = 0
        pixels[offset + 2] = 0
    }
    pixels[offset + 3] = UInt8(alpha)
}

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Could not encode prepared icon\n", stderr)
    exit(1)
}
try png.write(to: outputURL)

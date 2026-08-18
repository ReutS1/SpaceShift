// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import CoreImage.CIFilterBuiltins
import SwiftUI

struct DonationView: View {
    private let address = "TWpfp2XnWN2ESwFbSZnqBb9yT4mpU9P95m"
    @State private var copied = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 6) {
                Text("Buy me a coffee ☕️")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Just in case you want to — I’d really appreciate it.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
            }

            QRCodeView(value: address)
                .frame(width: 148, height: 148)

            VStack(spacing: 8) {
                Text("USDT · TRC20")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(address)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(1)
            }

            Button(copied ? "Copied ✓" : "Copy wallet address") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(address, forType: .string)
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    copied = false
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(28)
    }
}

private struct QRCodeView: View {
    let value: String

    var body: some View {
        if let image = makeImage() {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .aspectRatio(1, contentMode: .fit)
        }
    }

    private func makeImage() -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let representation = NSCIImageRep(ciImage: transformed)
        let image = NSImage(size: representation.size)
        image.addRepresentation(representation)
        return image
    }
}

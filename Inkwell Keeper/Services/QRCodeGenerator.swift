//
//  QRCodeGenerator.swift
//  Inkwell Keeper
//
//  Generates branded QR codes for share cards using CoreImage. Pure helper — no state.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum QRCodeGenerator {
    private static let context = CIContext()

    /// Renders `string` as a QR code tinted `foreground` on a transparent background so it
    /// reads cleanly on the dark share-card chrome.
    /// - Parameter scale: pixel multiplier applied to the (small) native QR output.
    static func image(
        from string: String,
        foreground: UIColor = .white,
        scale: CGFloat = 12
    ) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let coreImage = filter.outputImage else { return nil }

        // Recolor: QR modules become `foreground`, the quiet zone becomes transparent.
        let colored = coreImage.applyingFilter("CIFalseColor", parameters: [
            "inputColor0": CIColor(color: foreground),
            "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        ])

        let scaled = colored.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

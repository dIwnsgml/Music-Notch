import SwiftUI
import AppKit

extension NSImage {
    var averageColor: Color {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return .green }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rgba = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(data: &rgba, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return .green }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        
        var r = CGFloat(rgba[0]) / 255.0
        var g = CGFloat(rgba[1]) / 255.0
        var b = CGFloat(rgba[2]) / 255.0
        let maxColor = max(r, max(g, b))
        if maxColor < 0.4 {
            let boost = 0.4 - maxColor
            r += boost; g += boost; b += boost
        }
        return Color(red: Double(r), green: Double(g), blue: Double(b))
    }
}

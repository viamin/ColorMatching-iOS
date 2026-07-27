import CoreGraphics
import Foundation
import MeasurementCore

extension LinearImage {
    init?(cgImage: CGImage) {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var bytes = Array(repeating: UInt8(0), count: height * bytesPerRow)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &bytes,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var pixels: [RGB] = []
        pixels.reserveCapacity(width * height)

        for index in stride(from: 0, to: bytes.count, by: bytesPerPixel) {
            pixels.append(
                RGB(
                    r: Sampler.srgbToLinear(Double(bytes[index]) / 255),
                    g: Sampler.srgbToLinear(Double(bytes[index + 1]) / 255),
                    b: Sampler.srgbToLinear(Double(bytes[index + 2]) / 255)
                )
            )
        }

        self.init(width: width, height: height, pixels: pixels)
    }
}

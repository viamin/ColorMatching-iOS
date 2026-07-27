import Foundation

public struct Homography {
    private let h: [Double]

    public init(page: [Point], image: [Point]) {
        precondition(page.count == 4 && image.count == 4)
        h = Homography.solve(from: page, to: image)
    }

    public func map(_ point: Point) -> Point {
        let denominator = h[6] * point.x + h[7] * point.y + 1.0
        return Point(
            x: (h[0] * point.x + h[1] * point.y + h[2]) / denominator,
            y: (h[3] * point.x + h[4] * point.y + h[5]) / denominator
        )
    }

    public func map(_ rect: Rect) -> [Point] {
        rect.corners.map(map)
    }

    private static func solve(from source: [Point], to destination: [Point]) -> [Double] {
        var a = Array(repeating: Array(repeating: 0.0, count: 8), count: 8)
        var b = Array(repeating: 0.0, count: 8)

        for i in 0..<4 {
            let x = source[i].x
            let y = source[i].y
            let u = destination[i].x
            let v = destination[i].y
            let row = i * 2

            a[row] = [x, y, 1, 0, 0, 0, -u * x, -u * y]
            b[row] = u
            a[row + 1] = [0, 0, 0, x, y, 1, -v * x, -v * y]
            b[row + 1] = v
        }

        return gaussianElimination(a: a, b: b)
    }

    private static func gaussianElimination(a inputA: [[Double]], b inputB: [Double]) -> [Double] {
        var a = inputA
        var b = inputB
        let n = b.count

        for pivot in 0..<n {
            var maxRow = pivot
            for row in pivot..<n where abs(a[row][pivot]) > abs(a[maxRow][pivot]) {
                maxRow = row
            }
            a.swapAt(pivot, maxRow)
            b.swapAt(pivot, maxRow)

            let divisor = a[pivot][pivot]
            guard abs(divisor) > 1.0e-12 else { continue }

            for col in pivot..<n {
                a[pivot][col] /= divisor
            }
            b[pivot] /= divisor

            for row in 0..<n where row != pivot {
                let factor = a[row][pivot]
                for col in pivot..<n {
                    a[row][col] -= factor * a[pivot][col]
                }
                b[row] -= factor * b[pivot]
            }
        }

        return b
    }
}

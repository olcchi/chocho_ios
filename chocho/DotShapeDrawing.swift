import SwiftUI
import UIKit

nonisolated enum BuiltInDotShape: String, CaseIterable, Identifiable {
    case circle = "圆形"
    case square = "正方形"
    case triangle = "等边三角形"
    case star = "五角星"

    var id: String { rawValue }
}

extension BuiltInDotShape {
    nonisolated func bezierPath(in rect: CGRect) -> UIBezierPath {
        switch self {
        case .circle:
            return UIBezierPath(ovalIn: rect)
        case .square:
            return UIBezierPath(rect: rect)
        case .triangle:
            return Self.equilateralTrianglePath(in: rect)
        case .star:
            return Self.fivePointStarPath(in: rect)
        }
    }

    nonisolated func swiftUIPath(in rect: CGRect) -> Path {
        Path(bezierPath(in: rect).cgPath)
    }

    private nonisolated static func equilateralTrianglePath(in rect: CGRect) -> UIBezierPath {
        let side = min(rect.width, rect.height * 2 / sqrt(3))
        let height = side * sqrt(3) / 2
        let minX = rect.midX - side / 2
        let minY = rect.midY - height / 2

        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.midX, y: minY))
        path.addLine(to: CGPoint(x: minX + side, y: minY + height))
        path.addLine(to: CGPoint(x: minX, y: minY + height))
        path.close()
        return path
    }

    private nonisolated static func fivePointStarPath(in rect: CGRect) -> UIBezierPath {
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.42
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let path = UIBezierPath()

        for index in 0..<10 {
            let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 5
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.close()
        return path
    }
}

struct DotShapeDrawing: View {
    let shape: BuiltInDotShape
    let color: Color

    var body: some View {
        switch shape {
        case .circle:
            Circle()
                .fill(color)
        case .square:
            Rectangle()
                .fill(color)
        case .triangle:
            EquilateralTriangle()
                .fill(color)
        case .star:
            FivePointStar()
                .fill(color)
        }
    }
}

private struct EquilateralTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height * 2 / sqrt(3))
        let height = side * sqrt(3) / 2
        let minX = rect.midX - side / 2
        let minY = rect.midY - height / 2

        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: minY))
        path.addLine(to: CGPoint(x: minX + side, y: minY + height))
        path.addLine(to: CGPoint(x: minX, y: minY + height))
        path.closeSubpath()
        return path
    }
}

private struct FivePointStar: Shape {
    func path(in rect: CGRect) -> Path {
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.42
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()

        for index in 0..<10 {
            let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 5
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}

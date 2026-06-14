import SwiftUI

nonisolated struct HomeLandingLogoLetter: Equatable, Identifiable {
    let id: Int
    let assetName: String
    let accessibilityLabel: String
    let wavePhaseOffset: Double

    static let chocho: [HomeLandingLogoLetter] = [
        HomeLandingLogoLetter(id: 0, assetName: "home-c", accessibilityLabel: "c", wavePhaseOffset: 0),
        HomeLandingLogoLetter(id: 1, assetName: "home-h", accessibilityLabel: "h", wavePhaseOffset: 0.18),
        HomeLandingLogoLetter(id: 2, assetName: "home-o", accessibilityLabel: "o", wavePhaseOffset: 0.36),
        HomeLandingLogoLetter(id: 3, assetName: "home-c", accessibilityLabel: "c", wavePhaseOffset: 0.54),
        HomeLandingLogoLetter(id: 4, assetName: "home-h", accessibilityLabel: "h", wavePhaseOffset: 0.72),
        HomeLandingLogoLetter(id: 5, assetName: "home-o", accessibilityLabel: "o", wavePhaseOffset: 0.90)
    ]
}

nonisolated struct HomeLandingLogoMotion: Equatable {
    let amplitude: Double
    let period: Double

    func verticalOffset(at time: TimeInterval, phaseOffset: Double) -> Double {
        -sin(((time / period) + phaseOffset) * 2 * .pi) * amplitude
    }
}

nonisolated struct HomeLandingSnowflake: Equatable, Identifiable {
    static let tintHex = "#F4FFE6"
    static let fadePeriod: Double = 6

    let id: Int
    let xFraction: Double
    let yFraction: Double
    let size: Double
    let phaseOffset: Double

    static let scattered: [HomeLandingSnowflake] = [
        HomeLandingSnowflake(id: 0, xFraction: 0.10, yFraction: 0.12, size: 18, phaseOffset: 0.08),
        HomeLandingSnowflake(id: 1, xFraction: 0.30, yFraction: 0.08, size: 16, phaseOffset: 0.64),
        HomeLandingSnowflake(id: 2, xFraction: 0.76, yFraction: 0.11, size: 15, phaseOffset: 0.35),
        HomeLandingSnowflake(id: 3, xFraction: 0.91, yFraction: 0.20, size: 18, phaseOffset: 0.72),
        HomeLandingSnowflake(id: 4, xFraction: 0.16, yFraction: 0.31, size: 20, phaseOffset: 0.42),
        HomeLandingSnowflake(id: 5, xFraction: 0.67, yFraction: 0.29, size: 13, phaseOffset: 0.18),
        HomeLandingSnowflake(id: 6, xFraction: 0.86, yFraction: 0.38, size: 15, phaseOffset: 0.88),
        HomeLandingSnowflake(id: 7, xFraction: 0.07, yFraction: 0.49, size: 14, phaseOffset: 0.58),
        HomeLandingSnowflake(id: 8, xFraction: 0.38, yFraction: 0.43, size: 12, phaseOffset: 0.24),
        HomeLandingSnowflake(id: 9, xFraction: 0.96, yFraction: 0.52, size: 12, phaseOffset: 0.04),
        HomeLandingSnowflake(id: 10, xFraction: 0.20, yFraction: 0.63, size: 17, phaseOffset: 0.78),
        HomeLandingSnowflake(id: 11, xFraction: 0.54, yFraction: 0.58, size: 14, phaseOffset: 0.50),
        HomeLandingSnowflake(id: 12, xFraction: 0.80, yFraction: 0.68, size: 21, phaseOffset: 0.30),
        HomeLandingSnowflake(id: 13, xFraction: 0.12, yFraction: 0.78, size: 13, phaseOffset: 0.96),
        HomeLandingSnowflake(id: 14, xFraction: 0.42, yFraction: 0.82, size: 19, phaseOffset: 0.14),
        HomeLandingSnowflake(id: 15, xFraction: 0.72, yFraction: 0.84, size: 12, phaseOffset: 0.68),
        HomeLandingSnowflake(id: 16, xFraction: 0.91, yFraction: 0.91, size: 16, phaseOffset: 0.46),
        HomeLandingSnowflake(id: 17, xFraction: 0.28, yFraction: 0.94, size: 22, phaseOffset: 0.82)
    ]

    func opacity(at time: TimeInterval, period: Double) -> Double {
        let wave = sin(((time / period) + phaseOffset) * 2 * .pi)
        return max(0, wave)
    }
}

struct HomeLandingView: View {
    let onEnter: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "#24BFE5")
                .ignoresSafeArea()

            HomeLandingSnowfield()

            HomeLandingLogo()
                .padding(.horizontal, 26)

            VStack {
                Spacer()

                Button(action: onEnter) {
                    Text("进入chocho")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primaryForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.primary, in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("进入首页")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
    }
}

private struct HomeLandingSnowfield: View {
    private let snowflakes = HomeLandingSnowflake.scattered
    private let period = HomeLandingSnowflake.fadePeriod

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    for snowflake in snowflakes {
                        let opacity = snowflake.opacity(
                            at: timeline.date.timeIntervalSinceReferenceDate,
                            period: period
                        )
                        guard opacity > 0.02 else { continue }

                        let center = CGPoint(
                            x: size.width * snowflake.xFraction,
                            y: size.height * snowflake.yFraction
                        )
                        let path = snowflakePath(center: center, diameter: snowflake.size)
                        context.stroke(
                            path,
                            with: .color(Color(hex: HomeLandingSnowflake.tintHex).opacity(opacity)),
                            style: StrokeStyle(
                                lineWidth: max(1.4, snowflake.size / 9),
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func snowflakePath(center: CGPoint, diameter: Double) -> Path {
        let radius = diameter / 2
        let diagonal = radius * 0.72

        var path = Path()
        path.move(to: CGPoint(x: center.x - radius, y: center.y))
        path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        path.move(to: CGPoint(x: center.x, y: center.y - radius))
        path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        path.move(to: CGPoint(x: center.x - diagonal, y: center.y - diagonal))
        path.addLine(to: CGPoint(x: center.x + diagonal, y: center.y + diagonal))
        path.move(to: CGPoint(x: center.x - diagonal, y: center.y + diagonal))
        path.addLine(to: CGPoint(x: center.x + diagonal, y: center.y - diagonal))
        return path
    }
}

private struct HomeLandingLogo: View {
    private let letters = HomeLandingLogoLetter.chocho
    private let motion = HomeLandingLogoMotion(amplitude: 8, period: 1.35)

    var body: some View {
        TimelineView(.animation) { timeline in
            HStack(alignment: .center, spacing: 12) {
                ForEach(letters) { letter in
                    HomeLandingLogoGlyph(
                        letter: letter,
                        verticalOffset: motion.verticalOffset(
                            at: timeline.date.timeIntervalSinceReferenceDate,
                            phaseOffset: letter.wavePhaseOffset
                        )
                    )
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("chocho")
    }
}

private struct HomeLandingLogoGlyph: View {
    let letter: HomeLandingLogoLetter
    let verticalOffset: Double

    var body: some View {
        Image(letter.assetName)
            .resizable()
            .scaledToFit()
            .frame(height: letter.assetName == "home-h" ? 66 : 49)
            .offset(y: verticalOffset)
            .accessibilityHidden(true)
    }
}

#Preview("Home Landing") {
    HomeLandingView {}
}

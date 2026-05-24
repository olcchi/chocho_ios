import SwiftUI
import UIKit

struct StyledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double?
    var valueText: (Double) -> String = { "\(Int($0.rounded()))" }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.foreground)

            TrackTintedSlider(
                value: steppedValue,
                range: range,
                minimumTrackColor: Color.primary,
                maximumTrackColor: Color.input
            )
            .frame(height: 31)

            Text(valueText(value))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.mutedForeground)
                .frame(width: 48, height: 28)
                .background(Color.input, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var steppedValue: Binding<Double> {
        Binding(
            get: {
                value
            },
            set: { newValue in
                value = normalizedValue(newValue)
            }
        )
    }

    private func normalizedValue(_ newValue: Double) -> Double {
        let steppedValue = if let step, step > 0 {
            (newValue / step).rounded() * step
        } else {
            newValue
        }

        return min(max(steppedValue, range.lowerBound), range.upperBound)
    }
}

private struct TrackTintedSlider: UIViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let minimumTrackColor: Color
    let maximumTrackColor: Color

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.isContinuous = true
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )

        return slider
    }

    func updateUIView(_ slider: UISlider, context: Context) {
        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(range.upperBound)
        slider.value = Float(min(max(value, range.lowerBound), range.upperBound))
        slider.minimumTrackTintColor = UIColor(minimumTrackColor)
        slider.maximumTrackTintColor = UIColor(maximumTrackColor)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    final class Coordinator {
        private var value: Binding<Double>

        init(value: Binding<Double>) {
            self.value = value
        }

        @objc func valueChanged(_ slider: UISlider) {
            value.wrappedValue = Double(slider.value)
        }
    }
}

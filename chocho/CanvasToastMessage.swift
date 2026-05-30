import Foundation
import SwiftUI

struct CanvasToastMessage: Identifiable, Equatable {
    static let defaultDuration: Duration = .seconds(2.2)

    let id: UUID
    let title: String
    let duration: Duration

    init(_ title: String, duration: Duration = Self.defaultDuration, id: UUID = UUID()) {
        self.id = id
        self.title = title
        self.duration = duration
    }
}

struct CanvasToastOverlay: View {
    @Binding var message: CanvasToastMessage?

    var body: some View {
        ZStack {
            if let message {
                CanvasToastView(title: message.title)
                    .id(message.id)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                    .task(id: message.id) {
                        try? await Task.sleep(for: message.duration)
                        guard self.message?.id == message.id else { return }
                        withAnimation(.smooth(duration: 0.18)) {
                            self.message = nil
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 28)
        .allowsHitTesting(false)
        .animation(.smooth(duration: 0.2), value: message?.id)
    }
}

private struct CanvasToastView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.popoverForeground)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(minHeight: 42)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.popover)
                    .shadow(color: Color.black.opacity(0.14), radius: 20, x: 0, y: 8)
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.border, lineWidth: 1)
            }
            .frame(maxWidth: 260)
            .accessibilityAddTraits(.isStaticText)
    }
}

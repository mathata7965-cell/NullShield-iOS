import SwiftUI
import UIKit

struct ZeroRingView: View {
    let isActive: Bool
    let ruleCount: Int
    let presetTitle: String
    let onToggle: () -> Void

    @State private var pulseScale: CGFloat = 0.96
    @State private var ringRotation: Double = 0

    var body: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onToggle()
        } label: {
            ZStack {
                // Outer ambient glow halo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (isActive ? NullTheme.emerald : NullTheme.amber).opacity(0.28),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 120
                        )
                    )
                    .frame(width: 224, height: 224)
                    .scaleEffect(isActive ? pulseScale : 0.92)

                // Dashed tactical radar ring
                Circle()
                    .stroke(
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 7])
                    )
                    .foregroundStyle(
                        (isActive ? NullTheme.cyan : NullTheme.amber).opacity(0.42)
                    )
                    .frame(width: 192, height: 192)
                    .rotationEffect(.degrees(ringRotation))

                // Main sculpted ring
                Circle()
                    .stroke(
                        isActive ? NullTheme.accentGradient : NullTheme.pausedGradient,
                        lineWidth: 6
                    )
                    .frame(width: 162, height: 162)
                    .shadow(
                        color: (isActive ? NullTheme.emerald : NullTheme.amber).opacity(0.45),
                        radius: 16
                    )

                // Dark core disk
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.13, blue: 0.20),
                                Color(red: 0.04, green: 0.06, blue: 0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 146, height: 146)

                // Center Null Ø symbol + text
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(
                                isActive ? NullTheme.accentGradient : NullTheme.pausedGradient,
                                lineWidth: 5
                            )
                            .frame(width: 44, height: 44)

                        Capsule()
                            .fill(Color.white)
                            .frame(width: 5, height: 54)
                            .rotationEffect(.degrees(45))
                    }

                    Text(isActive ? "防護啟動中" : "防護已暫停")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)

                    Text(isActive ? "\(ruleCount) 條活躍規則 · \(presetTitle)" : "點擊立即恢復零噪防禦")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(isActive ? NullTheme.emerald : NullTheme.amber)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
            withAnimation(.linear(duration: 26).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        }
    }
}

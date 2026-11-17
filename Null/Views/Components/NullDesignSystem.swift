import SwiftUI

enum NullTheme {
    static let bgBase = Color(red: 0.027, green: 0.043, blue: 0.071)       // #070B12
    static let bgElevated = Color(red: 0.055, green: 0.086, blue: 0.133)   // #0E1622
    static let emerald = Color(red: 0.0, green: 0.961, blue: 0.627)        // #00F5A0
    static let cyan = Color(red: 0.0, green: 0.831, blue: 1.0)             // #00D4FF
    static let amber = Color(red: 1.0, green: 0.690, blue: 0.125)          // #FFB020
    static let crimson = Color(red: 1.0, green: 0.302, blue: 0.427)        // #FF4D6D
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.68)
    static let textMuted = Color.white.opacity(0.45)

    static let accentGradient = LinearGradient(
        colors: [emerald, cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pausedGradient = LinearGradient(
        colors: [amber, Color.orange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct NullAmbientBackground: View {
    let isActive: Bool

    var body: some View {
        ZStack {
            NullTheme.bgBase.ignoresSafeArea()

            RadialGradient(
                colors: [
                    (isActive ? NullTheme.emerald : NullTheme.amber).opacity(0.16),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: isActive)

            RadialGradient(
                colors: [
                    (isActive ? NullTheme.cyan : Color.orange).opacity(0.11),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 460
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: isActive)
        }
    }
}

struct NullGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 20
    var highlightColor: Color = .white
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.055))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.35))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                highlightColor.opacity(0.22),
                                highlightColor.opacity(0.06),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

struct NullStatusPill: View {
    let text: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(color.opacity(0.14), in: Capsule())
        .overlay(
            Capsule().strokeBorder(color.opacity(0.32), lineWidth: 0.8)
        )
    }
}

struct NullGlyphBadge: View {
    var size: CGFloat = 32
    var isActive: Bool = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(NullTheme.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .strokeBorder(
                            isActive ? NullTheme.accentGradient : NullTheme.pausedGradient,
                            lineWidth: 1.4
                        )
                )

            ZStack {
                Circle()
                    .stroke(
                        isActive ? NullTheme.accentGradient : NullTheme.pausedGradient,
                        lineWidth: max(2.2, size * 0.11)
                    )
                    .frame(width: size * 0.52, height: size * 0.52)

                Capsule()
                    .fill(Color.white)
                    .frame(width: max(2.0, size * 0.10), height: size * 0.68)
                    .rotationEffect(.degrees(45))
            }
        }
        .frame(width: size, height: size)
    }
}

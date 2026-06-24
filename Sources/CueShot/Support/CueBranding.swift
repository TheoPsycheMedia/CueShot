import SwiftUI

struct CueBrandMark: View {
    var size: CGFloat = 38
    var active = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            CueColor.accent.opacity(colorScheme == .dark ? 0.26 : 0.18),
                            CueColor.secondaryAccent.opacity(colorScheme == .dark ? 0.14 : 0.10),
                            Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.025)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                        .strokeBorder(CueColor.accent.opacity(active ? 0.48 : 0.28), lineWidth: 1)
                }

            Circle()
                .strokeBorder(CueColor.accent.opacity(active ? 0.92 : 0.62), lineWidth: max(1.2, size * 0.045))
                .frame(width: size * 0.48, height: size * 0.48)

            RoundedRectangle(cornerRadius: size * 0.045, style: .continuous)
                .fill(CueColor.accent.opacity(active ? 0.95 : 0.72))
                .frame(width: size * 0.58, height: max(1.4, size * 0.045))

            RoundedRectangle(cornerRadius: size * 0.045, style: .continuous)
                .fill(CueColor.accent.opacity(active ? 0.95 : 0.72))
                .frame(width: max(1.4, size * 0.045), height: size * 0.58)

            Circle()
                .fill(CueColor.secondaryAccent.opacity(active ? 0.95 : 0.72))
                .frame(width: size * 0.12, height: size * 0.12)
                .offset(x: size * 0.23, y: -size * 0.23)
        }
        .frame(width: size, height: size)
        .shadow(color: CueColor.accent.opacity(active ? 0.24 : 0.12), radius: active ? 14 : 8, y: active ? 5 : 3)
        .accessibilityHidden(true)
    }
}

struct CueBrandLockup: View {
    var active = false

    var body: some View {
        HStack(spacing: 10) {
            CueBrandMark(size: 34, active: active)
            VStack(alignment: .leading, spacing: 0) {
                Text("CueShot")
                    .font(.headline.weight(.semibold))
                    .tracking(-0.2)
                Text("Capture instrument")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("CueShot, capture instrument")
    }
}

struct CueLensAura: View {
    var active = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .stroke(CueColor.accent.opacity(colorScheme == .dark ? 0.16 : 0.10), lineWidth: 1)
                .frame(width: active ? 340 : 290, height: active ? 340 : 290)
            Circle()
                .stroke(CueColor.secondaryAccent.opacity(colorScheme == .dark ? 0.11 : 0.08), style: StrokeStyle(lineWidth: 1, dash: [7, 10]))
                .frame(width: active ? 245 : 220, height: active ? 245 : 220)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [CueColor.accent.opacity(colorScheme == .dark ? 0.15 : 0.08), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: active ? 210 : 180
                    )
                )
                .frame(width: active ? 420 : 360, height: active ? 420 : 360)
        }
        .animation(MotionSpec.panelMorph, value: active)
        .accessibilityHidden(true)
    }
}

struct CueBrandSheen: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.16 : 0.34),
                Color.white.opacity(0.0),
                CueColor.accent.opacity(colorScheme == .dark ? 0.08 : 0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .blendMode(colorScheme == .dark ? .plusLighter : .normal)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    @ViewBuilder
    func cueLiquidBrandGlass(cornerRadius: CGFloat = 20, interactive: Bool = false) -> some View {
        #if CUESHOT_ENABLE_NATIVE_LIQUID_GLASS
        if #available(macOS 26.0, *) {
            if interactive {
                self.glassEffect(.regular.tint(CueColor.accent.opacity(0.14)).interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                self.glassEffect(.regular.tint(CueColor.accent.opacity(0.12)), in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            cueLiquidBrandFallback(cornerRadius: cornerRadius)
        }
        #else
        cueLiquidBrandFallback(cornerRadius: cornerRadius)
        #endif
    }

    private func cueLiquidBrandFallback(cornerRadius: CGFloat) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(CueColor.accent.opacity(0.055), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                CueBrandSheen()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(CueColor.accent.opacity(0.20), lineWidth: 1)
            }
    }
}

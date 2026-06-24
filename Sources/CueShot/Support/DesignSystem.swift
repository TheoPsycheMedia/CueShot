import SwiftUI

enum CueTheme: String, CaseIterable, Identifiable, Codable {
    case optic
    case aurora
    case moss
    case cinder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .optic: "Optic"
        case .aurora: "Aurora"
        case .moss: "Moss"
        case .cinder: "Cinder"
        }
    }

    var detail: String {
        switch self {
        case .optic: "CueShot green"
        case .aurora: "Codex blue and magenta"
        case .moss: "Field green and gold"
        case .cinder: "Warm red and amber"
        }
    }

    var primary: Color {
        switch self {
        case .optic:
            Color(red: 0.22, green: 0.85, blue: 0.55)
        case .aurora:
            Color(red: 0.25, green: 0.76, blue: 0.91)
        case .moss:
            Color(red: 0.43, green: 0.78, blue: 0.52)
        case .cinder:
            Color(red: 1.0, green: 0.42, blue: 0.35)
        }
    }

    var secondary: Color {
        switch self {
        case .optic:
            Color(red: 0.95, green: 0.93, blue: 0.88)
        case .aurora:
            Color(red: 0.92, green: 0.38, blue: 0.72)
        case .moss:
            Color(red: 0.96, green: 0.75, blue: 0.35)
        case .cinder:
            Color(red: 0.95, green: 0.77, blue: 0.48)
        }
    }

    var glow: Color {
        switch self {
        case .optic:
            Color(red: 0.22, green: 0.85, blue: 0.55)
        case .aurora:
            Color(red: 0.39, green: 0.59, blue: 1.0)
        case .moss:
            Color(red: 0.53, green: 0.86, blue: 0.72)
        case .cinder:
            Color(red: 1.0, green: 0.53, blue: 0.40)
        }
    }

    var surfaceBase: Color {
        switch self {
        case .optic:
            Color(red: 0.07, green: 0.075, blue: 0.08)
        case .aurora:
            Color(red: 0.055, green: 0.065, blue: 0.095)
        case .moss:
            Color(red: 0.055, green: 0.075, blue: 0.060)
        case .cinder:
            Color(red: 0.095, green: 0.058, blue: 0.050)
        }
    }

    var graphite: Color {
        switch self {
        case .optic:
            Color(red: 0.09, green: 0.095, blue: 0.1)
        case .aurora:
            Color(red: 0.075, green: 0.085, blue: 0.125)
        case .moss:
            Color(red: 0.073, green: 0.092, blue: 0.075)
        case .cinder:
            Color(red: 0.12, green: 0.075, blue: 0.062)
        }
    }

    var pearl: Color {
        switch self {
        case .optic:
            Color(red: 0.95, green: 0.93, blue: 0.88)
        case .aurora:
            Color(red: 0.88, green: 0.93, blue: 1.0)
        case .moss:
            Color(red: 0.92, green: 0.95, blue: 0.84)
        case .cinder:
            Color(red: 1.0, green: 0.90, blue: 0.78)
        }
    }

    var backdrop: [Color] {
        switch self {
        case .optic:
            [
                Color(red: 0.08, green: 0.09, blue: 0.10),
                Color(red: 0.16, green: 0.17, blue: 0.16),
                Color(red: 0.10, green: 0.12, blue: 0.12)
            ]
        case .aurora:
            [
                Color(red: 0.055, green: 0.065, blue: 0.10),
                Color(red: 0.10, green: 0.11, blue: 0.17),
                Color(red: 0.07, green: 0.09, blue: 0.14)
            ]
        case .moss:
            [
                Color(red: 0.065, green: 0.078, blue: 0.065),
                Color(red: 0.11, green: 0.13, blue: 0.10),
                Color(red: 0.07, green: 0.10, blue: 0.08)
            ]
        case .cinder:
            [
                Color(red: 0.09, green: 0.06, blue: 0.055),
                Color(red: 0.15, green: 0.10, blue: 0.08),
                Color(red: 0.11, green: 0.075, blue: 0.065)
            ]
        }
    }
}

@MainActor
enum CueColor {
    private static var activeTheme: CueTheme = .optic

    static func use(_ theme: CueTheme) {
        activeTheme = theme
    }

    static var theme: CueTheme { activeTheme }
    static var accent: Color { activeTheme.primary }
    static var reticle: Color { activeTheme.primary }
    static var success: Color { Color(nsColor: .systemGreen) }
    static var warning: Color { Color(nsColor: .systemOrange) }
    static var danger: Color { Color(nsColor: .systemRed) }
    static var secondaryAccent: Color { activeTheme.secondary }
    static var glow: Color { activeTheme.glow }
    static var canvas: Color { Color(nsColor: .windowBackgroundColor) }
    static var surface: Color { Color(nsColor: .controlBackgroundColor) }
    static var surfaceElevated: Color { Color(nsColor: .textBackgroundColor) }
    static var surfaceSelected: Color { activeTheme.primary.opacity(0.12) }
    static var separator: Color { Color(nsColor: .separatorColor) }
    static var primaryText: Color { Color.primary }
    static var secondaryText: Color { Color.secondary }
    static var surfaceBase: Color { Color(nsColor: .controlBackgroundColor) }
    static var pearl: Color { activeTheme.pearl }
    static var graphite: Color { activeTheme.graphite }
    static var backdrop: [Color] { [Color(nsColor: .windowBackgroundColor), Color(nsColor: .controlBackgroundColor)] }

    static var widgetGradientColors: [Color] {
        [
            activeTheme.primary.opacity(0.22),
            activeTheme.secondary.opacity(0.12),
            Color(nsColor: .controlBackgroundColor).opacity(0.72)
        ]
    }

    static var vividWidgetGradientColors: [Color] {
        [
            activeTheme.primary.opacity(0.36),
            activeTheme.secondary.opacity(0.20),
            activeTheme.glow.opacity(0.12)
        ]
    }
}

enum CueShape {
    static let panelRadius: CGFloat = 22
    static let cardRadius: CGFloat = 14
    static let stageRadius: CGFloat = 16
    static let controlRadius: CGFloat = 12
}

extension View {
    @ViewBuilder
    func cueGlass(cornerRadius: CGFloat = CueShape.cardRadius, interactive: Bool = false) -> some View {
        #if CUESHOT_ENABLE_NATIVE_LIQUID_GLASS
        if #available(macOS 26.0, *) {
            if interactive {
                self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            cueMaterialGlass(cornerRadius: cornerRadius)
        }
        #else
        cueMaterialGlass(cornerRadius: cornerRadius)
        #endif
    }

    @ViewBuilder
    func cueTintedGlass(_ tint: Color, cornerRadius: CGFloat = CueShape.cardRadius, interactive: Bool = false) -> some View {
        #if CUESHOT_ENABLE_NATIVE_LIQUID_GLASS
        if #available(macOS 26.0, *) {
            if interactive {
                self.glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                self.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            cueTintedMaterialGlass(tint, cornerRadius: cornerRadius)
        }
        #else
        cueTintedMaterialGlass(tint, cornerRadius: cornerRadius)
        #endif
    }

    private func cueMaterialGlass(cornerRadius: CGFloat) -> some View {
        self
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(CueColor.separator.opacity(0.45), lineWidth: 1)
            }
    }

    private func cueTintedMaterialGlass(_ tint: Color, cornerRadius: CGFloat) -> some View {
        self
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(tint.opacity(0.34), lineWidth: 1)
            }
    }

    func cueElevatedSurface(cornerRadius: CGFloat = CueShape.cardRadius) -> some View {
        self
            .background(CueColor.surfaceElevated.opacity(0.82), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(CueColor.separator.opacity(0.55), lineWidth: 1)
            }
    }
}

struct CueGlassGroup<Content: View>: View {
    var spacing: CGFloat = 20
    @ViewBuilder var content: () -> Content

    var body: some View {
        #if CUESHOT_ENABLE_NATIVE_LIQUID_GLASS
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
        #else
        content()
        #endif
    }
}

struct CuePremiumBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            CueColor.canvas
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.black.opacity(0.34), CueColor.accent.opacity(0.08), Color.black.opacity(0.18)]
                    : [Color.white.opacity(0.74), CueColor.accent.opacity(0.055), Color.black.opacity(0.025)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [CueColor.accent.opacity(colorScheme == .dark ? 0.22 : 0.12), .clear],
                center: .topLeading,
                startRadius: 24,
                endRadius: 460
            )
            RadialGradient(
                colors: [CueColor.secondaryAccent.opacity(colorScheme == .dark ? 0.12 : 0.08), .clear],
                center: .bottomTrailing,
                startRadius: 80,
                endRadius: 540
            )
        }
        .ignoresSafeArea()
    }
}

struct CueStageBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CueShape.stageRadius, style: .continuous)
                .fill(.regularMaterial)
            RoundedRectangle(cornerRadius: CueShape.stageRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color.white.opacity(0.035), CueColor.accent.opacity(0.045), Color.black.opacity(0.10)]
                            : [Color.white.opacity(0.72), CueColor.accent.opacity(0.045), Color.black.opacity(0.018)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            CuePrecisionGrid()
                .opacity(colorScheme == .dark ? 0.34 : 0.22)
            RoundedRectangle(cornerRadius: CueShape.stageRadius, style: .continuous)
                .strokeBorder(CueColor.separator.opacity(0.58), lineWidth: 1)
        }
    }
}

private struct CuePrecisionGrid: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 34
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(CueColor.separator.opacity(0.55)), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: CueShape.stageRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

extension View {
    func cuePremiumPanel(cornerRadius: CGFloat = CueShape.cardRadius) -> some View {
        self
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(CueColor.accent.opacity(0.18), lineWidth: 1)
                    .blendMode(.plusLighter)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(CueColor.separator.opacity(0.44), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.10), radius: 18, y: 8)
    }

    func cueFloatingHUD(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(CueColor.accent.opacity(0.055), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(CueColor.separator.opacity(0.50), lineWidth: 1)
            }
            .shadow(color: CueColor.accent.opacity(0.12), radius: 22, y: 10)
            .shadow(color: Color.black.opacity(0.18), radius: 18, y: 8)
    }

    func cueThemeWidget(cornerRadius: CGFloat = 16, vivid: Bool = false) -> some View {
        self
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(
                LinearGradient(
                    colors: vivid ? CueColor.vividWidgetGradientColors : CueColor.widgetGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                CueBrandSheen()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .opacity(vivid ? 0.95 : 0.70)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(CueColor.accent.opacity(vivid ? 0.30 : 0.18), lineWidth: 1)
            }
            .shadow(color: CueColor.accent.opacity(vivid ? 0.14 : 0.08), radius: vivid ? 20 : 14, y: vivid ? 8 : 5)
    }
}

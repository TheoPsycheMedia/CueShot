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
    static var reticle: Color { activeTheme.primary }
    static var secondaryAccent: Color { activeTheme.secondary }
    static var glow: Color { activeTheme.glow }
    static var surfaceBase: Color { activeTheme.surfaceBase }
    static var pearl: Color { activeTheme.pearl }
    static var graphite: Color { activeTheme.graphite }
    static var backdrop: [Color] { activeTheme.backdrop }
}

enum CueShape {
    static let panelRadius: CGFloat = 28
    static let cardRadius: CGFloat = 18
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
            .background(CueColor.surfaceBase.opacity(0.72), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)
            }
    }

    private func cueTintedMaterialGlass(_ tint: Color, cornerRadius: CGFloat) -> some View {
        self
            .background(tint.opacity(0.24), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(CueColor.surfaceBase.opacity(0.62), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(tint.opacity(0.35), lineWidth: 1)
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

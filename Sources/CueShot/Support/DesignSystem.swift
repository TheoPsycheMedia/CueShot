import SwiftUI

enum CueColor {
    static let reticle = Color(red: 0.22, green: 0.85, blue: 0.55)
    static let surfaceBase = Color(red: 0.07, green: 0.075, blue: 0.08)
    static let pearl = Color(red: 0.95, green: 0.93, blue: 0.88)
    static let graphite = Color(red: 0.09, green: 0.095, blue: 0.1)
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

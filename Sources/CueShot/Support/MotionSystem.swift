import SwiftUI

enum MotionSpec {
    static let microInteraction = Animation.easeOut(duration: 0.12)
    static let stateChange = Animation.easeInOut(duration: 0.22)
    static let panelMorph = Animation.spring(response: 0.32, dampingFraction: 0.88, blendDuration: 0.06)
    static let targetLock = Animation.spring(response: 0.20, dampingFraction: 0.94, blendDuration: 0.03)
    static let success = Animation.spring(response: 0.36, dampingFraction: 0.80, blendDuration: 0.05)
    static let permissionCompletion = Animation.easeInOut(duration: 0.28)
    static let historyInsertion = Animation.spring(response: 0.30, dampingFraction: 0.90, blendDuration: 0.05)
    static let quietFade = Animation.easeOut(duration: 0.16)

    // Compatibility aliases. Keep these during the redesign so capture services and tests stay stable.
    static let navigationSpring = stateChange
    static let captureSpring = success
    static let quick = quietFade
    static let entrance = stateChange
}

struct MotionElement<Content: View>: View {
    let delay: Double
    @ViewBuilder var content: () -> Content
    @State private var visible = false

    init(delay: Double = 0, @ViewBuilder content: @escaping () -> Content) {
        self.delay = delay
        self.content = content
    }

    var body: some View {
        content()
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.98)
            .offset(y: visible ? 0 : 12)
            .onAppear {
                withAnimation(MotionSpec.entrance.delay(delay)) {
                    visible = true
                }
            }
    }
}

struct PressableMotionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(MotionSpec.microInteraction, value: configuration.isPressed)
    }
}

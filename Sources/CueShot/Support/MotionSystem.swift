import SwiftUI

enum MotionSpec {
    static let navigationSpring = Animation.spring(response: 0.34, dampingFraction: 0.78, blendDuration: 0.08)
    static let captureSpring = Animation.spring(response: 0.28, dampingFraction: 0.82, blendDuration: 0.04)
    static let quick = Animation.easeOut(duration: 0.16)
    static let entrance = Animation.spring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.08)
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
            .scaleEffect(configuration.isPressed ? 0.972 : 1)
            .animation(MotionSpec.quick, value: configuration.isPressed)
    }
}

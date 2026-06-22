import SwiftUI

struct StatusPill: View {
    let state: CaptureState

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(state.label)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .cueTintedGlass(color.opacity(0.18), cornerRadius: 14)
    }

    private var color: Color {
        switch state {
        case .permissionNeeded:
            .orange
        case .failed:
            .red
        case .codexNotFocused:
            .yellow
        default:
            CueColor.reticle
        }
    }
}

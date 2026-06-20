import SwiftUI

struct ModeRail: View {
    @ObservedObject var model: AppModel
    @Namespace private var selectionNamespace

    var body: some View {
        VStack(spacing: 8) {
            ForEach(CaptureMode.allCases) { mode in
                Button {
                    model.selectMode(mode)
                } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            if model.selectedMode == mode {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.white.opacity(0.11))
                                    .matchedGeometryEffect(id: "mode-selection", in: selectionNamespace)
                            }

                            Image(systemName: mode.symbol)
                                .font(.system(size: 18, weight: .regular))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(model.selectedMode == mode ? CueColor.reticle : .secondary)
                        }
                        .frame(width: 46, height: 34)

                        VStack(spacing: 1) {
                            Text(mode.railTitle)
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                            Text(mode.methodTitle)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .foregroundStyle(model.selectedMode == mode ? .primary : .secondary)
                    }
                    .frame(width: 76, height: 72)
                }
                .buttonStyle(PressableMotionStyle())
                .cueGlass(cornerRadius: 16, interactive: true)
                .help(mode.helpText)
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .cueGlass(cornerRadius: 22)
    }
}

import SwiftUI

struct CaptureLensView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            CaptureStageHeader(model: model)
            CaptureStage(model: model)
            CaptureActionRow(model: model)
        }
        .padding(14)
        .cuePremiumPanel(cornerRadius: 22)
    }
}

private struct CaptureStageHeader: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                CueBrandMark(size: 46, active: model.captureState.isActive)
                Image(systemName: model.selectedMode.symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(CueColor.surfaceBase)
                    .frame(width: 18, height: 18)
                    .background(CueColor.accent, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.42), lineWidth: 1)
                    }
                    .offset(x: 4, y: 4)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(model.captureState.isActive ? model.selectedMode.userFacingArmedInstruction : model.selectedMode.userFacingTitle)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                Text(model.captureState.isActive ? "Press Esc to cancel." : model.selectedMode.userFacingIdleInstruction)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            ViewThatFits(in: .horizontal) {
                CompactModeStrip(model: model)
                    .padding(4)
                    .background(.regularMaterial, in: Capsule())
                    .overlay { Capsule().strokeBorder(CueColor.separator.opacity(0.38), lineWidth: 1) }
                CaptureModeMenu(model: model)
            }
        }
    }
}

private struct CompactModeStrip: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(CaptureMode.allCases) { mode in
                Button {
                    model.selectMode(mode)
                } label: {
                    Label(mode.userFacingPickerTitle, systemImage: mode.symbol)
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .frame(height: 30)
                        .background(model.selectedMode == mode ? CueColor.accent.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(model.selectedMode == mode ? CueColor.accent.opacity(0.26) : Color.clear, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.selectedMode == mode ? CueColor.accent : .secondary)
                .help(mode.userFacingHelpText)
                .accessibilityLabel("Capture mode: \(mode.userFacingTitle)")
                .accessibilityAddTraits(model.selectedMode == mode ? [.isSelected] : [])
            }
        }
    }
}

private struct CaptureStage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            CueStageBackdrop()

            if let target = model.currentTarget, model.captureState.isActive {
                LiveTargetView(model: model, target: target)
                    .padding(28)
                    .transition(.opacity)
            } else if let image = model.selectedCaptureImage {
                CapturedPreviewView(image: image, record: model.selectedCapture)
                    .padding(16)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            } else {
                EmptyCaptureView(model: model)
                    .padding(28)
                    .transition(.opacity)
            }
        }
        .frame(minHeight: 300)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(MotionSpec.stateChange, value: model.captureState)
        .animation(MotionSpec.historyInsertion, value: model.selectedCaptureID)
    }
}

private struct EmptyCaptureView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: model.selectedMode.symbol)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(CueColor.accent)
                .frame(width: 76, height: 76)
                .background(
                    LinearGradient(
                        colors: [CueColor.accent.opacity(0.18), CueColor.secondaryAccent.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(CueColor.accent.opacity(0.22), lineWidth: 1)
                }

            VStack(spacing: 6) {
                Text(CaptureCopy.emptyTitle)
                    .font(.headline)
                Text(CaptureCopy.emptyDetail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }

            Button {
                model.armCaptureFromFloatingControl()
            } label: {
                Label("Capture", systemImage: model.selectedMode.symbol)
                    .font(.headline)
                    .padding(.horizontal, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LiveTargetView: View {
    @ObservedObject var model: AppModel
    let target: CaptureTarget

    var body: some View {
        VStack(spacing: 18) {
            TargetOutline(active: true)
                .frame(width: min(max(target.rect.width * 0.34, 124), 280), height: min(max(target.rect.height * 0.34, 76), 170))
                .overlay {
                    Image(systemName: model.selectedMode.symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(CueColor.accent)
                        .padding(12)
                        .background(.regularMaterial, in: Circle())
                }

            VStack(spacing: 5) {
                Text(model.selectedMode.userFacingArmedInstruction)
                    .font(.title3.weight(.semibold))
                Text(model.selectedMode.presentation.contextualHint ?? "Press Esc to cancel.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.selectedMode.userFacingTitle) capture active. \(model.selectedMode.userFacingArmedInstruction)")
    }
}

private struct CapturedPreviewView: View {
    let image: NSImage
    let record: CaptureRecord?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(CueColor.separator.opacity(0.65), lineWidth: 1)
                }

            if let record {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(CueColor.success)
                    Text(record.mode == .ocr && record.normalizedOCRText != nil ? "Text copied" : CaptureCopy.copiedTitle)
                        .font(.caption.weight(.semibold))
                    Text(record.detailsSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CaptureActionRow: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { actionContent }
            VStack(spacing: 10) { actionContent }
        }
    }

    @ViewBuilder
    private var actionContent: some View {
        if let capture = model.selectedCapture {
            let result = CaptureResultPresentation(capture: capture)
            Button {
                if result.isTextResult {
                    model.copyOCRText(capture)
                } else if capture.mode == .ocr && capture.normalizedOCRText == nil {
                    model.armCaptureFromFloatingControl()
                } else {
                    model.copyCapture(capture)
                }
            } label: {
                Label(result.primaryActionTitle, systemImage: result.isTextResult ? "textformat" : "doc.on.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                model.saveSelectedCaptureAs()
            } label: {
                Label("Save…", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }

            Button {
                model.revealCapture(capture)
            } label: {
                Label("Show in Finder", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }

            Button {
                model.armCaptureFromFloatingControl()
            } label: {
                Label("New Capture", systemImage: model.selectedMode.symbol)
                    .frame(maxWidth: .infinity)
            }
        } else {
            Button {
                model.armCaptureFromFloatingControl()
            } label: {
                Label("Capture", systemImage: model.selectedMode.symbol)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                model.showCapturePuck()
            } label: {
                Label("Show Control", systemImage: "scope")
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct TargetOutline: View {
    let active: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(CueColor.accent.opacity(active ? 1 : 0.62), style: StrokeStyle(lineWidth: 1.6, dash: [8, 7]))
            .shadow(color: CueColor.accent.opacity(active ? 0.22 : 0.08), radius: 8)
    }
}

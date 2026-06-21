import SwiftUI

struct InspectorView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 10) {
                InspectorSection(title: "Output") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Copy PNG to Clipboard", systemImage: "doc.on.clipboard")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CueColor.reticle)

                        Text(model.destinationFallbackSummary)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let capture = model.selectedCapture {
                            Divider().opacity(0.35)
                            LastCaptureSummary(capture: capture)
                        }
                    }
                }

                InspectorSection(title: "Advanced") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $model.autoPasteToCodex) {
                            Label("Try App Server after copying", systemImage: "sparkles")
                        }
                        .toggleStyle(.switch)

                        Text("Experimental. App Server may create a new thread instead of filling the visible Codex composer.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                InspectorSection(title: "Permissions") {
                    VStack(alignment: .leading, spacing: 8) {
                        PermissionRow(
                            title: "Element detection",
                            detail: "Uses Accessibility",
                            granted: model.permissions.accessibilityGranted,
                            required: false
                        ) {
                            model.openPermissionSettings(.accessibility)
                        }
                        PermissionRow(
                            title: "Screen capture",
                            detail: "Uses Screen Recording",
                            granted: model.permissions.screenRecordingGranted,
                            required: true
                        ) {
                            model.openPermissionSettings(.screenRecording)
                        }
                    }
                }

                InspectorSection(title: "Last Capture") {
                    if let capture = model.selectedCapture {
                        VStack(spacing: 8) {
                            CaptureActionsRow(model: model, capture: capture)
                            Text(model.historyLocationDescription)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                    } else {
                        Text("Captured PNGs will appear here for copy, save, reveal, or export.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                InspectorSection(title: "History") {
                    if model.recentCaptures.isEmpty {
                        Text("No captures yet")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(model.recentCaptures.prefix(2)) { capture in
                                RecentCaptureRow(
                                    capture: capture,
                                    selected: capture.id == model.selectedCaptureID,
                                    select: {
                                        withAnimation(MotionSpec.navigationSpring) {
                                            model.selectedCaptureID = capture.id
                                        }
                                    }
                                )
                            }
                        }
                    }
                }

                if let lastError = model.lastErrorMessage {
                    InspectorSection(title: "Last Error") {
                        Text(lastError)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

            }
            .padding(12)
        }
        .frame(maxHeight: .infinity)
        .cueGlass(cornerRadius: 26)
    }
}

private struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .font(.system(size: 12))
        .padding(10)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct LastCaptureSummary: View {
    let capture: CaptureRecord

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: capture.mode.symbol)
                .foregroundStyle(CueColor.reticle)
            VStack(alignment: .leading, spacing: 2) {
                Text(capture.displayHandoffStatus)
                    .font(.system(size: 12, weight: .semibold))
                Text("\(capture.sourceAppName) - \(capture.dimensions) - \(capture.fileSize)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}

private struct CaptureActionsRow: View {
    @ObservedObject var model: AppModel
    let capture: CaptureRecord

    var body: some View {
        HStack(spacing: 7) {
            Button("Copy") {
                model.copyCapture(capture)
            }
            Button("Save") {
                model.saveSelectedCaptureAs()
            }
            Button("Reveal") {
                model.revealCapture(capture)
            }
        }
        .buttonStyle(PressableMotionStyle())
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let required: Bool
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: granted ? "checkmark.circle.fill" : required ? "exclamationmark.triangle.fill" : "scope")
                .foregroundStyle(granted ? CueColor.reticle : required ? .orange : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                Button("Open") {
                    openSettings()
                }
                .font(.system(size: 11, weight: .medium))
                .buttonStyle(.plain)
            }
        }
    }
}

private struct RecentCaptureRow: View {
    let capture: CaptureRecord
    let selected: Bool
    let select: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(selected ? .white.opacity(0.15) : .white.opacity(0.08))
                .frame(width: 38, height: 28)
                .overlay {
                    Image(systemName: capture.mode.symbol)
                        .font(.system(size: 11))
                        .foregroundStyle(selected ? CueColor.reticle : .secondary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(capture.sourceAppName)
                    .font(.system(size: 12, weight: .medium))
                Text("\(capture.mode.title) - \(capture.displayHandoffStatus)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(capture.dimensions)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(6)
        .background(selected ? .white.opacity(0.06) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
    }
}

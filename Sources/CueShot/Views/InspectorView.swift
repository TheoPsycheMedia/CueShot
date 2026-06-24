import SwiftUI

struct InspectorView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                if let capture = model.selectedCapture {
                    CaptureDetailsSection(capture: capture)

                    if let ocrText = capture.normalizedOCRText {
                        DetailDisclosure(title: "Text", systemImage: "textformat") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(ocrText)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Button {
                                    model.copyOCRText(capture)
                                } label: {
                                    Label("Copy Text", systemImage: "doc.on.doc")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }

                    DetailDisclosure(title: "File", systemImage: "doc") {
                        DetailRow(title: "Name", value: capture.pngRelativePath ?? "Local history item")
                        DetailRow(title: "Size", value: capture.fileSize)
                        DetailRow(title: "Location", value: model.historyLocationDescription)
                        Button {
                            model.revealCapture(capture)
                        } label: {
                            Label("Show in Finder", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    EmptyDetailsView()
                }

                if let error = model.lastErrorMessage {
                    DetailDisclosure(title: "Troubleshooting", systemImage: "wrench.and.screwdriver", initiallyExpanded: true) {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        troubleshootingActions
                    }
                } else {
                    DetailDisclosure(title: "Troubleshooting", systemImage: "wrench.and.screwdriver") {
                        Text("Use this when capture or optional Codex handoff behaves unexpectedly.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        troubleshootingActions
                    }
                }
            }
            .padding(16)
        }
        .background(CueColor.canvas)
        .navigationTitle("Details")
    }

    private var troubleshootingActions: some View {
        VStack(spacing: 8) {
            Button {
                model.refreshPermissions()
            } label: {
                Label("Refresh Permissions", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }

            Button {
                if let kind = model.permissions.firstMissingRequiredKind {
                    model.openPermissionSettings(kind)
                } else {
                    model.openPermissionSettings(.accessibility)
                }
            } label: {
                Label("Open Permissions Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity)
            }

            Text(model.permissionDiagnosticSummary)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .background(CueColor.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct CaptureDetailsSection: View {
    let capture: CaptureRecord

    var body: some View {
        DetailDisclosure(title: "Capture", systemImage: capture.mode.symbol, initiallyExpanded: true) {
            DetailRow(title: "Mode", value: capture.mode.userFacingTitle)
            DetailRow(title: "App", value: capture.sourceAppName)
            DetailRow(title: "Dimensions", value: capture.dimensions)
            DetailRow(title: "Captured", value: capture.createdAtShortText)
            DetailRow(title: "Clipboard", value: capture.displayHandoffStatus)
        }
    }
}

private struct EmptyDetailsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "sidebar.right")
                .font(.title2)
                .foregroundStyle(CueColor.accent)
            Text("No capture selected")
                .font(.headline)
            Text("Capture something first, then details for the image, text, and local file will appear here.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cueElevatedSurface(cornerRadius: 14)
    }
}

private struct DetailDisclosure<Content: View>: View {
    let title: String
    let systemImage: String
    var initiallyExpanded = false
    @ViewBuilder var content: () -> Content
    @State private var isExpanded: Bool

    init(title: String, systemImage: String, initiallyExpanded: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.initiallyExpanded = initiallyExpanded
        self.content = content
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(.top, 8)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.headline)
        }
        .padding(14)
        .cueElevatedSurface(cornerRadius: 14)
    }
}

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.callout)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}

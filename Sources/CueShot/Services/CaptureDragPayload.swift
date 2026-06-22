import AppKit
import Foundation

enum CaptureDragPayload {
    static func makePasteboardItem(fileURL: URL, fileManager: FileManager = .default) -> NSPasteboardItem? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let item = NSPasteboardItem()
        item.setString(fileURL.absoluteString, forType: .fileURL)
        item.setString(fileURL.lastPathComponent, forType: .init("public.url-name"))
        item.setString(fileURL.path, forType: .string)

        if let pngData = try? Data(contentsOf: fileURL), !pngData.isEmpty {
            item.setData(pngData, forType: .png)
        }

        return item
    }
}

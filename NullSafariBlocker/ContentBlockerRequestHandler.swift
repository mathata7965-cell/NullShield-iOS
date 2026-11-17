import Foundation

final class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        guard let attachmentURL = resolveActiveBlockerListURL(),
              let attachment = NSItemProvider(contentsOf: attachmentURL) else {
            context.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }

        let item = NSExtensionItem()
        item.attachments = [attachment]
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }

    private func resolveActiveBlockerListURL() -> URL? {
        if let extBundleID = Bundle.main.bundleIdentifier {
            let parts = extBundleID.split(separator: ".")
            if parts.count > 1 {
                let hostID = parts.dropLast().joined(separator: ".")
                let groupID = "group.\(hostID)"
                if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
                    let sharedFile = containerURL.appendingPathComponent("blockerList.json")
                    if FileManager.default.fileExists(atPath: sharedFile.path),
                       let data = try? Data(contentsOf: sharedFile),
                       data.count > 4 {
                        return sharedFile
                    }
                }
            }
        }

        return Bundle.main.url(forResource: "blockerList", withExtension: "json")
    }
}

import UIKit
import UserNotifications

/// Renders the announcing artists into the push banner as a stack of round
/// avatars — same geometry as StackedAvatars in the app (35% overlap, dark
/// ring gap, subtle border). The digest push carries up to three image URLs
/// in `artist_images`; whatever downloads in time gets drawn, and the push
/// is delivered unmodified if nothing does.
final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var content: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        content = request.content.mutableCopy() as? UNMutableNotificationContent

        let urls = (request.content.userInfo["artist_images"] as? [String] ?? [])
            .prefix(3)
            .compactMap(URL.init(string:))
        guard let content, !urls.isEmpty else {
            contentHandler(request.content)
            return
        }

        Task {
            let images = await Self.download(urls)
            if !images.isEmpty,
               let fileURL = Self.writeStackedAvatars(images),
               let attachment = try? UNNotificationAttachment(identifier: "artists", url: fileURL) {
                content.attachments = [attachment]
            }
            contentHandler(content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Out of time — deliver with whatever we have (usually no attachment).
        if let contentHandler, let content {
            contentHandler(content)
        }
    }

    /// Fetch all images concurrently, keeping the ranked order and dropping
    /// any that fail.
    private static func download(_ urls: [URL]) async -> [UIImage] {
        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask {
                    guard let (data, _) = try? await URLSession.shared.data(from: url) else {
                        return (index, nil)
                    }
                    return (index, UIImage(data: data))
                }
            }
            var ordered = [UIImage?](repeating: nil, count: urls.count)
            for await (index, image) in group {
                ordered[index] = image
            }
            return ordered.compactMap { $0 }
        }
    }

    /// Compose the avatar stack into a transparent PNG in tmp and return its
    /// URL (UNNotificationAttachment takes ownership of the file).
    private static func writeStackedAvatars(_ images: [UIImage]) -> URL? {
        let diameter: CGFloat = 180
        let overlapStep = diameter * 0.65  // the app's -0.35 stack spacing
        let ring: CGFloat = 5              // bg-colored gap between overlapped avatars
        let canvas = CGSize(
            width: diameter + CGFloat(images.count - 1) * overlapStep + ring * 2,
            height: diameter + ring * 2
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvas, format: format)

        let ringColor = UIColor(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0A / 255, alpha: 1)
        let borderColor = UIColor(red: 0x3A / 255, green: 0x3A / 255, blue: 0x3A / 255, alpha: 1)

        let png = renderer.pngData { ctx in
            // First artist sits on top, so draw back-to-front.
            for (index, image) in images.enumerated().reversed() {
                let rect = CGRect(
                    x: ring + CGFloat(index) * overlapStep,
                    y: ring,
                    width: diameter,
                    height: diameter
                )
                ringColor.setFill()
                ctx.cgContext.fillEllipse(in: rect.insetBy(dx: -ring, dy: -ring))

                ctx.cgContext.saveGState()
                ctx.cgContext.addEllipse(in: rect)
                ctx.cgContext.clip()
                image.draw(in: aspectFillRect(for: image.size, in: rect))
                ctx.cgContext.restoreGState()

                borderColor.setStroke()
                ctx.cgContext.setLineWidth(2)
                ctx.cgContext.strokeEllipse(in: rect.insetBy(dx: 1, dy: 1))
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("artist-avatars-\(UUID().uuidString).png")
        do {
            try png.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private static func aspectFillRect(for imageSize: CGSize, in rect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return rect }
        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let scaled = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: rect.midX - scaled.width / 2,
            y: rect.midY - scaled.height / 2,
            width: scaled.width,
            height: scaled.height
        )
    }
}

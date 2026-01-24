//
//  ShareSheet.swift
//  jiji-purinto
//
//  Utility for presenting UIActivityViewController (iOS share sheet).
//

import UIKit

/// Utility for presenting the iOS share sheet imperatively.
///
/// This bypasses SwiftUI's declarative system to avoid view update overhead.
///
/// ## Usage
/// ```swift
/// Button("Share") {
///     ShareSheet.present(items: [image])
/// }
/// ```
enum ShareSheet {
    /// Presents the iOS share sheet with the given items.
    ///
    /// - Parameter items: Items to share (images, URLs, text, Data, etc).
    static func present(items: [Any]) {
        print("[ShareSheet] present() called with \(items.count) items")
        guard !items.isEmpty else { return }

        // Find the topmost view controller
        print("[ShareSheet] Finding root VC...")
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            print("[ShareSheet] No root VC found!")
            return
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        print("[ShareSheet] Found top VC")

        print("[ShareSheet] Creating UIActivityViewController...")
        let activityController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        print("[ShareSheet] UIActivityViewController created")

        // Handle iPad popover presentation
        if let popover = activityController.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(
                x: topVC.view.bounds.midX,
                y: topVC.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        print("[ShareSheet] Calling present()...")
        topVC.present(activityController, animated: true)
        print("[ShareSheet] present() returned")
    }
}

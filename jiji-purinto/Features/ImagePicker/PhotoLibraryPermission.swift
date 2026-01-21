//
//  PhotoLibraryPermission.swift
//  jiji-purinto
//
//  Handles photo library permission requests.
//

import Photos

/// Manages photo library access permissions.
///
/// Provides async methods to check and request photo library access,
/// with clear status reporting for UI display.
enum PhotoLibraryPermission {
    /// Current authorization status for photo library access.
    enum Status: Sendable {
        /// User has not yet been asked for permission.
        case notDetermined

        /// User has granted limited access (iOS 14+).
        case limited

        /// User has granted full access.
        case authorized

        /// User has denied access.
        case denied

        /// Access is restricted by parental controls or MDM.
        case restricted

        /// Whether the app can access photos.
        var canAccessPhotos: Bool {
            switch self {
            case .authorized, .limited:
                return true
            case .notDetermined, .denied, .restricted:
                return false
            }
        }
    }

    /// Gets the current photo library authorization status.
    ///
    /// - Returns: The current authorization status.
    static func currentStatus() -> Status {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return mapStatus(status)
    }

    /// Requests photo library access permission.
    ///
    /// If permission has not been determined, prompts the user.
    /// Otherwise returns the current status immediately.
    ///
    /// - Returns: The resulting authorization status.
    static func requestAccess() async -> Status {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return mapStatus(status)
    }

    /// Maps PHAuthorizationStatus to our Status enum.
    private static func mapStatus(_ status: PHAuthorizationStatus) -> Status {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        @unknown default:
            return .denied
        }
    }
}

//
//  ImagePickerView.swift
//  jiji-purinto
//
//  SwiftUI wrapper for UIImagePickerController.
//

import SwiftUI
import PhotosUI

/// SwiftUI wrapper for the system image picker (camera or photo library).
///
/// Uses UIImagePickerController for camera access and PHPickerViewController
/// for photo library access (more modern API with better privacy).
///
/// ## Usage
/// ```swift
/// @State private var showPicker = false
/// @State private var selectedImage: UIImage?
///
/// Button("Select Photo") { showPicker = true }
///     .sheet(isPresented: $showPicker) {
///         ImagePickerView(
///             source: .gallery,
///             onImageSelected: { image in
///                 selectedImage = image
///             },
///             onCancel: {
///                 // Handle cancellation
///             }
///         )
///     }
/// ```
struct ImagePickerView: UIViewControllerRepresentable {
    /// The image source type.
    let source: ImageSource

    /// Called when an image is selected.
    let onImageSelected: (UIImage) -> Void

    /// Called when the picker is cancelled.
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        switch source {
        case .camera:
            return makeCameraPicker(context: context)
        case .gallery:
            return makePhotoPicker(context: context)
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected, onCancel: onCancel)
    }

    // MARK: - Camera Picker

    private func makeCameraPicker(context: Context) -> UIViewController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    // MARK: - Photo Library Picker

    private func makePhotoPicker(context: Context) -> UIViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        configuration.filter = .images

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    // MARK: - Coordinator

    /// Coordinator handling delegate callbacks from both picker types.
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
        let onImageSelected: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImageSelected: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImageSelected = onImageSelected
            self.onCancel = onCancel
        }

        // MARK: - UIImagePickerControllerDelegate (Camera)

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImageSelected(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }

        // MARK: - PHPickerViewControllerDelegate (Photo Library)

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                onCancel()
                return
            }

            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        self?.onImageSelected(image)
                    } else {
                        self?.onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - Camera Availability

extension ImagePickerView {
    /// Checks if the camera is available on this device.
    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Gallery Picker") {
    ImagePickerView(
        source: .gallery,
        onImageSelected: { _ in },
        onCancel: { }
    )
}
#endif

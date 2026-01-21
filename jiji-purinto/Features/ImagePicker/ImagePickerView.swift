//
//  ImagePickerView.swift
//  jiji-purinto
//
//  SwiftUI wrapper for PHPickerViewController.
//

import SwiftUI
import PhotosUI

/// SwiftUI wrapper for the system photo library picker.
///
/// Uses PHPickerViewController for photo library access (modern API with better privacy).
///
/// ## Usage
/// ```swift
/// @State private var showPicker = false
/// @State private var selectedImage: UIImage?
///
/// Button("Select Photo") { showPicker = true }
///     .sheet(isPresented: $showPicker) {
///         ImagePickerView(
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
    /// Called when an image is selected.
    let onImageSelected: (UIImage) -> Void

    /// Called when the picker is cancelled.
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        configuration.filter = .images

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected, onCancel: onCancel)
    }

    // MARK: - Coordinator

    /// Coordinator handling delegate callbacks from photo picker.
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImageSelected: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImageSelected: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImageSelected = onImageSelected
            self.onCancel = onCancel
        }

        // MARK: - PHPickerViewControllerDelegate

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

// MARK: - Preview

#if DEBUG
#Preview("Gallery Picker") {
    ImagePickerView(
        onImageSelected: { _ in },
        onCancel: { }
    )
}
#endif

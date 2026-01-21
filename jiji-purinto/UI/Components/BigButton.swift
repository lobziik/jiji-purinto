//
//  BigButton.swift
//  jiji-purinto
//
//  Large, toddler-friendly button component.
//

import SwiftUI

/// A large, prominent button designed for toddler-friendly interaction.
///
/// Features:
/// - Large tap target (minimum 88pt)
/// - High contrast colors
/// - Optional icon with text
struct BigButton: View {
    /// The button's label text.
    let title: String

    /// Optional SF Symbol name for the icon.
    let systemImage: String?

    /// The action to perform when tapped.
    let action: () -> Void

    /// Creates a big button with title and optional icon.
    ///
    /// - Parameters:
    ///   - title: The button label.
    ///   - systemImage: Optional SF Symbol name.
    ///   - action: The action to perform on tap.
    init(
        _ title: String,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 28, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

/// A square big button with an icon, designed for primary actions like camera.
struct BigIconButton: View {
    /// SF Symbol name for the icon.
    let systemImage: String

    /// The action to perform when tapped.
    let action: () -> Void

    /// Creates a big square icon button.
    ///
    /// - Parameters:
    ///   - systemImage: SF Symbol name for the icon.
    ///   - action: The action to perform on tap.
    init(systemImage: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 64, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 160, height: 160)
                .background(Color.accentColor)
                .cornerRadius(24)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Big Button") {
    VStack(spacing: 20) {
        BigButton("Gallery", systemImage: "photo.on.rectangle") {
            print("Gallery tapped")
        }

        BigButton("Print", systemImage: "printer") {
            print("Print tapped")
        }

        BigButton("Reset") {
            print("Reset tapped")
        }
    }
    .padding()
}

#Preview("Big Icon Button") {
    BigIconButton(systemImage: "photo.on.rectangle") {
        print("Gallery tapped")
    }
}

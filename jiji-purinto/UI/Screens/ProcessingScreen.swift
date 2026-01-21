//
//  ProcessingScreen.swift
//  jiji-purinto
//
//  Screen shown while image is being processed.
//

import SwiftUI

/// Screen displayed while the image is being processed.
///
/// Shows a simple loading indicator. In v0.2+, this will show actual processing progress.
struct ProcessingScreen: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(2.0)
                .progressViewStyle(CircularProgressViewStyle())

            Text("Processing...")
                .font(.title2)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

// MARK: - Previews

#Preview("Processing Screen") {
    ProcessingScreen()
}
